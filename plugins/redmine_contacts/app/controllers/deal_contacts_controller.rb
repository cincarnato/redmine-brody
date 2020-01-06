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

class DealContactsController < ApplicationController
  unloadable

  before_action :find_project_by_project_id, :authorize
  before_action :find_contact, :only => :delete
  before_action :find_deal

  helper :deals
  helper :contacts

  def search
    @contacts = contacts.limit(10) - @deal.all_contacts
  end

  def autocomplete
    @contacts = contacts.live_search(params[:q]).limit(100) - @deal.all_contacts
    render :layout => false
  end

  def add
    if params[:contact_id] && request.post?
      find_contact
      unless @deal.all_contacts.include?(@contact)
        @deal.related_contacts << @contact
        @deal.save
      end
    end

    respond_to do |format|
      format.html do
        redirect_to :back
      end
      format.js
    end
  end

  def delete
    @deal.related_contacts.delete(@contact)
    respond_to do |format|
      format.html { redirect_to :back }
      format.js
    end
  end

  private

  def contacts
    Contact.visible.by_project(ContactsSetting.cross_project_contacts? ? nil : @project)
  end

  def find_contact
    @contact = Contact.find(params[:contact_id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def find_deal
    @deal = Deal.find(params[:deal_id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end
end
