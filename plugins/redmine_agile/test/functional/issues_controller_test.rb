# encoding: utf-8
#
# This file is a part of Redmin Agile (redmine_agile) plugin,
# Agile board plugin for redmine
#
# Copyright (C) 2011-2019 RedmineUP
# http://www.redmineup.com/
#
# redmine_agile is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# redmine_agile is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with redmine_agile.  If not, see <http://www.gnu.org/licenses/>.

require File.expand_path('../../test_helper', __FILE__)

class IssuesControllerTest < ActionController::TestCase
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

  def setup
    @project_1 = Project.find(1)
    @project_2 = Project.find(5)
    EnabledModule.create(:project => @project_1, :name => 'agile')
    EnabledModule.create(:project => @project_2, :name => 'agile')
    @request.session[:user_id] = 1
  end
  def test_get_index_with_colors
    with_agile_settings "color_on" => "issue" do
      issue = Issue.find(1)
      issue.color = AgileColor::AGILE_COLORS[:red]
      issue.save
      compatible_request :get, :index
      assert_response :success
      assert_select 'tr#issue-1.issue.bk-red', 1
    end
  end

  def test_post_issue_journal_color
    with_agile_settings 'color_on' => 'issue' do
      compatible_request :put, :update, :id => 1, :issue => { :agile_color_attributes => { :color => AgileColor::AGILE_COLORS[:red] } }
      issue = Issue.find(1)
      details = issue.journals.order(:id).last.details.last
      assert issue.color
      assert_equal 'color', details.prop_key
      assert_equal AgileColor::AGILE_COLORS[:red], details.value
    end
  end

  def test_new_issue_with_sp_value
    with_agile_settings 'estimate_units' => 'story_points' do
      compatible_request :get, :new, :project_id => 1
      assert_response :success
      assert_select 'input#issue_agile_data_attributes_story_points'
    end
  end

  def test_new_issue_without_sp_value
    with_agile_settings 'estimate_units' => 'hours' do
      compatible_request :get, :new, :project_id => 1
      assert_response :success
      assert_select 'input#issue_agile_data_attributes_story_points', :count => 0
    end
  end

  def test_create_issue_with_sp_value
    with_agile_settings 'estimate_units' => 'story_points' do
      assert_difference 'Issue.count' do
        compatible_request :post, :create, :project_id => 1, :issue => {
          :subject => 'issue with sp',
          :tracker_id => 3,
          :status_id => 1,
          :priority_id => IssuePriority.first.id,
          :agile_data_attributes => { :story_points => 50 }
        }
      end
      issue = Issue.last
      assert_equal 'issue with sp', issue.subject
      assert_equal 50, issue.story_points
    end
  end

  def test_post_issue_journal_story_points
    with_agile_settings 'estimate_units' => 'story_points' do
      compatible_request :put, :update, :id => 1, :issue => { :agile_data_attributes => { :story_points => 100 } }
      issue = Issue.find(1)
      assert_equal 100, issue.story_points
      sp_history = JournalDetail.where(:property => 'attr', :prop_key => 'story_points', :journal_id => issue.journals).last
      assert sp_history
      assert_equal 100, sp_history.value.to_i
    end
  end

  def test_show_issue_with_story_points
    with_agile_settings 'estimate_units' => 'story_points' do
      compatible_request :get, :show, :id => 1
      assert_response :success
      assert_select '.attributes', :text => /Story points/, :count => 1
    end
  end

  def test_show_issue_with_order_by_story_points
    session[:issue_query] = { :project_id => Issue.find(1).project_id,
                              :filters => { 'status_id' => { :operator => 'o', :values => [''] } },
                              :group_by => '',
                              :column_names => [:tracker, :status, :story_points],
                              :totalable_names => [],
                              :sort => [['story_points', 'asc'], ['id', 'desc']]
                            }
    with_agile_settings 'estimate_units' => 'story_points' do
      compatible_request :get, :show, :id => 1
      assert_response :success
      assert_select '.attributes', :text => /Story points/, :count => 1
    end
  ensure
    session[:issue_query] = {}
  end
  def test_show_issue_form_with_story_points_select
    with_agile_settings('sp_values' => [1,2,3],
      'estimate_units' => 'story_points') do
        compatible_request :get, :new, :project_id => 1
        assert_response :success
        assert_select 'select#issue_agile_data_attributes_story_points'
    end
  end

  def test_dont_show_story_points_select_when_no_sp_values
    with_agile_settings('sp_values' => [],
      'estimate_units' => 'story_points') do
        compatible_request :get, :new, :project_id => 1
        assert_response :success
        assert_select 'select#issue_agile_data_attributes_story_points', :count => 0
    end
  end
end
