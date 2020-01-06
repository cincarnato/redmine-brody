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

class ContactsTagsController < ApplicationController
  unloadable
  before_action :require_admin, :except => [:index]
  before_action :find_tag, :only => [:edit, :update]
  before_action :bulk_find_tags, :only => [:context_menu, :merge, :destroy]

  accept_api_auth :index

  def index
    @tags = Contact.all_tag_counts(:order => :name)
    respond_to do |format|
      format.api
    end
  end

  def edit
  end

  def destroy
    @tags.each do |tag|
      begin
        tag.reload.destroy
        Contact.where("#{Contact.table_name}.cached_tag_list LIKE ?", '%' + tag.name + '%').includes(:tags).each{|c| c.tag_list = c.all_tags_list; c.save}
      rescue ::ActiveRecord::RecordNotFound # raised by #reload if tag no longer exists
        # nothing to do, tag was already deleted (eg. by a parent)
      end
    end
    redirect_back_or_default(:controller => 'settings', :action => 'plugin', :id => 'redmine_contacts', :tab => "tags")
  end

  def update
    old_name = @tag.name
    @tag.name = params[:tag][:name]
    if @tag.save
      Contact.where("#{Contact.table_name}.cached_tag_list LIKE ?", '%' + old_name + '%').includes(:tags).each{|c| c.tag_list = c.all_tags_list; c.save}
      flash[:notice] = l(:notice_successful_update)
      respond_to do |format|
        format.html { redirect_to :controller => 'settings', :action => 'plugin', :id => 'redmine_contacts', :tab => "tags" }
      end
    else
      respond_to do |format|
        format.html { render :action => "edit"}
      end
    end
  end

  def context_menu
    @tag = @tags.first if (@tags.size == 1)
    @back = back_url
    render :layout => false
  end

  def merge
    if request.post? && params[:tag] && params[:tag][:name]
      RedmineCrm::Tagging.transaction do
        tag = RedmineCrm::Tag.where(:name => params[:tag][:name]).first || RedmineCrm::Tag.create(params[:tag])
        RedmineCrm::Tagging.where(:tag_id => @tags.map(&:id)).update_all(:tag_id => tag.id)
        @tags.select{|t| t.id != tag.id}.each do |t|
          t.destroy
          Contact.where("#{Contact.table_name}.cached_tag_list LIKE ?", '%' + t.name + '%').includes(:tags).each{|c| c.tag_list = c.all_tags_list; c.save}
        end
        redirect_to :controller => 'settings', :action => 'plugin', :id => 'redmine_contacts', :tab => "tags"
      end
    end
  end

  private

  def bulk_find_tags
    @tags = RedmineCrm::Tag.where(:id => params[:id] ? [params[:id]] : params[:ids])
    raise ActiveRecord::RecordNotFound if @tags.empty?
  end

  def find_tag
    @tag = RedmineCrm::Tag.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end
end
