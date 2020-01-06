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

class AutoCompletesControllerTest < ActionController::TestCase
  fixtures :projects, :issues, :issue_statuses,
           :enumerations, :users, :issue_categories,
           :trackers,
           :projects_trackers,
           :roles,
           :member_roles,
           :members,
           :enabled_modules,
           :workflows,
           :journals, :journal_details
  fixtures :email_addresses if ActiveRecord::VERSION::MAJOR >= 4

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
    @request.session[:user_id] = 1
  end

  def test_contacts_should_not_be_case_sensitive
    compatible_request :get, :contacts, :project_id => 'ecookbook', :q => 'ma'
    assert_response :success
    assert response.body.match /Marat/
  end

  def test_contacts_should_accept_term_param
    compatible_request :get, :contacts, :project_id => 'ecookbook', :term => 'ma'
    assert_response :success
    assert response.body.match /Marat/
  end

  def test_companies_should_not_be_case_sensitive
    compatible_request :get, :companies, :project_id => 'ecookbook', :q => 'domo'
    assert_response :success
    assert response.body.match /Domoway/
  end

  def test_companies_witth_spaces_should_be_found
    compatible_request :get, :companies, :project_id => 'ecookbook', :q => 'my c'
    assert_response :success
    assert response.body.match /My company/
  end

  def test_contacts_should_return_json
    compatible_request :get, :contacts, :project_id => 'ecookbook', :q => 'marat'
    assert_response :success
    json = ActiveSupport::JSON.decode(response.body)
    assert_kind_of Array, json
    contact = json.last
    assert_kind_of Hash, contact
    assert_equal 2, contact['id']
    assert_equal 2, contact['value']
    assert_equal 'Marat Aminov', contact['name']
  end

  def test_companies_should_return_json
    compatible_request :get, :companies, :project_id => 'ecookbook', :q => 'domo'
    assert_response :success
    json = ActiveSupport::JSON.decode(response.body)
    assert_kind_of Array, json
    contact = json.first
    assert_kind_of Hash, contact
    assert_equal 3, contact['id']
    assert_equal 'Domoway', contact['value']
    assert_equal 'Domoway', contact['label']
  end

  def test_contact_tags_should_return_json
    compatible_request :get, :contact_tags, :q => 'ma'
    assert_response :success
    json = ActiveSupport::JSON.decode(response.body)
    assert_kind_of Array, json
    tag = json.last['text']
    assert_match 'main', tag
  end

  def test_taggable_tags_should_return_json
    compatible_request :get, :taggable_tags, :q => 'ma', :taggable_type => 'contact'
    assert_response :success
    json = ActiveSupport::JSON.decode(response.body)
    assert_kind_of Array, json
    tag = json.last['text']
    assert_match 'main', tag
  end
  def test_deals_should_return_json
    compatible_request :get, :deals, :q => 'redmine'
    assert_response :success
    json = ActiveSupport::JSON.decode(response.body)
    assert_kind_of Array, json
    deal = json.last
    assert_kind_of Hash, deal
    assert_equal 3, deal['id']
    assert_equal 3, deal['value']
    assert_match 'Delevelop redmine plugin', deal['label']
  end

  def test_should_return_the_most_appropriate_deals
    deals = Deal.all.map { |deal| { 'id' => deal.id, 'text' => deal.name } }
    check_by_params 'Not exist deal'
    check_by_params 'Second deal with contacts', deals.values_at(1)
    check_by_params 'First deal with contacts', deals.values_at(0, 5)
    check_by_params '10First deal with contacts', deals.values_at(5)
    check_by_params 'deal with contacts', deals.values_at(5, 0, 1)
  end

  def test_deals_should_fiend_by_contact_details
    deals = Deal.all.map { |deal| { 'id' => deal.id, 'text' => deal.name } }
    check_by_params '', deals.values_at(5, 4, 3, 2, 0, 1)     # Search string is empty
    check_by_params 'Ivanov', deals.values_at(5, 0)           # Contact last name is Ivanov
    check_by_params 'jsmith@somenet.foo'                      # Contact email is jsmith@somenet.foo
    check_by_params 'Domoway', deals.values_at(5, 4, 2, 0, 1) # Contact first name is Domoway
  end

  private

  def check_by_params(search_string, expected_deals = [])
    compatible_request :get, :deals, :q => search_string
    assert_response :success
    actual_deals = ActiveSupport::JSON.decode(response.body)

    assert_equal expected_deals.length, actual_deals.length
    expected_deals.each_with_index do |expected_deal, index|
      actual_deal = actual_deals[index]
      %w(id value).each { |field| assert_equal expected_deal['id'], actual_deal[field] }
      %w(label text).each { |field| assert_match expected_deal['text'], actual_deal[field] }
    end
  end
end
