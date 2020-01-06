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
require File.expand_path(File.dirname(__FILE__) + '/../../../../test/test_helper')


class RedmineContacts::CommonViewsTest < ActiveRecord::VERSION::MAJOR >= 4 ? Redmine::ApiTest::Base : ActionController::IntegrationTest
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
                                                                                                                    :deals_issues,
                                                                                                                    :deals,
                                                                                                                    :deal_statuses,
                                                                                                                    :notes,
                                                                                                                    :tags,
                                                                                                                    :taggings,
                                                                                                                    :queries])

  def setup
    RedmineContacts::TestCase.prepare
  end

  test 'View user' do
    log_user('admin', 'admin')
    compatible_request :get, '/users/2'
    assert_response :success
  end

  test 'View contacts activity' do
    log_user('admin', 'admin')
    compatible_request :get, '/projects/ecookbook/activity?show_contacts=1'
    assert_response :success
  end

  test 'View contacts settings' do
    log_user('admin', 'admin')
    compatible_request :get, '/settings/plugin/redmine_contacts'
    assert_response :success
  end

  test 'View contacts project settings' do
    log_user('admin', 'admin')
    compatible_request :get, '/projects/ecookbook/settings/contacts'
    assert_response :success
  end

  test 'View contact tag edit' do
    log_user('admin', 'admin')
    compatible_request :get, '/contacts_tags/1/edit'
    assert_response :success
  end
  test 'View deal status edit' do
    log_user('admin', 'admin')
    compatible_request :get, '/deal_statuses/1/edit'
    assert_response :success
  end

  test 'View My page with contacts and deals blocks' do
    log_user('rhill', 'foo')
    user = User.where(:login => 'rhill').first
    Contact.all.each { |c| c.assigned_to = user; c.save }
    preferences = user.pref
    preferences[:my_page_layout] = { 'top' => ['my_contacts', 'my_deals'] }
    preferences.save!

    compatible_request :get, '/my/page'
    assert_response :success
    assert_select 'span.contact', 'Domoway'
  end

  def test_new_custom_field
    log_user('admin', 'admin')
    compatible_request :get, '/custom_fields/new', :type => 'ContactCustomField'
    assert_response :success

    compatible_request :get, '/custom_fields/new', :type => 'DealCustomField'
    assert_response :success
  end

  test 'Global search with contacts' do
    log_user('admin', 'admin')
    compatible_request :get, '/search?q=Domoway'
    assert_response :success
  end

  test 'View contacts project notes list' do
    log_user('admin', 'admin')
    compatible_request :get, '/projects/ecookbook/contacts/notes'
    assert_response :success
  end

  test 'View contacts notes list' do
    log_user('admin', 'admin')
    compatible_request :get, '/contacts/notes'
    assert_response :success
  end

  test 'View issue contacts' do
    log_user('admin', 'admin')
    EnabledModule.create(:project_id => 1, :name => 'issue_tracking')
    issue = Issue.where(:id => 1).first
    contact = Contact.where(:id => 1).first
    issue.contacts << contact
    issue.save
    compatible_request :get, '/issues/1'
    assert_response :success
  end

  test 'View user with contact relation' do
    log_user('admin', 'admin')
    compatible_request :get, '/users/2'
    assert_response :success
    # assert_tag :div,
    #   :content => /John Smith/,
    #   :attributes => { :class => 'contact card' }
  end
end
