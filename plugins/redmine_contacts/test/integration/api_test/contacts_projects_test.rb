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

  test 'POST /contacts/:contact_id/projects.xml' do
    parameters = { :project => { :id => 2 } }

    if ActiveRecord::VERSION::MAJOR < 4
      Redmine::ApiTest::Base.should_allow_api_authentication(:post, '/contacts/1/projects.xml', parameters, :success_code => :success)
    end

    compatible_api_request :post, '/contacts/1/projects.xml', parameters, credentials('admin')
    assert_response :success
    assert_not_nil Contact.find(1).projects.where(:id => 2)
  end

  test 'DELETE /contacts/:contact_id/projects.xml' do
    contact = Contact.find(1)
    contact.projects << Project.find(2)
    contact.save

    if ActiveRecord::VERSION::MAJOR < 4
      Redmine::ApiTest::Base.should_allow_api_authentication(:delete, '/contacts/1/projects/2.xml', {}, :success_code => :success)
    end

    compatible_api_request :delete, '/contacts/1/projects/2.xml', {}, credentials('admin')
    assert_response :success
    contact.reload
    assert_nil contact.projects.where(:id => 2).first
  end
end
