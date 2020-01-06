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

class WikiControllerTest < ActionController::TestCase
  fixtures :projects,
           :users,
           :roles,
           :members,
           :member_roles,
           :issues,
           :issue_statuses,
           :roles,
           :enabled_modules,
           :versions,
           :trackers,
           :projects_trackers,
           :issue_categories,
           :enabled_modules,
           :enumerations,
           :attachments,
           :wikis,
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
    EnabledModule.create(:project_id => 1, :name => 'wiki')
    @project = Project.find(1)
    @wiki = @project.wiki
    @page_name = 'contact_macro_test'
    @page = @wiki.find_or_new_page(@page_name)
    @page.content = WikiContent.new
    @page.content.text = 'test'
    @page.content.author = User.find(1)
    @page.save!
  end

  def test_show_with_contact_macro
    @request.session[:user_id] = 1
    @page.content.text = '{{contact(1)}}'
    @page.content.save!
    compatible_request :get, :show, :project_id => 1, :id => @page_name
    assert_response :success
    assert_select 'h3', 'Wiki'
    assert_select 'div.wiki p', /Ivan Ivanov/
  end

  def test_show_with_contact_avatar_macro
    @request.session[:user_id] = 1
    @page.content.text = '{{contact_avatar(1)}}'
    @page.content.save!
    compatible_request :get, :show, :project_id => 1, :id => @page_name
    assert_response :success
    assert_select 'h3', 'Wiki'
    assert_select 'div.wiki p img'
  end

  def test_show_with_note_macro
    @request.session[:user_id] = 1
    @page.content.text = '{{contact_note(1)}}'
    @page.content.save!
    compatible_request :get, :show, :project_id => 1, :id => @page_name
    assert_response :success
    assert_select 'h3', 'Wiki'
    assert_select 'div.wiki p', /Note 1 content with wiki syntax/
  end
  def test_show_with_deal_macro
    @request.session[:user_id] = 1
    @page.content.text = '{{deal(1)}}'
    @page.content.save!
    compatible_request :get, :show, :project_id => 1, :id => @page_name
    assert_response :success
    assert_select 'h3', 'Wiki'
    assert_select 'div.wiki p', /Ivan Ivanov: First deal with contacts/
  end
end
