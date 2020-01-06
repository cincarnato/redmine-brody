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
include RedmineContacts::TestHelper

class CustomFieldCompanyFormatTest < ActiveSupport::TestCase
  fixtures :custom_fields, :projects, :members, :users, :member_roles, :trackers, :issues

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
    @field = IssueCustomField.create!(:name => 'Tester', :field_format => 'company')
    @controller = DealStatusesController.new
    Role.anonymous.remove_permission!(:view_contacts)
    User.current = nil
  end

  def test_possible_values_options_with_no_arguments
    with_contacts_settings('cross_project_contacts' => 0) do
      User.current = nil
      assert_equal [], @field.possible_values_options
      assert_equal [], @field.possible_values_options(nil)
    end
  end

  def test_possible_values_options_with_project_resource
    with_contacts_settings('cross_project_contacts' => 1) do
      User.current = User.find(1)
      project = Project.find(1)
      possible_values_options = @field.possible_values_options(project.issues.first)
      assert possible_values_options.empty?
    end
  end

  def test_cast_blank_value
    assert_nil @field.cast_value(nil)
    assert_nil @field.cast_value('')
  end

  def test_cast_valid_value
    contact = @field.cast_value('2')
    assert_kind_of Contact, contact
    assert_equal Contact.find(2), contact
  end

  def test_cast_invalid_value
    assert_nil @field.cast_value('187')
  end
end
