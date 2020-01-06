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

class IssuesControllerTest < ActionController::TestCase
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
                                                                                                                    :notes,
                                                                                                                    :tags,
                                                                                                                    :taggings,
                                                                                                                    :queries])

  def setup
    RedmineContacts::TestCase.prepare
    User.current = nil
    @request.session[:user_id] = 1
  end

  def test_get_show_issue_with_deal_and_contacts
    compatible_request :get, :show, :id => 1
    assert_response :success
    assert_select '#issue_contacts span.contact a', /Marat Aminov/
    if Redmine::VERSION.to_s >= '3.2'
      assert_select 'div.value a', /Ivan Ivanov: First deal with contacts/
    else
      assert_select 'td a', /Ivan Ivanov: First deal with contacts/
    end
  end
  def test_get_index_with_contacts_and_deals
    compatible_request :get, :index, :f => ['status_id', 'companies', 'deal', ''],
                                     :op => { :status_id => 'o', :companies => '=', :deal => '=' },
                                     :v => { :companies => ['3'], :deal => ['2'] },
                                     :c => ['subject', 'contacts_relations', 'deal'],
                                     :project_id => 'ecookbook'
    assert_response :success
    assert_select 'table.list.issues td.contacts span.contact a', /Marat Aminov/
    assert_select 'table.list.issues td.deal a', /Second deal with contacts/
  end

  def test_get_issues_without_contacts
    compatible_request :get, :index, :f => ['status_id', 'contacts', ''],
                                     :op => { :status_id => '*', :contacts => '!*' },
                                     :c => ['subject', 'contacts_relations'],
                                     :project_id => 'ecookbook'
    assert_response :success
    assert_select 'table.list.issues td.contacts', ''
  end

  def test_get_issues_only_with_contacts
    compatible_request :get, :index, :f => ['status_id', 'contacts', ''],
                                     :op => { :status_id => '*', :contacts => '*' },
                                     :c => ['subject', 'contacts_relations'],
                                     :project_id => 'ecookbook'
    assert_response :success
    assert_select 'table.list.issues td.contacts'
  end

  def test_get_new_with_deal
    compatible_request :get, :new, :project_id => 'ecookbook', :deal_id => 1
    assert_response :success
    assert_select 'select#issue_deals_issue_attributes_deal_id', /First deal with contacts/
    if ActiveRecord::VERSION::MAJOR >= 4
      assert_select "#issue_deals_issue_attributes_deal_id option[value='1']"
    else
      assert_select '#issue_deals_issue_attributes_deal_id option[value=?]', 1
    end
  end

  def test_get_new_with_permission_edit_deals
    # User(id: 2) has role Developer in Project(id: 2) and role Developer has permission :edit_deals
    @request.session[:user_id] = 2
    compatible_request :get, :new, issue: { project_id: 2 }
    assert_select '#issue_deals_issue_attributes_deal_id'
  end

  def test_get_new_without_permission_edit_deals
    @request.session[:user_id] = 2
    developer_role = Role.find(2)
    developer_role.remove_permission! :edit_deals
    compatible_request :get, :new, issue: { project_id: 2 }
    assert_select '#issue_deals_issue_attributes_deal_id', 0
  end

  def test_get_new_with_permission_edit_deals_in_other_project
    # User(id: 2) has role Manager in Project(id: 1) and role Developer in Project(id: 2)
    @request.session[:user_id] = 2
    manager_role = Role.find(1)
    manager_role.remove_permission! :edit_deals
    compatible_request :get, :new, issue: { project_id: 1 }
    assert_select '#issue_deals_issue_attributes_deal_id', 0
  end

  def test_get_edit_with_permission_edit_deals
    @request.session[:user_id] = 2
    compatible_request :get, :edit, id: 1, issue: { project_id: 2 }
    assert_select '#issue_deals_issue_attributes_deal_id'
  end

  def test_get_edit_without_permission_edit_deals
    @request.session[:user_id] = 2
    developer_role = Role.find(2)
    developer_role.remove_permission! :edit_deals
    compatible_request :get, :edit, id: 1, issue: { project_id: 2 }
    assert_select '#issue_deals_issue_attributes_deal_id', 0
  end

  def test_get_edit_with_permission_edit_deals_in_other_project
    # User(id: 2) has role Manager in Project(id: 1) and role Developer in Project(id: 2)
    @request.session[:user_id] = 2
    manager_role = Role.find(1)
    manager_role.remove_permission! :edit_deals
    compatible_request :get, :edit, id: 1, issue: { project_id: 1 }
    assert_select '#issue_deals_issue_attributes_deal_id', 0
  end

  def test_post_create_with_deal
    assert_difference 'DealsIssue.count' do
      compatible_request :post, :create, :issue => { :tracker_id => 3, :subject => 'test', :status_id => 2, :priority_id => 5,
                                                     :deals_issue_attributes => { :deal_id => 1 } },
                                         :project_id => 'ecookbook'
    end

    issue = Issue.order('id ASC').last
    assert_redirected_to :controller => 'issues', :action => 'show', :id => issue.id
    assert_not_nil issue.deal
  end

  def test_post_create_with_invalid_deal_id
    assert_no_difference 'Issue.count' do
      compatible_request :post, :create, :issue => { :tracker_id => 3, :subject => 'test', :status_id => 2, :priority_id => 5,
                                                     :deals_issue_attributes => { :deal_id => 'abc' } },
                                         :project_id => 'ecookbook'
    end
  end

  def test_put_update_form
    issue = Issue.find(1)
    if ActiveRecord::VERSION::MAJOR < 4
      compatible_xhr_request :put, :update_form, :issue => { :tracker_id => 2,
                                                             :deals_issue_attributes => { :deal_id => 2 } },
                                                 :project_id => issue.project
      assert_response :success
      assert_equal 'text/javascript', response.content_type

      issue = assigns(:issue)
      assert_kind_of Issue, issue
      assert_equal 2, issue.deals_issue.deal_id
    end
  end
end
