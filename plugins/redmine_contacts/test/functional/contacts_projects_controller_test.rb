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

class ContactsProjectsControllerTest < ActionController::TestCase
  fixtures :projects,
           :users,
           :roles,
           :members,
           :member_roles,
           :versions,
           :trackers,
           :projects_trackers,
           :enabled_modules,
           :enumerations,
           :attachments,
           :workflows,
           :time_entries

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

  def test_delete_destroy
    @request.session[:user_id] = 1
    contact = Contact.find(1)
    assert_equal 2, contact.projects.size
    compatible_xhr_request :delete, :destroy, :project_id => 1, :id => 2, :contact_id => 1
    assert_response :success
    assert_include 'contact_projects', response.body

    contact.reload
    assert_equal [1], contact.project_ids
  end

  def test_delete_destroy_last_project
    @request.session[:user_id] = 1
    contact = Contact.find(1)
    assert RedmineContacts::TestCase.is_arrays_equal(contact.project_ids, [1, 2])
    compatible_xhr_request :delete, :destroy, :project_id => 1, :id => 2, :contact_id => 1
    assert_response :success
    compatible_xhr_request :delete, :destroy, :project_id => 1, :id => 1, :contact_id => 1
    assert_response 403

    contact.reload
    assert_equal [1], contact.project_ids
  end

  def test_post_new
    @request.session[:user_id] = 1

    compatible_xhr_request :post, :new, :project_id => 'ecookbook', :id => 2, :contact_id => 2
    assert_response :success
    assert_include 'contact_projects', response.body
    contact = Contact.find(2)
    assert RedmineContacts::TestCase.is_arrays_equal(contact.project_ids, [1, 2])
  end

  def test_double_create
    @request.session[:user_id] = 1

    compatible_xhr_request :post, :create, :project_id => 'ecookbook', :id => 2, :contact_id => 2
    assert_response :success
    contact = Contact.find(2)
    assert_equal [1, 2], contact.project_ids

    compatible_xhr_request :post, :create, :project_id => 'ecookbook', :id => 2, :contact_id => 2
    assert_response :success
    contact = Contact.find(2)
    assert_equal [1, 2], contact.project_ids
  end

  def test_post_create_without_permissions
    @request.session[:user_id] = 1

    compatible_xhr_request :post, :create, :project_id => 'project6', :id => 2, :contact_id => 2
    assert_response 403
  end
end
