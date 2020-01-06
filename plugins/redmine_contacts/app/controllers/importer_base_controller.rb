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

class ImporterBaseController < ApplicationController
  unloadable
  if Redmine::VERSION.to_s >= '3.2'
    helper :imports
    before_action :find_import, :only => [:show, :settings, :mapping, :run]
  end

  before_action :find_project_by_project_id, :authorize

  def new
    @importer = klass.new
    if Redmine::VERSION.to_s >= '3.2'
      render 'importers/kernel_new'
    else
      render 'importers/new'
    end
  end

  def create
    if Redmine::VERSION.to_s >= '3.2'
      @import = importer_klass.new
      @import.user = User.current
      @import.project = @project
      @import.file = params[:file]
      @import.set_default_settings

      if @import.save
        redirect_to :controller => klass.name.tableize, :action => 'settings', :id => @import, :project_id => @project
      else
        render 'importers/kernel_new'
      end
    else
      @importer = klass.new(params[klass.to_s.underscore.to_sym])
      @importer.project = @project
      if @importer.file && @importer.save
        redirect_to instance_index
      else
        render 'importers/new'
      end
    end
  end

  def show
    render 'importers/show'
  end

  def settings
    if request.post? && @import.parse_file
      return redirect_to :controller => klass.name.tableize, :action => 'mapping', :id => @import, :project_id => @project
    end
    render 'importers/settings'

  rescue CSV::MalformedCSVError => e
    flash.now[:error] = l(:error_invalid_csv_file_or_settings)
    render 'importers/settings'
  rescue ArgumentError, Encoding::InvalidByteSequenceError => e
    flash.now[:error] = l(:error_invalid_file_encoding, :encoding => ERB::Util.h(@import.settings['encoding']))
    render 'importers/settings'
  rescue SystemCallError => e
    flash.now[:error] = l(:error_can_not_read_import_file)
    render 'importers/settings'
  end

  def mapping
    mapping_object = klass.new.klass.new
    @attributes = mapping_object.safe_attribute_names
    @custom_fields = mapping_object.custom_field_values.map(&:custom_field)

    if request.post?
      respond_to do |format|
        format.html do
          if params[:previous]
            redirect_to :controller => klass.name.tableize, :action => 'settings', :id => @import, :project_id => @project
          else
            redirect_to :controller => klass.name.tableize, :action => 'run', :id => @import, :project_id => @project
          end
        end
      end
    else
      render 'importers/mapping'
    end
  end

  def run
    if request.post?
      @current = @import.run(
        :max_items => max_items_per_request,
        :max_time => 10.seconds
      )
      respond_to do |format|
        format.html do
          if @import.finished?
            redirect_to :controller => klass.name.tableize, :action => 'show', :id => @import, :project_id => @project
          else
            redirect_to :controller => klass.name.tableize, :action => 'run', :id => @import, :project_id => @project
          end
        end
        format.js { render 'importers/run' }
      end
    else
      render 'importers/run'
    end
  end

  private

  def find_import
    @import = Import.where(:user_id => User.current.id, :filename => params[:id]).first
    if @import.nil?
      render_404
      return
    elsif @import.finished? && action_name != 'show'
      redirect_to new_project_contact_import_path(@import)
      return
    end
    update_from_params if request.post?
  end

  def update_from_params
    if params[:import_settings].present?
      @import.settings ||= {}
      @import.settings.merge!(params.respond_to?(:to_unsafe_hash) ? params.to_unsafe_hash['import_settings'] : params['import_settings'])
      @import.save!
    end
  end

  def max_items_per_request
    5
  end
end
