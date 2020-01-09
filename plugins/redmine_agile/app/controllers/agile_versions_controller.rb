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

class AgileVersionsController < ApplicationController
  unloadable

  menu_item :agile

  before_action :find_project_by_project_id
  before_action :authorize, except: [:autocomplete, :load_more]
  before_action :find_version, only: [:load_more]
  before_action :retrieve_versions_query
  before_action :find_no_version_issues, only: [:index]

  helper :queries
  include QueriesHelper
  helper :sort
  include SortHelper
  helper :issues
  include IssuesHelper
  helper :agile_boards
  include AgileBoardsHelper
  include RedmineAgile::AgileHelper

  def index
    respond_to do |format|
      format.html
      format.js
    end
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def autocomplete
    @issues = find_no_version_issues
    render layout: false
  end

  def load_more
    @issues = @version ? find_version_issues : find_no_version_issues
    render layout: false
  end

  private

  def find_version
    return unless params[:version_id]
    @version = Version.visible.where(id: params[:version_id]).first
    return render_404 unless @version
  end

  def find_version_issues
    scope = @query.version_issues(@version)
    @paginator = @query.version_paginator(@version, params)
    @version_issues = scope.offset(@paginator.offset).limit(@paginator.per_page).all
  end

  def find_no_version_issues
    scope = @query.no_version_issues(params)
    @paginator = @query.version_paginator(nil, params)
    @no_version_issues = scope.offset(@paginator.offset).limit(@paginator.per_page).all
  end
end
