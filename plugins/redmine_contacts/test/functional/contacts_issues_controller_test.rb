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

class ContactsIssuesControllerTest < ActionController::TestCase
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
    RedmineContacts::TestCase.prepare
    User.current = nil
  end

  def test_create_issue
    @request.session[:user_id] = 1
    @request.env['HTTP_REFERER'] = '/contacts/1'
    parameters = { :issue => { :subject => 'Test subject', :assigned_to_id => '1', :due_date => Date.today.to_s, :description => 'Test descripiton', :tracker_id => '1' } }
    assert_difference('Issue.count') do
      assert_difference('ContactsIssue.count') do
        compatible_request :post, :create_issue, { :project_id => 1, :id => 1 }.merge!(parameters)
      end
    end
    assert_response 302
  end

  def test_delete
    @request.session[:user_id] = 1
    ContactsIssue.create(:contact_id => 1, :issue_id => 1)
    assert_difference('ContactsIssue.count', -1) do
      compatible_xhr_request :delete, :delete, :project_id => 1, :id => 1, :issue_id => 1
    end
    assert_response :success
  end

  def test_close
    @request.session[:user_id] = 1
    assert_not_nil Issue.find(1)
    compatible_xhr_request :post, :close, :issue_id => 1
    assert_response :success
  end

  def test_autocomplete_for_contact
    @request.session[:user_id] = 1
    compatible_xhr_request :get, :autocomplete_for_contact, :q => 'domo', :issue_id => '1', :project_id => 'ecookbook', :cross_project_contacts => '1'
    assert_response :success
    assert_select 'input', :count => 1
    if ActiveRecord::VERSION::MAJOR >= 4
      assert_select "input[name='contacts_issue[contact_ids][]'][value='3']"
    else
      assert_select 'input[name=?][value=3]', 'contacts_issue[contact_ids][]'
    end
  end

  def test_autocomplete_for_contact_cross_contacts
    @request.session[:user_id] = 2

    compatible_xhr_request :get, :autocomplete_for_contact, :q => 'a', :issue_id => '4', :project_id => 'onlinestore', :cross_project_contacts => '0'
    assert_response :success
    assert_select 'span.contact', :count => 1
    assert_select 'span.contact', /Ivan Ivanov/

    compatible_xhr_request :get, :autocomplete_for_contact, :q => 'a', :issue_id => '4', :project_id => 'onlinestore', :cross_project_contacts => '1'
    assert_response :success
    assert_select 'span.contact', :count => 4
    assert_select 'span.contact', /Domoway/
    assert_select 'span.contact', /Ivan Ivanov/
    assert_select 'span.contact', /Marat Aminov/
    assert_select 'span.contact', /My company/
  end

  def test_new
    @request.session[:user_id] = 1
    compatible_xhr_request :get, :new, :issue_id => '1'
    assert_response :success
    assert_match /ajax-modal/, response.body
  end

  def test_create_multiple
    @request.session[:user_id] = 1
    assert_difference('ContactsIssue.count', 2) do
      compatible_xhr_request :post, :create, :issue_id => '2', :contacts_issue => {:contact_ids => ['3', '4']}
      assert_response :success
      assert_match /contacts/, response.body
      assert_match /ajax-modal/, response.body
    end
    assert Issue.find(2).contact_ids.include?(3)
    assert Issue.find(2).contact_ids.include?(4)
  end
end
