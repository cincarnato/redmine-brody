# encoding: utf-8
#
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


require File.expand_path('../../test_helper', __FILE__)

class DealTest < ActiveSupport::TestCase
  fixtures :projects, :users

  RedmineContacts::TestCase.create_fixtures(
    Redmine::Plugin.find(:redmine_contacts).directory + '/test/fixtures/', [:contacts, :contacts_projects,
                                                                            :deals, :deal_statuses]
  )

  def test_price_to_s_with_custome_settings
    Setting.plugin_redmine_contacts['decimal_separator'] = '.'
    Setting.plugin_redmine_contacts['thousands_delimiter'] = ' '
    assert_equal '$3 000.00', Deal.find(1).price_to_s
  end

  def test_count_for_status_scope
    project = Project.find(2)
    assert_equal 1, project.deals.with_status(1).count
    assert_equal 2, project.deals.with_status(2).count
    assert_equal 1, project.deals.with_status(3).count
  end

  def test_price_with_big_value
    Setting.plugin_redmine_contacts['decimal_separator'] = '.'
    Setting.plugin_redmine_contacts['thousands_delimiter'] = ' '
    deal = Deal.find(5)
    price = deal.price
    deal.update_attributes(:price => 9999999999999)
    assert_equal '9 999 999 999 999.00 RUB', Deal.find(5).price_to_s
  ensure
    deal.update_attributes(:price => price)
  end
end
