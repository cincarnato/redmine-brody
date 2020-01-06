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

class DealsPipelineProcessor
  attr_reader :scope

  def initialize(scope)
    @scope = scope
  end

  def count
    @scope.count
  end

  def deals_for_status(status)
    if status.is_open?
      open_deals_for_status(status) + closed_deals_for_status(status)
    else
      @scope.where(:status_id => status.id)
    end
  end

  def closed_deals_for_status(status)
    deal_status_ids = DealStatus.open.where('position >= ?', status.position).pluck(:id)
    first_condition = []
    second_condition = []
    if lost_status_ids.present?
      first_condition << "dp.value IN (#{lost_status_ids.join(',')})"
      second_condition << "dp2.value IN (#{lost_status_ids.join(',')})"
    end
    if won_status_ids.present?
      first_condition << "dp.old_value IN (#{won_status_ids.join(',')})"
      second_condition << "dp2.old_value IN (#{won_status_ids.join(',')})"
    end
    first_sql = first_condition.present? ? "NOT (#{first_condition.join(' AND ')})" : '1=1'
    second_sql = second_condition.present? ? "NOT (#{second_condition.join(' AND ')})" : '1=1'
    ret = @scope.closed.joins("LEFT OUTER JOIN #{DealProcess.table_name} dp on dp.deal_id = deals.id AND #{first_sql}").
      joins("LEFT OUTER JOIN #{DealProcess.table_name} dp2 ON (deals.id = dp2.deal_id AND (dp.created_at < dp2.created_at OR dp.created_at = dp2.created_at AND dp.id < dp2.id)) AND #{second_sql}").
      joins("LEFT OUTER JOIN #{DealStatus.table_name} ds ON (ds.id = deals.status_id)").
      where(['ds.status_type IN (?)', [DealStatus::WON_STATUS, DealStatus::LOST_STATUS] ]).
      where("dp2.id IS NULL")
    if status.is_open?
      ret.where(["(dp.old_value IN (?) OR (#{Deal.table_name}.status_id IN (?)))", deal_status_ids, won_status_ids])
    else
      ret.where(["dp.old_value IN (?)", deal_status_ids])
    end
  end

  def open_deals_for_status(status)
    deal_status_ids = DealStatus.open.where('position >= ?', status.position).pluck(:id)
    @scope.open.joins("LEFT OUTER JOIN #{DealStatus.table_name} ds ON (ds.id = deals.status_id)").
      where(['ds.status_type NOT IN (?)', [DealStatus::WON_STATUS, DealStatus::LOST_STATUS] ]).
      where(["#{Deal.table_name}.status_id IN (?)", deal_status_ids])
  end

  def won_status_ids
    @won_status_ids ||= DealStatus.won.pluck(:id)
  end

  def lost_status_ids
    @lost_status_ids ||= DealStatus.lost.pluck(:id)
  end
end
