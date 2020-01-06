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

# encoding: utf-8
require File.expand_path('../../test_helper', __FILE__)
class QueriesControllerTest < ActionController::TestCase
  fixtures :projects, :enabled_modules,
           :users, :email_addresses,
           :members, :member_roles, :roles,
           :trackers, :issue_statuses, :issue_categories, :enumerations, :versions,
           :issues, :custom_fields, :custom_values,
           :queries

  def setup
    User.current = nil
  end
  def test_filter_for_contact_custom_field
    contact_cf = ContactCustomField.create!(:name => 'contact_cf', :is_filter => true, :field_format => 'company')
    @request.session[:user_id] = 1
    compatible_request :get, :filter, :params => { :type => 'ContactQuery', :name => contact_cf.name }

    assert_response :success
    assert_equal 'application/json', response.content_type
  ensure
    contact_cf.destroy
  end if Redmine::VERSION.to_s >= '3.4' || RedmineContacts.unstable_branch?
end
