# This file is a part of Redmin Agile (redmine_agile) plugin,
# Agile board plugin for redmine
#
# Copyright (C) 2011-2019 RedmineUP
# http://www.redmineup.com/
#
# redmine_agile is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# redmine_agile is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with redmine_agile.  If not, see <http://www.gnu.org/licenses/>.

class AgileBoardsController < ApplicationController
  unloadable

  menu_item :agile

  before_action :find_issue, :only => [:update, :issue_tooltip, :inline_comment]
  before_action :find_optional_project, :only => [:index, :create_issue]

  helper :issues
  helper :journals
  helper :projects
  include ProjectsHelper
  helper :custom_fields
  include CustomFieldsHelper
  helper :issue_relations
  include IssueRelationsHelper
  helper :watchers
  include WatchersHelper
  helper :attachments
  include AttachmentsHelper
  helper :queries
  include QueriesHelper
  helper :repositories
  include RepositoriesHelper
  helper :sort
  include SortHelper
  include IssuesHelper
  helper :timelog
  include RedmineAgile::AgileHelper
  helper :checklists if RedmineAgile.use_checklist?

  def index
    retrieve_agile_query
    if @query.valid?
      @issues = @query.issues
      @issue_board = @query.issue_board
      @board_columns = @query.board_statuses
      @swimlanes = @query.swimlanes
      @closed_swimline_ids = params[:closed_swimline_ids] || []

      respond_to do |format|
        format.html { render :template => 'agile_boards/index', :layout => !request.xhr? }
        format.js
      end
    else
      respond_to do |format|
        format.html { render(:template => 'agile_boards/index', :layout => !request.xhr?) }
        format.js
      end
    end
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def update
    (render_403; return false) unless @issue.editable?
    retrieve_agile_query_from_session
    old_status = @issue.status
    @issue.init_journal(User.current)
    @issue.safe_attributes = auto_assign_on_move? ? params[:issue].merge(:assigned_to_id => User.current.id) : params[:issue]
    checking_params = params.respond_to?(:to_unsafe_hash) ? params.to_unsafe_hash : params
    saved = checking_params['issue'] && checking_params['issue'].inject(true) do |total, attribute|
      if @issue.attributes.include?(attribute.first)
        total &&= @issue.attributes[attribute.first].to_i == attribute.last.to_i
      else
        total &&= true
      end
    end
    call_hook(:controller_agile_boards_update_before_save, { :params => params, :issue => @issue})
    @update = true
    @version_board = params[:version_board].to_i > 0
    if saved && @issue.save
      call_hook(:controller_agile_boards_update_after_save, { :params => params, :issue => @issue})
      AgileData.transaction do
        Issue.eager_load(:agile_data).find(params[:positions].keys).each do |issue|
          issue.agile_data.position = params[:positions][issue.id.to_s]['position']
          issue.agile_data.save
        end
      end if params[:positions]

      @inline_adding = params[:issue][:notes] || nil
      if Redmine::VERSION.to_s > '2.4'
        if current_status = @query.board_statuses.detect{ |st| st == @issue.status }
          @error_msg =  l(:lable_agile_wip_limit_exceeded) if current_status.over_wp_limit?
          @wp_class = current_status.wp_class
        end

        if @old_status = @query.board_statuses.detect{ |st| st == old_status }
          @wp_class_for_old_status = @old_status.wp_class
        end
      end

      respond_to do |format|
        format.html { render(:partial => 'issue_card', :locals => {:issue => @issue}, :status => :ok, :layout => nil) }
      end
    else
      respond_to do |format|
        messages = @issue.errors.full_messages
        messages = [l(:text_agile_move_not_possible)] if messages.empty?
        format.html {
          render :json => messages, :status => :fail, :layout => nil
        }
      end
    end
  end
  def create_issue
    if !User.current.allowed_to?(:add_issues, @project) || params[:subject].blank?
      messages = [l(:notice_not_authorized)]
      respond_to do |format|
        format.html {
          render :json => messages, :status => :fail, :layout => nil
        }
      end
      return
    end
    retrieve_agile_query_from_session
    @update = true
    @issue = Issue.new(:subject => params[:subject].strip, :project => @project,
      :tracker => @project.trackers.first, :author => User.current, :status_id => params[:status_id])
    begin
      if @issue.save(:validate => false)
        if Redmine::VERSION.to_s > '2.4'
          if current_status = @query.board_statuses.detect{ |st| st == @issue.status }
            @error_msg =  l(:lable_agile_wip_limit_exceeded) if current_status.over_wp_limit?
            @wp_class = current_status.wp_class
          end
        end
        @not_in_scope = !@query.issues.include?(@issue)
        respond_to do |format|
          format.html { render(:partial => 'issue_card', :locals => {:issue => @issue}, :status => :ok, :layout => nil) }
        end
      else
        respond_to do |format|
          messages = @issue.errors.full_messages
          messages = [l(:text_agile_move_not_possible)] if messages.empty?
          format.html {
            render :json => messages, :status => :fail, :layout => nil
          }
        end
      end
    rescue
      respond_to do |format|
        messages = @issue.errors.full_messages
        messages = [l(:text_agile_create_issue_error)] if messages.empty?
        format.html {
          render :json => messages, :status => :fail, :layout => nil
        }
      end
    end
  end

  def issue_tooltip
    render :partial => 'issue_tooltip'
  end

  def inline_comment
    render 'inline_comment', :layout => nil
  end

  private

  def auto_assign_on_move?
    RedmineAgile.auto_assign_on_move? && @issue.assigned_to.nil? &&
      !params[:issue].keys.include?('assigned_to_id') &&
      @issue.status_id != params[:issue]['status_id'].to_i
  end

end
