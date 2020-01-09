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

class AgileVersionsQuery < AgileQuery
  unloadable

  self.queried_class = Issue
  self.view_permission = :view_issues if Redmine::VERSION.to_s >= '3.4'

  self.available_columns = [
    QueryColumn.new(:id, sortable: "#{Issue.table_name}.id", default_order: 'desc', caption: :label_agile_issue_id),
    QueryColumn.new(:tracker, sortable: "#{Tracker.table_name}.position", groupable: true),
    QueryColumn.new(:status, sortable: "#{Tracker.table_name}.status_id", groupable: true),
    QueryColumn.new(:estimated_hours, sortable: "#{Issue.table_name}.estimated_hours"),
    QueryColumn.new(:done_ratio, sortable: "#{Issue.table_name}.done_ratio"),
    QueryColumn.new(:priority, sortable: "#{IssuePriority.table_name}.position", default_order: 'desc', groupable: true),
    QueryColumn.new(:author, sortable: lambda { User.fields_for_order_statement('users') }, groupable: true),
    QueryColumn.new(:category, sortable: "#{IssueCategory.table_name}.name", groupable: "#{Issue.table_name}.category_id"),
    QueryColumn.new(:start_date, sortable: "#{Issue.table_name}.start_date"),
    QueryColumn.new(:due_date, sortable: "#{Issue.table_name}.due_date"),
    QueryColumn.new(:created_on, sortable: "#{Issue.table_name}.created_on"),
    QueryColumn.new(:updated_on, sortable: "#{Issue.table_name}.updated_on"),
    QueryColumn.new(:thumbnails, caption: :label_agile_board_thumbnails),
    QueryColumn.new(:description),
    QueryColumn.new(:sub_issues, caption: :label_agile_sub_issues),
    QueryColumn.new(:day_in_state, caption: :label_agile_day_in_state),
    QueryColumn.new(:parent, groupable: "#{Issue.table_name}.parent_id", sortable: "#{AgileData.table_name}.position", caption: :field_parent_issue),
    QueryColumn.new(:assigned_to, sortable: lambda { User.fields_for_order_statement }, groupable: "#{Issue.table_name}.assigned_to_id"),
    QueryColumn.new(:relations, caption: :label_related_issues),
    QueryColumn.new(:last_comment, caption: :label_agile_last_comment),
    QueryColumn.new(:story_points, caption: :label_agile_story_points)
  ]

  def initialize(attributes = nil, *args)
    super attributes
    self.filters = { 'status_id' => { :operator => 'o', :values => [''] } } unless filters.present?
  end

  def initialize_available_filters
    principals = []
    categories = []
    issue_custom_fields = []

    if project
      principals += project.principals.sort
      unless project.leaf?
        subprojects = project.descendants.visible.all
        principals += Principal.member_of(subprojects)
      end
      categories = project.issue_categories.all
      issue_custom_fields = project.all_issue_custom_fields
    else
      if all_projects.any?
        principals += Principal.member_of(all_projects)
      end
      issue_custom_fields = IssueCustomField.where(is_for_all: true)
    end
    principals.uniq!
    principals.sort!
    users = principals.select { |p| p.is_a?(User) }

    add_available_filter('tracker_id', type: :list, values: trackers.map { |s| [s.name, s.id.to_s] })
    add_available_filter('priority_id', type: :list, values: IssuePriority.all.map { |s| [s.name, s.id.to_s] })

    author_values = []
    author_values << ["<< #{l(:label_me)} >>", 'me'] if User.current.logged?
    author_values += users.map { |s| [s.name, s.id.to_s] }
    add_available_filter('author_id', type: :list, values: author_values) unless author_values.empty?

    assigned_to_values = []
    assigned_to_values << ["<< #{l(:label_me)} >>", 'me'] if User.current.logged?
    assigned_to_values += (Setting.issue_group_assignment? ? principals : users).map { |s| [s.name, s.id.to_s] }
    add_available_filter('assigned_to_id', type: :list_optional, values: assigned_to_values) unless assigned_to_values.empty?

    if categories.any?
      add_available_filter('category_id', type: :list_optional, values: categories.map { |s| [s.name, s.id.to_s] })
    end

    add_available_filter('status_id', type: :list_status, values: IssueStatus.sorted.map { |s| [s.name, s.id.to_s] })
    add_available_filter('estimated_hours', type: :float)
    add_available_filter('fixed_version_id', type: :list, values: project.shared_versions.open.sorted.map { |v| [v.name, v.id.to_s] })

    add_custom_fields_filters(issue_custom_fields)
    add_associations_custom_fields_filters(:project, :author, :assigned_to, :fixed_version)
  end

  def available_columns
    return @available_columns if @available_columns
    @available_columns = self.class.available_columns.dup
    @available_columns += project.all_issue_custom_fields.visible.map { |cf| QueryCustomFieldColumn.new(cf) }

    if User.current.allowed_to?(:view_time_entries, project, global: true)
      index = nil
      @available_columns.each_with_index { |column, i| index = i if column.name == :estimated_hours}
      index = (index ? index + 1 : -1)
      # insert the column after estimated_hours or at the end
      @available_columns.insert index, QueryColumn.new(:spent_hours,
        sortable: "COALESCE((SELECT SUM(hours) FROM #{TimeEntry.table_name} WHERE #{TimeEntry.table_name}.issue_id = #{Issue.table_name}.id), 0)",
        default_order: 'desc',
        caption: :label_spent_time
      )
    end

    if User.current.allowed_to?(:set_issues_private, nil, global: true) ||
         User.current.allowed_to?(:set_own_issues_private, nil, global: true)
      @available_columns << QueryColumn.new(:is_private, sortable: "#{Issue.table_name}.is_private")
    end

    disabled_fields = Tracker.disabled_core_fields(trackers).map { |field| field.sub(/_id$/, '') }
    @available_columns.reject! { |column| disabled_fields.include?(column.name.to_s) }

    @available_columns.reject! { |column| column.name == :done_ratio } unless Issue.use_field_for_done_ratio?

    @available_columns
  end

  def versions
    versions_sql =
      if filters['fixed_version_id']
        filter = filters['fixed_version_id']
        sql_for_field('fixed_version_id', filter[:operator], filter[:values], Version.table_name, 'id')
      else
        '1=1'
      end
    project.shared_versions.open.where(versions_sql).sorted
  end

  def no_version_issues(params = {})
    return @no_version_scope if @no_version_scope
    q = (params[:q] || params[:term]).to_s.strip
    @no_version_scope = Issue.visible.joins(query_includes)
    if project
      project_ids = [project.id]
      project_ids += project.descendants.map(&:id) if Setting.display_subprojects_issues?
      @no_version_scope = @no_version_scope.where(project_id: project_ids)
      @no_version_scope = @no_version_scope.where(tracker_id: project.trackers.where(is_in_roadmap: true))
    end

    @no_version_scope = @no_version_scope.where(no_version_statetment).where(fixed_version_id: nil).sorted_by_rank
    if q.present?
      if q.match(/^#?(\d+)\z/)
        @no_version_scope = @no_version_scope.where("(#{Issue.table_name}.id = ?) OR (LOWER(#{Issue.table_name}.subject) LIKE LOWER(?))", $1.to_i, "%#{q}%")
      else
        @no_version_scope = @no_version_scope.where("LOWER(#{Issue.table_name}.subject) LIKE LOWER(?)", "%#{q}%")
      end
    end
    @no_version_scope
  end

  def version_issues(version)
    version.fixed_issues.visible.joins(query_includes)
           .where(statement)
           .where(tracker_id: project.trackers.where(is_in_roadmap: true))
           .sorted_by_rank
  end

  def version_paginator(version, params)
    issues = version ? version_issues(version) : no_version_issues(params)
    Redmine::Pagination::Paginator.new(issues.count, 20, params[:page])
  end

  private

  def query_includes
    [:project]
  end

  def no_version_statetment
    versions_filter = filters['fixed_version_id']
    filters.delete('fixed_version_id')
    clauses = statement
    clauses
  ensure
    filters['fixed_version_id'] = versions_filter if versions_filter
  end
end
