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
  class AverageLeadTimeChart < LeadTimeChart
    def initialize(data_scope, options = {})
      @date_from = (options[:date_from] || data_scope.minimum("#{Issue.table_name}.created_on")).to_date
      @date_to = options[:date_to] || Date.today
      @average_lead_time = !!options[:average_lead_time]
      super data_scope, options
      @line_colors = { :closed => '247,175,125' }
    end

    def data
      chart_data = average_lead_time_data
      datasets = []
      datasets << dataset(chart_data, l(:field_closed_on), :color => line_colors[:closed]) if chart_data.any?

      {
        :title    => l(:label_agile_charts_lead_time),
        :y_title  => l(:label_agile_charts_number_of_days),
        :labels   => @fields,
        :datasets => datasets,
        :show_tooltips => [0]
      }
    end

    private

    def average_lead_time_data
      lead_time_by_date = closed_issues.map { |c| { :closed_on => c.closed_on, :lead_time => (c.closed_on.to_time - c.created_on.to_time).to_f / (60 * 60 * 24) } }
      lead_time_by_period = [0] * @period_count
      lead_time_by_date.each do |c|
        next if c[:closed_on].to_date > @date_to.to_date
        period_num = (@date_to.to_date - c[:closed_on].to_date).to_i / @scale_division
        if lead_time_by_period[period_num]
          lead_time_by_period[period_num] = c[:lead_time] unless lead_time_by_period[period_num].to_i > 0
          lead_time_by_period[period_num] = ((lead_time_by_period[period_num].to_f + c[:lead_time]).to_f / 2).round(2)
        end
      end
      lead_time_by_period.reverse!

      prev_lead_time = lead_time_by_period[0]
      lead_time_by_period.each_with_index do |c, index|
        lead_time_by_period[index] = c == 0 ? prev_lead_time : ((c + prev_lead_time).to_f / 2).round(2)
        prev_lead_time = lead_time_by_period[index]
      end

      lead_time_by_period
    end
  end
end
