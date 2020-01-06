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

class Redmine::ApiTest::NotesTest < ActiveRecord::VERSION::MAJOR >= 4 ? Redmine::ApiTest::Base : ActionController::IntegrationTest
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

  test 'POST /notes.xml' do
    if ActiveRecord::VERSION::MAJOR < 4
      Redmine::ApiTest::Base.should_allow_api_authentication(:post, '/notes.xml', { :note => { :project_id => 1,
                                                                                               :source_id => 1,
                                                                                               :source_type => 'Contact',
                                                                                               :content => 'API test' } },
                                                                                  { :success_code => :created })
    end

    assert_difference('Note.count', 1) do
      compatible_api_request :post, '/notes.xml', { :note => { :content => 'API test' }, :project_id => 1, :source_id => 1, :source_type => 'Contact' }, credentials('admin')
    end

    note = Note.order('id DESC').first
    assert_equal 'API test', note.content

    assert_response :created
    assert_equal 'application/xml', @response.content_type
    assert_select 'note', :child => { :tag => 'id', :content => note.id.to_s }
  end

  test 'PUT /notes/1.xml' do
    @parameters = { :note => { :content => 'API update' } }

    if ActiveRecord::VERSION::MAJOR < 4
      Redmine::ApiTest::Base.should_allow_api_authentication(:put, '/notes/1.xml', @parameters, :success_code => :ok)
    end

    assert_no_difference('Note.count') do
      compatible_api_request :put, '/notes/1.xml', @parameters, credentials('admin')
      assert_response :success
    end

    note = Note.where(:id => 1).first
    assert_equal 'API update', note.content
  end

  test 'DELETE /notes/1.xml' do
    @parameters = { :note => { :content => 'API update' } }

    if ActiveRecord::VERSION::MAJOR < 4
      Redmine::ApiTest::Base.should_allow_api_authentication(:put, '/notes/1.xml', @parameters, :success_code => :ok)
    end

    assert_difference('Note.count', -1) do
      compatible_api_request :delete, '/notes/1.xml', @parameters, credentials('admin')
      assert_response :success
    end
    assert_nil Note.where(:id => 1).first
  end
end
