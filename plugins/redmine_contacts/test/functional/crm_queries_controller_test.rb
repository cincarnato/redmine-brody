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

class CrmQueriesControllerTest < ActionController::TestCase
  fixtures :projects, :users, :members, :member_roles, :roles, :trackers, :issue_statuses, :enumerations, :issues

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
    @request.session[:user_id] = 1
  end

  def test_get_new_project_query
    compatible_request :get, :new, :project_id => 1, :object_type => 'contact'
    assert_response :success
    att = { :type => 'checkbox',
            :name => 'query_is_for_all',
            :checked => nil,
            :disabled => nil }
    assert_select 'input', :attributes => att
  end

  def test_get_new_global_query
    compatible_request :get, :new, :object_type => 'contact'
    assert_response :success
    att = { :type => 'checkbox',
            :name => 'query_is_for_all',
            :checked => 'checked',
            :disabled => nil }
    assert_select 'input', :attributes => att
  end

  def test_post_create_project_public_query
    if Redmine::VERSION.to_s < '2.4'
      query_params = { 'name' => 'test_new_project_public_contacts_query', 'is_public' => '1' }
    else
      query_params = { 'name' => 'test_new_project_public_contacts_query', 'visibility' => '2' }
    end

    compatible_request :post, :create,
                              :project_id => 'ecookbook',
                              :object_type => 'contact',
                              :default_columns => '1',
                              :f => ['first_name', 'last_name'],
                              :op => { 'first_name' => '=', 'last_name' => '=' },
                              :v => { 'first_name' => ['Ivan'], 'last_name' => ['Ivanov'] },
                              :query => query_params

    q = ContactQuery.find_by_name('test_new_project_public_contacts_query')
    assert_redirected_to :controller => 'contacts', :action => 'index', :project_id => 'ecookbook', :query_id => q
    assert q.is_public?
    assert q.has_default_columns?
    assert q.valid?
  end

  def test_post_create_project_private_query

    if Redmine::VERSION.to_s < '2.4'
      query_params = { 'name' => 'test_new_project_public_contacts_query', 'is_public' => '0' }
    else
      query_params = { 'name' => 'test_new_project_public_contacts_query', 'visibility' => '0' }
    end

    compatible_request :post, :create,
                              :project_id => 'ecookbook',
                              :object_type => 'contact',
                              :default_columns => '1',
                              :f => ['first_name', 'last_name'],
                              :op => { 'first_name' => '=', 'last_name' => '=' },
                              :v => { 'first_name' => ['Ivan'], 'last_name' => ['Ivanov'] },
                              :query => query_params

    q = ContactQuery.find_by_name('test_new_project_public_contacts_query')
    assert_redirected_to :controller => 'contacts', :action => 'index', :project_id => 'ecookbook', :query_id => q
    assert !q.is_public?
    assert q.has_default_columns?
    assert q.valid?
  end

  def test_put_update_global_public_query

    if Redmine::VERSION.to_s < '2.4'
      query_params = { 'name' => 'test_edit_global_public_query', 'is_public' => '1' }
    else
      query_params = { 'name' => 'test_edit_global_public_query', 'visibility' => '2' }
    end

    compatible_request :put, :update,
                             :id => 2,
                             :object_type => 'contact',
                             :default_columns => '1',
                             :fields => ['first_name', 'last_name'],
                             :operators => { 'first_name' => '=', 'last_name' => '=' },
                             :values => { 'first_name' => ['Ivan'], 'last_name' => ['Ivanov'] },
                             :query => query_params

    assert_redirected_to :controller => 'contacts', :action => 'index', :project_id => 'ecookbook', :query_id => 2
    q = ContactQuery.find_by_name('test_edit_global_public_query')
    assert q.is_public?
    assert q.has_default_columns?
    assert q.valid?
  end

  def test_delete_destroy
    compatible_request :delete, :destroy, :id => 2, :object_type => 'contact'
    assert_redirected_to :controller => 'contacts', :action => 'index', :project_id => 'ecookbook', :set_filter => 1, :query_id => nil
    assert_nil Query.find_by_id(2)
  end


  def test_post_create_query_with_grouping
    query_params = { 'name' => 'test_new_contacts_query_with_grouping', 'group_by' => 'status' }

    compatible_request :post, :create,
                              :project_id => 'ecookbook',
                              :object_type => 'contact',
                              :default_columns => '1',
                              :f => ['first_name', 'last_name'],
                              :op => { 'first_name' => '=', 'last_name' => '=' },
                              :v => { 'first_name' => ['Ivan'], 'last_name' => ['Ivanov'] },
                              :query => query_params

    q = ContactQuery.find_by_name('test_new_contacts_query_with_grouping')
    assert_equal false, q.group_by.blank?
    assert q.group_by == 'status'
    assert q.valid?
  end

  def test_post_create_query_with_sorting
    sort_criteria = { "0" => ["order_number", "asc"], "1" => ["", ""], "2" => ["", ""] }
    query_params = { 'name' => 'test_new_contacts_query_with_sorting', 'sort_criteria' => sort_criteria }

    compatible_request :post, :create,
                              :project_id => 'ecookbook',
                              :object_type => 'contact',
                              :default_columns => '1',
                              :f => ['first_name', 'last_name'],
                              :op => { 'first_name' => '=', 'last_name' => '=' },
                              :v => { 'first_name' => ['Ivan'], 'last_name' => ['Ivanov'] },
                              :query => query_params

    q = ContactQuery.find_by_name('test_new_contacts_query_with_sorting')
    assert_equal false, q.sort_criteria.blank?
    assert q.sort_criteria[0] == ["order_number", "asc"]
    assert q.valid?
  end

  def test_post_create_query_for_roles_visibility
    query_params = { 'name' => 'test_new_query_with_roles_visibility', 'visibility' => Query::VISIBILITY_ROLES.to_s, 'role_ids' => ['1'] }

    compatible_request :post, :create, project_id: 'ecookbook',
                                       object_type: 'contact',
                                       default_columns: '1',
                                       query: query_params

    q = ContactQuery.find_by_name('test_new_query_with_roles_visibility')
    assert_redirected_to controller: 'contacts', action: 'index', project_id: 'ecookbook', query_id: q
    assert q.valid?
    assert_equal [1], q.role_ids
  end
end
