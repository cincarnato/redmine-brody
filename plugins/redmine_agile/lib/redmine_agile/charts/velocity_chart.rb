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

module RedmineAgile
  class VelocityChart < AgileChart
    def initialize(data_scope, options = {})
      @date_from = (options[:date_from] || data_scope.minimum("#{Issue.table_name}.created_on")).to_date
      @date_to = options[:date_to] || Date.today
      super data_scope, options
      @line_colors = { :closed => '102,102,102', :created => '80,122,170' }
    end

    def data
      created_by_period = issues_avg_count_by_period(scope_by_created_date)
      closed_by_period = issues_avg_count_by_period(scope_by_closed_date)

      if @scale_division > 1
        y_title = l(:label_agile_charts_avarate_number_of_issues)
        graph_title = l(:label_agile_charts_average_velocity)
      else
        y_title = l(:label_agile_charts_number_of_issues)
        graph_title = l(:label_agile_charts_issues_velocity)
      end

      datasets = []
      if closed_by_period.any?
        datasets << dataset(closed_by_period, l(:field_closed_on), :type => 'bar', :fill => true, :color => line_colors[:closed])
        datasets << dataset(trendline(closed_by_period), l(:field_closed_on_trendline), :nopoints => true, :dashed => true, :color => line_colors[:closed])
      end

      if created_by_period.any?
        datasets << dataset(created_by_period, l(:field_created_on), :type => 'bar', :fill => true, :color => line_colors[:created])
        datasets << dataset(trendline(created_by_period), l(:field_created_on_trendline), :nopoints => true, :dashed => true, :color => line_colors[:created])
      end

      show_tooltips = []
      (0..datasets.size).each do |i|
        show_tooltips << i if i % 2 == 0
      end

      {
        :title    => graph_title,
        :y_title  => y_title,
        :labels   => @fields,
        :datasets => datasets,
        :show_tooltips => show_tooltips
      }
    end
  end
end
