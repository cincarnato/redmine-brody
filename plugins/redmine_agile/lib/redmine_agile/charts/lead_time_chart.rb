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
  class LeadTimeChart < AgileChart
    def initialize(data_scope, options = {})
      @date_from = (options[:date_from] || data_scope.minimum("#{Issue.table_name}.created_on")).to_date
      @date_to = options[:date_to] || Date.today
      @average_lead_time = !!options[:average_lead_time]
      super data_scope, options
      @line_colors = { :closed => '102,102,102' }
    end

    def data
      chart_data = lead_time_data
      datasets = []
      if chart_data.any?
        datasets << dataset(chart_data, l(:field_closed_on), :type => 'bar', :fill => true, :color => line_colors[:closed])
        datasets << dataset(trendline(chart_data), l(:field_closed_on_trendline), :nopoints => true, :dashed => true, :color => line_colors[:closed])
      end
      {
        :title    => l(:label_agile_charts_lead_time),
        :y_title  => l(:label_agile_charts_number_of_days),
        :labels   => @fields,
        :datasets => datasets,
        :show_tooltips => [0]
      }
    end

    private

    def lead_time_data
      lead_time_by_date = closed_issues.map { |c| { :closed_on => c.closed_on.localtime, :lead_time => (c.closed_on.to_time.localtime - c.created_on.localtime.to_time).to_f / (60 * 60 * 24) } }
      lead_time_arr_by_period = {}
      lead_time_by_date.each do |c|
        next if c[:closed_on].to_date > @date_to.to_date
        period_num = ((@date_to.to_date - c[:closed_on].localtime.to_date).to_i / @scale_division).to_i
        lead_time_arr_by_period[period_num] = [] if lead_time_arr_by_period[period_num].blank?
        lead_time_arr_by_period[period_num] << c[:lead_time]
      end

      lead_time_by_period = [0] * @period_count
      (0..@period_count - 1).each do |period_num|
        next if lead_time_arr_by_period[period_num].blank?
        arr = lead_time_arr_by_period[period_num]
        len = arr.length
        half_len = len / 2
        sorted = arr.sort
        median = len % 2 == 1 ? sorted[half_len] : (sorted[half_len - 1] + sorted[half_len]).to_f / 2
        lead_time_by_period[period_num] = median.round(2)
      end
      lead_time_by_period.reverse!
    end

    def closed_issues
      @closed_issues ||= @data_scope.open(false).where("#{Issue.table_name}.closed_on IS NOT NULL").
                         where("#{Issue.table_name}.closed_on >= ?", @date_from).
                         where("#{Issue.table_name}.closed_on < ?", @date_to + 1).
                         where("#{Issue.table_name}.created_on IS NOT NULL")
    end
  end
end
