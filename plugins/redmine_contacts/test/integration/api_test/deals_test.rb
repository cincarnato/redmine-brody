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

require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')

class Redmine::ApiTest::DealsTest < ActiveRecord::VERSION::MAJOR >= 4 ? Redmine::ApiTest::Base : ActionController::IntegrationTest
  fixtures :projects,
           :users,
           :roles,
           :members,
           :member_roles,
           :issues,
           :issue_statuses,
           :versions,
           :trackers,
           :projects_trackers,
           :issue_categories,
           :enabled_modules,
           :enumerations,
           :attachments,
           :workflows,
           :custom_fields,
           :custom_values,
           :custom_fields_projects,
           :custom_fields_trackers,
           :time_entries,
           :journals,
           :journal_details,
           :queries

  RedmineContacts::TestCase.create_fixtures(Redmine::Plugin.find(:redmine_contacts).directory + '/test/fixtures/', [:contacts,
                                                                                                                    :contacts_projects,
                                                                                                                    :contacts_issues,
                                                                                                                    :deals,
                                                                                                                    :notes,
                                                                                                                    :tags,
                                                                                                                    :taggings,
                                                                                                                    :queries])

  def setup
    Setting.rest_api_enabled = '1'
    RedmineContacts::TestCase.prepare
  end

  test 'GET /deals.xml' do
    # Use a private project to make sure auth is really working and not just
    # only showing public issues.
    Redmine::ApiTest::Base.should_allow_api_authentication(:get, '/projects/private-child/deals.xml') if ActiveRecord::VERSION::MAJOR < 4
    compatible_api_request :get, '/deals.xml', {}, credentials('admin')

    att = { :type => 'array', :total_count => 2, :limit => 25, :offset => 0 }
    assert_select 'deals', :attributes => att
  end

  test 'POST /deals.xml' do
    if ActiveRecord::VERSION::MAJOR < 4
      Redmine::ApiTest::Base.should_allow_api_authentication(:post, '/deals.xml', { :deal => { :project_id => 1, :name => 'API test', :contact_id => 1 } },
                                                                                  { :success_code => :created })
    end

    assert_difference('Deal.count') do
      compatible_api_request :post, '/deals.xml', { :deal => { :project_id => 1, :name => 'API test', :contact_id => 1 } }, credentials('admin')
    end

    deal = Deal.order('id DESC').first
    assert_equal 'API test', deal.name

    assert_response :created
    assert_equal 'application/xml', @response.content_type
    assert_select 'deal', :child => { :tag => 'id', :content => deal.id.to_s }
  end

  # Issue 6 is on a private project
  test 'PUT /deals/1.xml' do
    @parameters = { :deal => { :name => 'API update' } }

    if ActiveRecord::VERSION::MAJOR < 4
      Redmine::ApiTest::Base.should_allow_api_authentication(:put, '/deals/1.xml', { :deal => { :name => 'API update' } },
                                                                                   { :success_code => :ok })
    end

    assert_no_difference('Deal.count') do
      compatible_api_request :put, '/deals/1.xml', @parameters, credentials('admin')
    end

    deal = Deal.where(:id => 1).first
    assert_equal 'API update', deal.name
  end

  def test_post_with_custom_fields
    field = DealCustomField.create!(:name => 'Test', :field_format => 'int')
    assert_difference('Deal.count') do
      compatible_api_request :post, '/deals.xml', { :deal => { :project_id => 1, :name => 'API test',
                                                               :custom_fields => [{ 'id' => field.id.to_s, 'value' => '14' }] } },
                                                  credentials('admin')
    end
    deal = Deal.last
    assert_equal '14', deal.custom_value_for(field.id).value
  end

  def test_put_with_custom_fields
    field = DealCustomField.create!(:name => 'Test', :field_format => 'text')
    assert_no_difference('Deal.count') do
      compatible_api_request :put, '/deals/1.xml', { :deal => { :custom_fields => [{ 'id' => field.id.to_s, 'value' => 'Hello deal' }] } },
                                                   credentials('admin')
    end
    deal = Deal.where(:id => 1).first
    assert_equal 'Hello deal', deal.custom_value_for(field.id).value
  end
end
