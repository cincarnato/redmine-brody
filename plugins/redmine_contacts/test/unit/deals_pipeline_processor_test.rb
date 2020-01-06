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

class DealsPipelineProcessorTest < ActiveSupport::TestCase
  fixtures :projects, :users

  RedmineContacts::TestCase.create_fixtures(Redmine::Plugin.find(:redmine_contacts).directory + '/test/fixtures/', [:contacts,
                                                                                                                    :contacts_projects,
                                                                                                                    :deals,
                                                                                                                    :deal_statuses,
                                                                                                                    :deal_categories])

  def setup
    Deal.destroy_all
    @deal_status_new = DealStatus.find(1)
    @deal_status_won = DealStatus.find(2)
    @deal_status_lost = DealStatus.find(3)
    @deal_status_intermediate1 = DealStatus.find(4)
    @deal_status_intermediate2 = DealStatus.find(5)
  end

  def test_constructor
    assert_not_nil DealsPipelineProcessor.new(Deal)
  end

  def test_closed_deal_counts_in_last_unclosed_status
    @deal = Deal.create!(:status => @deal_status_new, :name => 'New deal', :project => Project.last)
    @deal.init_deal_process(User.first)
    @deal.update_attribute(:status, @deal_status_won)
    assert_equal(1, DealProcess.count)
    processor = DealsPipelineProcessor.new(Deal)
    assert_equal(1, processor.deals_for_status(@deal_status_new).count)
  end

  def test_open_deal_counts_in_last_unclosed_status
    @deal = Deal.create!(:status => @deal_status_new, :name => 'New deal', :project => Project.last)
    @deal.init_deal_process(User.first)
    @deal.update_attribute(:status, @deal_status_intermediate1)
    assert_equal(1, DealProcess.count)
    processor = DealsPipelineProcessor.new(Deal)
    assert_equal(1, processor.deals_for_status(@deal_status_new).count)
  end

  def test_if_asked_in_status_returns_simple_case
    @deal = Deal.create!(:status => @deal_status_new, :name => 'New deal', :project => Project.last)
    @deal.init_deal_process(User.first)
    @deal.update_attribute(:status, @deal_status_won)

    @deal = Deal.create!(:status => @deal_status_new, :name => 'New deal 2', :project => Project.last)
    @deal.init_deal_process(User.first)
    @deal.update_attribute(:status, @deal_status_intermediate1)

    assert_equal(2, DealProcess.count)
    processor = DealsPipelineProcessor.new(Deal)
    assert_equal(1, processor.deals_for_status(@deal_status_won).count)
  end

  def test_if_deal_jumped_over_status
    @deal = Deal.create!(:status => @deal_status_new, :name => 'New deal', :project => Project.last)
    @deal.init_deal_process(User.first)
    @deal.update_attribute(:status, @deal_status_intermediate2)

    processor = DealsPipelineProcessor.new(Deal)
    assert_equal(1, processor.deals_for_status(@deal_status_intermediate1).count)
  end

  def test_if_deal_returned_from_lost
    @deal = Deal.create!(:status => @deal_status_new, :name => 'New deal', :project => Project.last)
    @deal.init_deal_process(User.first)
    @deal.update_attribute(:status, @deal_status_lost)
    @deal.update_attribute(:status, @deal_status_intermediate2)

    processor = DealsPipelineProcessor.new(Deal)
    assert_equal(1, processor.deals_for_status(@deal_status_intermediate1).count)
  end
end
