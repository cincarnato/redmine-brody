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


require 'acts_as_colored/init'

require 'redmine_agile/hooks/views_layouts_hook'
require 'redmine_agile/hooks/views_issues_hook'
require 'redmine_agile/hooks/views_versions_hook'
require 'redmine_agile/hooks/controller_issue_hook'
require 'redmine_agile/hooks/helper_issues_hook'
require 'redmine_agile/patches/issue_patch'

require 'redmine_agile/helpers/agile_helper'

require 'redmine_agile/charts/agile_chart'
require 'redmine_agile/charts/burndown_chart'
require 'redmine_agile/charts/work_burndown_chart'
require 'redmine_agile/charts/velocity_chart'
require 'redmine_agile/charts/cumulative_flow_chart'
require 'redmine_agile/charts/trackers_cumulative_flow_chart'
require 'redmine_agile/charts/burnup_chart'
require 'redmine_agile/charts/work_burnup_chart'
require 'redmine_agile/charts/lead_time_chart'
require 'redmine_agile/charts/average_lead_time_chart'

require 'redmine_agile/patches/issue_priority_patch'
require 'redmine_agile/patches/issue_query_patch'
require 'redmine_agile/patches/tracker_patch'
require 'redmine_agile/patches/project_patch'
require 'redmine_agile/hooks/views_context_menus_hook'
require 'redmine_agile/hooks/views_projects_form_hook'

require 'redmine_agile/utils/header_tree'

require 'redmine_agile/patches/user_patch'
require 'redmine_agile/hooks/views_users_form_hook'
require 'redmine_agile/patches/queries_controller_patch' if Redmine::VERSION.to_s >= '3.4'
require 'redmine_agile/charts/charts'

module RedmineAgile

  ISSUES_PER_COLUMN = 10
  TIME_REPORTS_ITEMS = 1000
  BOARD_ITEMS = 500

  ESTIMATE_HOURS        = 'hours'.freeze
  ESTIMATE_STORY_POINTS = 'story_points'.freeze
  ESTIMATE_UNITS        = [ESTIMATE_HOURS, ESTIMATE_STORY_POINTS].freeze
  COLOR_BASE = ['issue', 'tracker', 'priority', 'spent_time', 'user', 'project']

  class << self
    def time_reports_items_limit
      by_settigns = Setting.plugin_redmine_agile['time_reports_items_limit'].to_i
      by_settigns > 0 ? by_settigns : TIME_REPORTS_ITEMS
    end

    def board_items_limit
      by_settigns = Setting.plugin_redmine_agile['board_items_limit'].to_i
      by_settigns > 0 ? by_settigns : BOARD_ITEMS
    end

    def issues_per_column
      by_settigns = Setting.plugin_redmine_agile['issues_per_column'].to_i
      by_settigns > 0 ? by_settigns : ISSUES_PER_COLUMN
    end

    def default_columns
      Setting.plugin_redmine_agile['default_columns'].to_a
    end

    def default_chart
      Setting.plugin_redmine_agile['default_chart'] || Charts::BURNDOWN_CHART
    end

    def estimate_units
      Setting.plugin_redmine_agile['estimate_units'] || 'hours'
    end

    def use_story_points?
      estimate_units == 'story_points'
    end

    def trackers_for_sp
      Setting.plugin_redmine_agile['trackers_for_sp']
    end

    def use_story_points_for?(tracker)
      return true if trackers_for_sp.blank?
      tracker = tracker.is_a?(Tracker) ? tracker.id.to_s : tracker
      trackers_for_sp == tracker
    end

    def use_colors?
      COLOR_BASE.include?(color_base)
                end

    def color_base
      Setting.plugin_redmine_agile['color_on'] || 'none'
                end

    def minimize_closed?
      Setting.plugin_redmine_agile['minimize_closed'].to_i > 0
    end

    def exclude_weekends?
      Setting.plugin_redmine_agile['exclude_weekends'].to_i > 0
    end

    def auto_assign_on_move?
      Setting.plugin_redmine_agile['auto_assign_on_move'].to_i > 0
    end
    def color_prefix
      'bk'
    end

    COLOR_BASE.each do |cb|
      define_method :"#{cb}_colors?" do
        color_base == cb
      end
    end

    def status_colors?
      Setting.plugin_redmine_agile['status_colors'].to_i > 0
                end

    def hide_closed_issues_data?
      Setting.plugin_redmine_agile['hide_closed_issues_data'].to_i > 0
    end

    def use_checklist?
      @@chcklist_plugin_installed ||= (Redmine::Plugin.installed?(:redmine_checklists))
    end

    def allow_create_card?
      Setting.plugin_redmine_agile['allow_create_card'].to_i > 0
          end

    def allow_inline_comments?
      Setting.plugin_redmine_agile['allow_inline_comments'].to_i > 0
    end
    def sp_values
      Setting.plugin_redmine_agile['sp_values'].to_s.split(',').map{|x| x.strip.to_i}.uniq.delete_if{|x| x == 0}
    end
  end

end
