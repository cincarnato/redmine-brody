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

class DealCategoriesController < ApplicationController
  unloadable
  menu_item :settings
  model_object DealCategory
  before_action :find_model_object, :except => [:new, :index, :create]
  before_action :find_project_from_association, :except => [:new, :index, :create]
  before_action :find_project_by_project_id, :only => [:new, :index, :create]
  before_action :authorize
  accept_api_auth :index, :update, :create, :destroy

  def index
    @categories = @project.deal_categories
    respond_to do |format|
      format.api
    end
  end

  def create
    @category = @project.deal_categories.build
    @category.safe_attributes = params[:category]
    if @category.save
      flash[:notice] = l(:notice_successful_create)
      respond_to do |format|
        format.html { redirect_to_settings_in_projects }
        format.api  { render_api_ok }
      end

    else
      respond_to do |format|
        format.html { render :action => 'new' }
        format.api  { render_validation_errors(@category) }
      end
    end
  end

  def new
    @category = @project.deal_categories.build(params[:category])
  end

  def edit
  end

  def update
    @category.safe_attributes = params[:category]
    if @category.save
      # @deal.contacts = [Contact.find(params[:contacts])] if params[:contacts]
      flash[:notice] = l(:notice_successful_update)
      respond_to do |format|
        format.html { redirect_to_settings_in_projects }
        format.api  { render_api_ok }
      end
    else
      respond_to do |format|
        format.html { render :action => 'edit' }
        format.api  { render_validation_errors(@category) }
      end
    end
  end

  def destroy
    @deal_count = @category.deals.size
    if @deal_count == 0 || params[:todo] || api_request?
      reassign_to = nil
      if params[:reassign_to_id] && (params[:todo] == 'reassign' || params[:todo].blank?)
        reassign_to = @project.deal_categories.find_by_id(params[:reassign_to_id])
      end
      @category.destroy(reassign_to)
      respond_to do |format|
        format.html { redirect_to_settings_in_projects }
        format.api { render_api_ok }
      end
      return
    end
    @categories = @project.deal_categories - [@category]
  end

  private

  def redirect_to_settings_in_projects
    redirect_to settings_project_path(@project, :tab => 'deals')
  end

  # Wrap ApplicationController's find_model_object method to set
  # @category instead of just @deal_category
  def find_model_object
    super
    @category = @object
    @project = @category.project
  end
end
