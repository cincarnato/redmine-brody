# This file is a part of Redmine CRM (redmine_contacts) plugin,
# customer relationship management plugin for Redmine
#
# Copyright (C) 2010-2019 RedmineUP
# http://www.redmineup.com/
#
# redmine_contacts is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# redmine_contacts is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with redmine_contacts.  If not, see <http://www.gnu.org/licenses/>.

class CrmQueriesController < ApplicationController
  before_action :find_query_class
  before_action :find_query, :except => [:new, :create, :index]
  before_action :find_optional_project, :only => [:new, :create]
  before_action :set_menu_item

  accept_api_auth :index

  helper :queries
  include QueriesHelper

  def index
    case params[:format]
    when 'xml', 'json'
      @offset, @limit = api_offset_and_limit
    else
      @limit = per_page_option
    end
    @query_count = @query_class.visible.count
    @query_pages = Paginator.new @query_count, @limit, params['page']
    @queries = @query_class.visible.
                    order("#{Query.table_name}.name").
                    limit(@limit).
                    offset(@offset).
                    all
    respond_to do |format|
      format.api
    end
  end

  def new
    @query = @query_class.new
    @query.user = User.current
    @query.project = @project
    update_query_from_params
  end

  def create
    @query = @query_class.new
    @query.user = User.current
    @query.project = params[:query_is_for_all] ? nil : @project
    update_query_from_params

    if @query.save
      flash[:notice] = l(:notice_successful_create)
      redirect_to_list(:query_id => @query)
    else
      render :action => 'new', :layout => !request.xhr?
    end
  end

  def edit
  end

  def update
    @query.project = nil if params[:query_is_for_all]
    update_query_from_params

    if @query.save
      flash[:notice] = l(:notice_successful_update)
      redirect_to_list(:query_id => @query)
    else
      render :action => 'edit'
    end
  end

  def destroy
    @query.destroy
    redirect_to_list(:set_filter => 1)
  end

  private

  def find_query_class
    raise NameError if params[:object_type].blank?
    @query_class = Object.const_get("#{params[:object_type].to_s.camelcase}Query")
    @object_type = params[:object_type]
    return false unless @query_class.is_a?(Query)
  rescue NameError
    render_404
  end

  def find_query
    @query = @query_class.find(params[:id])
    @project = @query.project
    render_403 unless @query.editable_by?(User.current)
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def find_optional_project
    @project = Project.find(params[:project_id]) if params[:project_id]
    render_403 unless User.current.allowed_to?("save_#{@object_type}s_queries".to_sym, @project, :global => true)
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def redirect_to_list(options)
    redirect_to url_for({:controller => "#{@object_type}s", :action => "index", :project_id => @project}.merge(options))
  end

  def set_menu_item
    menu_items[:project_tabs][:actions][action_name.to_sym] = "#{@object_type}s"
  end

  def update_query_from_params
    return if params[:query].blank? && params[:c].blank?

    query_params = params[:query].present? ? params[:query] : params

    @query.build_from_params(params)
    @query.name = query_params[:name]
    @query.is_public = query_params[:is_public] if query_params[:is_public]
    @query.column_names = nil if query_params[:default_columns]
    @query.sort_criteria = query_params[:sort_criteria] || @query.sort_criteria
    if User.current.allowed_to?("manage_public_#{@object_type}s_queries".to_sym, @project) || User.current.admin?
      @query.visibility = query_params[:visibility] if query_params[:visibility]
      @query.role_ids = query_params[:role_ids] if query_params[:role_ids]
    else
      @query_class::VISIBILITY_PRIVATE
    end
  end
end
