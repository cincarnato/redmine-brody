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

class ContactsTagsControllerTest < ActionController::TestCase
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
    @request.env['HTTP_REFERER'] = '/'
  end

  def test_should_get_edit
    @request.session[:user_id] = 1
    compatible_request :get, :edit, :id => 1
    assert_response :success
    assigned_tag = css_select('#tag_name').map { |tag| tag['value'] }.join
    assert_not_nil assigned_tag
    assert_equal RedmineCrm::Tag.find(1).name, assigned_tag
  end

  def test_should_put_update
    @request.session[:user_id] = 1
    tag1 = RedmineCrm::Tag.find(1)
    new_name = 'updated main'
    compatible_request :put, :update, :id => 1, :tag => { :name => new_name, :color_name => '#000000' }
    assert_redirected_to :controller => 'settings', :action => 'plugin', :id => 'redmine_contacts', :tab => 'tags'
    tag1.reload
    assert_equal new_name, tag1.name
  end

  def test_should_delete_destroy
    @request.session[:user_id] = 1
    assert_difference 'RedmineCrm::Tag.count', -1 do
      compatible_request :post, :destroy, :id => 1
      assert_response 302
    end
  end

  def test_should_get_merge
    @request.session[:user_id] = 1
    tag1 = RedmineCrm::Tag.find(1)
    tag2 = RedmineCrm::Tag.find(2)
    compatible_request :get, :merge, :ids => [tag1.id, tag2.id]
    assert_response :success
    merged_tags = css_select('.tag_list a').map { |tag| tag.to_s.to_s[/.*>(.+?)<\/a>/, 1] }
    assert_equal 2, merged_tags.size
  end

  def test_should_post_merge
    @request.session[:user_id] = 1
    tag1 = RedmineCrm::Tag.find(1)
    tag2 = RedmineCrm::Tag.find(2)
    assert_difference 'RedmineCrm::Tag.count', -1 do
      compatible_request :post, :merge, :ids => [tag1.id, tag2.id], :tag => { :name => 'main' }
      assert_redirected_to :controller => 'settings', :action => 'plugin', :id => 'redmine_contacts', :tab => 'tags'
    end
    assert_equal 0, Contact.tagged_with('test').count
    assert_equal 4, Contact.tagged_with('main').count # added one more tagging for tag2
  end
end
