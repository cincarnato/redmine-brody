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

require_dependency 'issue'

module RedmineAgile
  module Patches

    module IssueQueryPatch
      def self.included(base)
        base.send(:include, InstanceMethods)
        base.class_eval do
          alias_method :issues_without_agile, :issues
          alias_method :issues, :issues_with_agile
          alias_method :issue_ids_without_agile, :issue_ids
          alias_method :issue_ids, :issue_ids_with_agile

          available_columns << QueryColumn.new(:story_points, :caption => :label_agile_story_points, :sortable => "#{AgileData.table_name}.story_points")
        end
      end

      module InstanceMethods
        def issues_with_agile(options = {})
          options[:include] = (options[:include] || []) | [:agile_data]
          issues = issues_without_agile(options)
          if RedmineAgile.color_base == AgileColor::COLOR_GROUPS[:issue]
            agile_colors = AgileColor.where(container_id: issues, container_type: 'Issue').group_by { |ac| ac[:container_id] }
            issues.each { |issue| issue.color = agile_colors[issue.id].try(:first).try(:color) }
          end
          issues
        end

        def issue_ids_with_agile(options = {})
          options[:include] = (options[:include] || []) | [:agile_data]
          options[:include] = (options[:include] || []) | [:agile_color] if RedmineAgile.color_base == AgileColor::COLOR_GROUPS[:issue]
          issue_ids_without_agile(options)
        end
      end
    end

  end
end

unless IssueQuery.included_modules.include?(RedmineAgile::Patches::IssueQueryPatch)
  IssueQuery.send(:include, RedmineAgile::Patches::IssueQueryPatch)
end
