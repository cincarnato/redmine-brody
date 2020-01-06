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
# require 'contacts_duplicates_controller'

class ContactsDuplicatesControllerTest < ActionController::TestCase
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

  def test_get_index_duplicates
    contact = Contact.find(3)
    contact_clone = contact.dup
    contact_clone.project = contact.project
    contact_clone.save!

    @request.session[:user_id] = 2
    Setting.default_language = 'en'

    compatible_request :get, :index, :project_id => contact.project, :contact_id => 3
    assert_response :success
    assert_select 'ul#contact_duplicates li', 1
    assert_select 'ul#contact_duplicates li a', contact.name
  ensure
    contact_clone.delete
  end

  def test_get_merge_duplicates
    @request.session[:user_id] = 1
    Setting.default_language = 'en'

    compatible_request :get, :merge, :project_id => 1, :contact_id => 1, :duplicate_id => 2
    assert_redirected_to :controller => 'contacts', :action => 'show', :id => 2, :project_id => 'ecookbook'

    contact = Contact.find(2)
    assert_equal contact.emails, ['marat@mail.ru', 'marat@mail.com', 'ivan@mail.com']
  end

  def test_xhr_get_duplicates
    @request.session[:user_id] = 1
    compatible_xhr_request :get, :duplicates, :project_id => 'ecookbook', :contact => { :first_name => 'marat' }
    assert_match /Marat Aminov/, @response.body
  end

  def test_xhr_get_search
    @request.session[:user_id] = 1
    compatible_xhr_request :get, :search, :project_id => 'ecookbook', :contact_id => 2, :q => 'iva'
    assert_match /Ivan Ivanov/, @response.body
  end
end
