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

class ContactsIssuesController < ApplicationController
  unloadable

  before_action :find_contact, :only => [:create_issue, :delete]
  before_action :find_issue, :except => [:create_issue]
  before_action :find_project_by_project_id, :only => [:create_issue]
  before_action :authorize_global, :only => [:close]
  before_action :authorize

  helper :contacts

  def create_issue
    deny_access unless User.current.allowed_to?(:manage_contact_issue_relations, @project) || User.current.allowed_to?(:add_issues, @project)
    issue = Issue.new
    issue.project = @project
    issue.author = User.current
    issue.status = IssueStatus.default if ActiveRecord::VERSION::MAJOR < 4
    issue.start_date ||= Date.today
    issue.contacts << @contact
    issue.safe_attributes = params[:issue] if params[:issue]

    if issue.save
      flash[:notice] = l(:notice_successful_add)
    else
      flash[:error] = issue.errors.full_messages.join('<br>').html_safe
    end
    redirect_to :back
  end

  def create
    contact_ids = []
    if params[:contacts_issue].present?
      contact_ids << (params[:contacts_issue][:contact_ids] || params[:contacts_issue][:contact_id])
    else
      contact_ids << params[:contact_id]
    end
    contact_ids.flatten.compact.uniq.each do |contact_id|
      ContactsIssue.create(:issue_id => @issue.id, :contact_id => contact_id)
    end
    respond_to do |format|
      format.html { redirect_to_referer_or { render :text => 'Added.', :layout => true } }
      format.js
    end
  end

  def new
  end

  def delete
    @issue.contacts.delete(@contact)
    respond_to do |format|
      format.html { redirect_to :back }
      format.js
    end
  end

  def close
    @issue.init_journal(User.current)
    @issue.status = IssueStatus.where(:is_closed => true).first
    @issue.save
    respond_to do |format|
      format.js
      format.html { redirect_to :back }
    end
  end

  def autocomplete_for_contact
    q = params[:q].to_s
    scope = Contact.where({})
    q.split(' ').collect { |search_string| scope = scope.live_search(search_string) } unless q.blank?
    @contacts = scope.visible.includes(:avatar).order(Contact.fields_for_order_statement).by_project(params[:cross_project_contacts] == '1' ? nil : @project).limit(100)
    @contacts -= @issue.contacts if @issue
    render :layout => false
  end

  private

  def find_contact
    @contact = Contact.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def find_issue
    @issue = Issue.find(params[:issue_id])
    @project = @issue.project
  rescue ActiveRecord::RecordNotFound
    render_404
  end
end
