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

class DealStatusesController < ApplicationController
  unloadable

  layout 'admin'
  before_action :require_admin, except: :assign_to_project
  before_action :find_project_by_project_id, :authorize, only: :assign_to_project

  accept_api_auth :index

  def index
    @deal_statuses = DealStatus.order(:position)

    respond_to do |format|
      format.api
      format.html { render action: 'index', layout: false if request.xhr? }
    end
  end

  def new
    @deal_status = DealStatus.new
  end

  def create
    @deal_status = DealStatus.new
    @deal_status.safe_attributes = params[:deal_status]
    if @deal_status.save
      flash[:notice] = l(:notice_successful_create)
      redirect_to action: 'plugin', id: 'redmine_contacts', controller: 'settings', tab: 'deal_statuses'
    else
      render action: 'new'
    end
  end

  def edit
    @deal_status = DealStatus.find(params[:id])
  end

  def update
    @deal_status = DealStatus.find(params[:id])
    @deal_status.safe_attributes = params[:deal_status]
    @deal_status.insert_at(@deal_status.position) if @deal_status.position_changed?
    if @deal_status.save
      respond_to do |format|
        format.html do
          flash[:notice] = l(:notice_successful_update)
          redirect_to action: 'plugin', id: 'redmine_contacts', controller: 'settings', tab: 'deal_statuses'
        end
        format.js { head 200 }
      end
    else
      respond_to do |format|
        format.html do
          render action: 'edit'
        end
        format.js { head 422 }
      end
    end
  end

  def destroy
    DealStatus.find(params[:id]).destroy
    redirect_to action: 'plugin', id: 'redmine_contacts', controller: 'settings', tab: 'deal_statuses'
  rescue
    flash[:error] = l(:error_unable_delete_deal_status)
    redirect_to action: 'plugin', id: 'redmine_contacts', controller: 'settings', tab: 'deal_statuses'
  end

  def assign_to_project
    if request.put?
      @project.deal_statuses = !params[:deal_statuses].blank? ? DealStatus.find(params[:deal_statuses]) : []
      @project.save
      flash[:notice] = l(:notice_successful_update)
    end
    redirect_to controller: 'projects', action: 'settings', tab: 'deals', id: @project
  end
end
