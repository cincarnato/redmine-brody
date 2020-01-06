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

class TimelogControllerTest < ActionController::TestCase
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
  end
  def test_get_report_with_deal
    @request.session[:user_id] = 1
    compatible_request :get, :report, :columns => 'month', :criteria => ['deal', 'deal_contact'], :project_id => 'ecookbook'
    assert_response :success
    assert_select 'table#time-report td', /Domoway/
    assert_select 'table#time-report td', /First deal with contacts/
    assert_select 'table#time-report td', /Second deal with contacts/
  end

  def test_get_index_with_company_cf
    @request.session[:user_id] = 1
    project = Project.find(1)
    company = Contact.find(3)
    @cfield = IssueCustomField.create!(name: 'COMPANY', field_format: 'company', is_filter: true)
    @cfield.projects << project
    compatible_request :get, :index, :set_filter => 1,
                                     :f => ["issue.cf_#{@cfield.id}", ''],
                                     :op => { "issue.cf_#{@cfield.id}" => '=' },
                                     :v => { "issue.cf_#{@cfield.id}" => [company.id] },
                                     :c => ['spent_on', 'user', 'issue'],
                                     :project_id => project.identifier
    assert_response :success
    assert_match "values\":[[\"#{company.name}\",\"#{company.id}\"]]", response.body
    assert_match '"type":"company"', response.body
  ensure
    @cfield.destroy
  end

  def test_get_report_as_csv
    @request.session[:user_id] = 1
    compatible_request :get, :report, format: 'csv', set_filter: '1', criteria: ['project', ''], f: ['spent_on', ''], op: { 'spent_on' => '*' },
                                      c: ['project', 'issue'], group_by: '', t: ['hours', ''], columns: 'month', encoding: 'UTF-8'
    assert_response :success
    assert_match 'Cookbook', response.body
  end
end
