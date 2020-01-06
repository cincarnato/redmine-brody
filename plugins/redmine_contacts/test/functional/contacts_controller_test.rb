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

class ContactsControllerTest < ActionController::TestCase
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
                                                                                                                    :queries,
                                                                                                                    :addresses])

  def setup
    RedmineContacts::TestCase.prepare
    User.current = nil
  end

  def test_get_index
    @request.session[:user_id] = 1
    assert_not_nil Contact.find(1)
    compatible_request :get, :index
    assert_response :success
    assert_not_nil contacts_in_list
    assert_select 'a', :html => /Domoway/
    assert_select 'a', :html => /Marat/
    assert_select 'h3', :html => /Tags/
    assert_select 'h3', :html => /Recently viewed/
    assert_select 'div#tags span#single_tags span.tag-label-color a', 'test'
    assert_select 'div#tags span#single_tags span.tag-label-color a', 'main'
  end

  test 'should get index in project' do
    @request.session[:user_id] = 1
    Setting.default_language = 'en'

    compatible_request :get, :index, :project_id => 1
    assert_response :success
    assert_not_nil contacts_in_list
    assert_select 'a', :html => /Domoway/
    assert_select 'a', :html => /Marat/
    assert_select 'h3', :html => /Tags/
    assert_select 'h3', :html => /Recently viewed/
  end
  test 'should get index with filters and sorting' do
    field = ContactCustomField.create!(:name => 'Test custom field', :is_filter => true, :field_format => 'string')
    contact = Contact.find(1)
    contact.custom_field_values = { field.id => "This is custom значение" }
    contact.save

    @request.session[:user_id] = 1
    Setting.default_language = 'en'

    compatible_request :get, :index, :sort => 'assigned_to,cf_1,last_name,first_name',
                                     :v => { 'first_name' => ['Ivan'] },
                                     :f => ['first_name', ''],
                                     :op => { 'first_name' => '~' }
    assert_response :success
    assert_not_nil contacts_in_list

    assert_select 'div#content div#contact_list table.contacts td.name h1', 'Ivan Ivanov'
  end

  def test_get_index_with_all_fields
    @request.session[:user_id] = 1
    compatible_request :get,
                       :index,
                       :set_filter => 1,
                       :project_id => 1,
                       :c => ContactQuery.available_columns.map(&:name),
                       :contacts_list_style => 'list'
    assert_response :success
    assert_select 'tr#contact-1 td.id a[href=?]', '/contacts/1'
    assert_select 'tr#contact-1 td.tags', 'main'
  end

  def test_index_with_short_filters
    @request.session[:user_id] = 1
    to_test = {
      'tags' => {
        'main|test' => { :op => '=', :values => ['main', 'test'] },
        '=main' => { :op => '=', :values => ['main'] },
        '!test' => { :op => '!', :values => ['test'] } },
      'country' => {
        '*' => { :op => '*', :values => [''] },
        '!*' => { :op => '!*', :values => [''] },
        'US|RU' => { :op => '=', :values => ['US', 'RU'] } },
      'first_name' => {
        'Marat' => { :op => '=', :values => ['Marat'] },
        '~Mara' => { :op => '~', :values => ['Mara'] },
        '!~Mara' => { :op => '!~', :values => ['Mara'] } },
      'created_on' => {
        '>=2011-10-12' => { :op => '>=', :values => ['2011-10-12'] },
        '<t-2' => { :op => '<t-', :values => ['2'] },
        '>t-2' => { :op => '>t-', :values => ['2'] },
        't-2' => { :op => 't-', :values => ['2'] } },
      'last_note' => {
        '>=2011-10-12' => { :op => '>=', :values => ['2011-10-12'] },
        '<t-2' => { :op => '<t-', :values => ['2'] },
        '>t-2' => { :op => '>t-', :values => ['2'] },
        't-2' => { :op => 't-', :values => ['2'] } },
      'has_deals' => {
        'c' => { :op => '=', :values => ['c'] },
        '!c' => { :op => '!', :values => ['c'] } },
      'has_open_issues' => {
        '=4' => { :op => '=', :values => ['4'] },
        '!*' => { :op => '!*', :values => [''] },
        '*' => { :op => '*', :values => [''] } }
    }

    to_test.each do |field, expression_and_expected|
      expression_and_expected.each do |filter_expression, expected|
        compatible_request :get, :index, set_filter: 1, field => filter_expression

        assert_response :success
        assert_not_nil contacts_in_list
      end
    end
  end

  def test_filter_by_ids_equal
    @request.session[:user_id] = 1
    ids = [1, 2]
    compatible_request :get, :index, project_id: 1, set_filter: 1, 'f' => ['ids', ''], 'op' => { 'ids' => '=' }, 'v' => { 'ids' => ids }
    assert_response :success
    assert_equal ids.sort, contacts_in_list.map(&:id).sort
  end if Redmine::VERSION.to_s >= '3.3'

  def test_filter_by_ids_not_equal
    @request.session[:user_id] = 1
    compatible_request :get, :index, project_id: 1, set_filter: 1, 'f' => ['ids', ''], 'op' => { 'ids' => '!' }, 'v' => { 'ids' => [1, 2] }
    assert_response :success
    assert_equal [3, 4, 5].sort, contacts_in_list.map(&:id).sort
  end if Redmine::VERSION.to_s >= '3.3'

  def test_filter_by_ids_any
    @request.session[:user_id] = 1
    compatible_request :get, :index, project_id: 1, set_filter: 1, 'f' => ['ids', ''], 'op' => { 'ids' => '*' }
    assert_response :success
    assert_equal [1, 2, 3, 4, 5].sort, contacts_in_list.map(&:id).sort
  end if Redmine::VERSION.to_s >= '3.3'

  def test_filter_by_ids_none
    @request.session[:user_id] = 1
    compatible_request :get, :index, project_id: 1, set_filter: 1, 'f' => ['ids', ''], 'op' => { 'ids' => '!*' }
    assert_response :success
    assert contacts_in_list.blank?
  end if Redmine::VERSION.to_s >= '3.3'

  def test_filter_by_ids_short_filter
    @request.session[:user_id] = 1
    compatible_request :get, :index, project_id: 1, set_filter: 1, ids: '1|2|4'
    assert_response :success
    assert_equal [1, 2, 4].sort, contacts_in_list.map(&:id).sort
  end if Redmine::VERSION.to_s >= '3.3'

  def test_filter_by_tags_equal
    @request.session[:user_id] = 1
    tags = %w(main test)
    compatible_request :get, :index, project_id: 1, set_filter: 1, f: ['tags', ''], op: { tags: '=' }, v: { tags: tags }
    assert_response :success
    contacts = contacts_in_list
    assert_equal [3].sort, contacts.map(&:id).sort
    contacts.each { |contact| assert_equal (tags & contact.tag_list), tags }
  end

  def test_filter_by_tags_not_equal
    @request.session[:user_id] = 1
    tags = %w(main test)
    compatible_request :get, :index, project_id: 1, set_filter: 1, f: ['tags', ''], op: { tags: '!' }, v: { tags: tags }
    assert_response :success
    contacts = contacts_in_list
    assert_equal [1, 2, 4, 5].sort, contacts.map(&:id).sort
  end

  def test_index_sort_by_custom_field
    @request.session[:user_id] = 1
    cf = ContactCustomField.create!(:name => 'Contact test cf', :is_for_all => true, :field_format => 'string')
    CustomValue.create!(:custom_field => cf, :customized => Contact.find(1), :value => 'test_1')
    CustomValue.create!(:custom_field => cf, :customized => Contact.find(2), :value => 'test_2')
    CustomValue.create!(:custom_field => cf, :customized => Contact.find(3), :value => 'test_3')

    compatible_request :get, :index, :set_filter => 1, :sort => "cf_#{cf.id},id"
    assert_response :success

    assert_equal [1, 2, 3], contacts_in_list.select { |contact| contact.custom_field_value(cf).present? }.map(&:id).sort
  end

  def test_should_not_absolute_links
    @request.session[:user_id] = 1

    compatible_request :get, :index
    assert_response :success
    assert_no_match %r{localhost}, @response.body
  end

  def test_should_get_index_deny_user_in_project
    @request.session[:user_id] = 5

    compatible_request :get, :index, :project_id => 1
    assert_response :redirect
  end
  def test_should_get_index_with_filters
    @request.session[:user_id] = 1
    contact = Contact.find(2)
    first_name = contact.first_name
    full_name = contact.name
    compatible_request :get, :index, :first_name => first_name
    assert_response :success
    assert_select 'div#content div#contact_list table.contacts td.name h1 a', full_name
  end

  def test_should_get_index_as_csv
    field = ContactCustomField.create!(:name => 'Test custom field', :is_filter => true, :field_format => 'string')
    contact = Contact.find(1)
    contact.custom_field_values = { field.id => "This is custom значение" }
    contact.save

    @request.session[:user_id] = 1
    compatible_request :get, :index, :format => 'csv'
    assert_response :success
    assert_not_nil contacts_in_list
    assert_match 'text/csv', @response.content_type
    assert_match /Domoway/, @response.body
  end

  def test_should_get_index_as_VCF
    @request.session[:user_id] = 1
    compatible_request :get, :index, :format => 'vcf'
    assert_response :success
    assert_not_nil contacts_in_list
    assert_equal 'text/x-vcard', @response.content_type
    assert @response.body.starts_with?('BEGIN:VCARD')
    assert_match /^N:;Domoway/, @response.body
  end

  def test_should_get_contacts_notes_as_csv
    @request.session[:user_id] = 1
    compatible_request :get, :contacts_notes, :format => 'csv'
    assert_response :success
    assert_match 'text/csv', @response.content_type
    assert @response.body.starts_with?('#,')
  end

  def test_get_show
    @request.session[:user_id] = 2
    Setting.default_language = 'en'

    compatible_request :get, :show, :id => 3, :project_id => 1
    assert_response :success

    assert_not_nil contacts_in_list
    assert_select 'h1', :html => /Domoway/
    assert_select 'div#tags_data span.tag-label-color a', 'main'
    assert_select 'div#tags_data span.tag-label-color a', 'test'
    assert_select 'div#tab-placeholder-contacts'
    assert_select 'div#comments div#notes table.note_data td.name h4', 4
    assert_select 'h3', 'Recently viewed'
  end

  def test_get_show_with_long_note
    long_note = 'A' * 1500
    Contact.find(3).notes.create(:content => long_note, :author_id => 1)
    @request.session[:user_id] = 2
    Setting.default_language = 'en'

    compatible_request :get, :show, :id => 3, :project_id => 1
    assert_response :success
    assert_select '.note a', '(read more)'
  end
  def test_get_show_tab_deals
    @request.session[:user_id] = 2
    Setting.default_language = 'en'

    compatible_request :get, :show, :id => 3, :project_id => 1, :tab => 'deals'
    assert_response :success
    assert_not_nil contacts_in_list
    assert_select 'h1', :html => /Domoway/
    assert_select 'div#deals a', 'Delevelop redmine plugin'
    assert_select 'div#deals a', 'Second deal with contacts'
  end

  def test_get_show_without_deals
    @request.session[:user_id] = 4
    Setting.default_language = 'en'

    compatible_request :get, :show, :id => 3, :project_id => 1, :tab => 'deals'
    assert_response :success
    assert_not_nil contacts_in_list

    assert_select 'div#deals a', { :count => 0, :text => /Delevelop redmine plugin/ }
    assert_select 'div#deals a', { :count => 0, :text => /Second deal with contacts/ }
  end

  def test_get_new
    @request.session[:user_id] = 2
    compatible_request :get, :new, :project_id => 1
    assert_response :success
    assert_select 'input#contact_first_name'
  end
  def test_get_new_with_params
    @request.session[:user_id] = 2
    compatible_request :get, :new, project_id: 1, contact: { company: 'Test company' }
    assert_response :success

    assert_match /Test company/, @response.body.to_s
  end

  def test_get_new_without_permission
    @request.session[:user_id] = 4
    compatible_request :get, :new, :project_id => 1
    assert_response :forbidden
  end

  def test_post_create
    @request.session[:user_id] = 1
    assert_difference 'Contact.count' do
      compatible_request :post, :create, :project_id => 1, :contact => { :company => 'OOO "GKR"',
                                                                         :is_company => 0,
                                                                         :job_title => 'CFO',
                                                                         :assigned_to_id => 3,
                                                                         :tag_list => 'test,new',
                                                                         :last_name => 'New',
                                                                         :middle_name => 'Ivanovich',
                                                                         :first_name => 'Created' }
    end

    assert_redirected_to :controller => 'contacts', :action => 'show', :id => Contact.last.id, :project_id => Contact.last.project

    contact = Contact.where(:first_name => 'Created', :last_name => 'New', :middle_name => 'Ivanovich').first
    assert_not_nil contact
    assert_equal 'CFO', contact.job_title
    assert_equal ['new', 'test'], contact.tag_list.sort
    assert_equal 3, contact.assigned_to_id
  end
  def test_post_create_with_custom_fields
    field = ContactCustomField.create!(:name => 'Test', :is_filter => true, :field_format => 'string')
    @request.session[:user_id] = 1
    assert_difference 'Contact.count' do
      compatible_request :post, :create, :project_id => 1, :contact => { :company => 'OOO "GKR"',
                                                                         :is_company => 0,
                                                                         :job_title => 'CFO',
                                                                         :assigned_to_id => 3,
                                                                         :tag_list => 'test,new',
                                                                         :last_name => 'New',
                                                                         :middle_name => 'Ivanovich',
                                                                         :first_name => 'Created',
                                                                         :custom_field_values => { "#{field.id}" => 'contact one' } }
    end
    assert_redirected_to :controller => 'contacts', :action => 'show', :id => Contact.last.id, :project_id => Contact.last.project

    contact = Contact.where(:first_name => 'Created', :last_name => 'New', :middle_name => 'Ivanovich').first
    assert_equal 'contact one', contact.custom_field_values.last.value
  end

  def test_post_create_without_permission
    @request.session[:user_id] = 4
    compatible_request :post, :create, :project_id => 1, :contact => { :company => 'OOO "GKR"',
                                                                       :is_company => 0,
                                                                       :job_title => 'CFO',
                                                                       :assigned_to_id => 3,
                                                                       :tag_list => 'test,new',
                                                                       :last_name => 'New',
                                                                       :middle_name => 'Ivanovich',
                                                                       :first_name => 'Created' }
    assert_response :forbidden
  end

  def test_get_edit
    @request.session[:user_id] = 1
    compatible_request :get, :edit, :id => 1
    assert_response :success
    assert_select 'h2', /Editing Contact Information/
  end

  def test_get_edit_with_duplicates
    contact = Contact.find(3)
    contact_clone = contact.dup
    contact_clone.project = contact.project
    contact_clone.save!

    @request.session[:user_id] = 2
    Setting.default_language = 'en'

    compatible_request :get, :edit, :id => 3
    assert_response :success
    assert_select 'div#duplicates', 1
    assert_select 'div#duplicates h3', /Possible duplicates/
  ensure
    contact_clone.delete
  end

  def test_put_update
    @request.session[:user_id] = 1

    contact = Contact.find(1)
    new_firstname = 'Fist name modified by ContactsControllerTest#test_put_update'

    compatible_request :put, :update, :id => 1, :project_id => 1, :contact => { :first_name => new_firstname }
    assert_redirected_to :action => 'show', :id => '1', :project_id => 1
    contact.reload
    assert_equal new_firstname, contact.first_name
  end

  def test_post_destroy
    @request.session[:user_id] = 1
    compatible_request :post, :destroy, :id => 1, :project_id => 'ecookbook'
    assert_redirected_to :action => 'index', :project_id => 'ecookbook'
    assert_equal 0, Contact.where(:id => [1]).count
  end

  def test_post_bulk_destroy
    @request.session[:user_id] = 1

    compatible_request :post, :bulk_destroy, :ids => [1, 2, 3]
    assert_redirected_to :controller => 'contacts', :action => 'index'

    assert_equal 0, Contact.where(:id => [1, 2, 3]).count
  end

  def test_post_bulk_destroy_without_permission
    @request.session[:user_id] = 4
    assert_raises ActiveRecord::RecordNotFound do
      compatible_request :post, :bulk_destroy, :ids => [1, 2]
    end
  end
  def test_bulk_edit_mails
    @request.session[:user_id] = 1
    compatible_request :post, :edit_mails, :ids => [1, 2]
    assert_response :success
    assert_not_nil contacts_in_list
  end

  def test_bulk_edit_mails_by_deny_user
    @request.session[:user_id] = 4
    compatible_request :post, :edit_mails, :ids => [1, 2]
    assert_response 403
  end

  def test_bulk_send_mails_by_deny_user
    @request.session[:user_id] = 4
    compatible_request :post, :send_mails, :ids => [1, 2], :message => 'test message', :subject => 'test subject'
    assert_response 403
  end

  def test_bulk_send_mails
    ActionMailer::Base.deliveries.clear
    @request.session[:user_id] = 1
    compatible_request :post, :send_mails, :ids => [2], :from => 'test@mail.from', :bcc => 'test@mail.bcc', :"message-content" => "Hello %%NAME%%\ntest message", :subject => 'test subject'
    mail = ActionMailer::Base.deliveries.last
    assert_not_nil mail
    assert_match /Hello Marat/, mail.text_part.body.to_s
    assert_equal 'test subject', mail.subject
    assert_equal 'test@mail.from', mail.from.first
    assert_equal 'test@mail.bcc', mail.bcc.first
    note = Note.last
    assert_equal 'test subject', note.subject
    assert_equal note.type_id, Note.note_types[:email]
    assert_equal "Hello Marat\ntest message", note.content
  end

  def test_post_bulk_edit
    @request.session[:user_id] = 1
    compatible_request :post, :bulk_edit, :ids => [1, 2]
    assert_response :success
    assert_not_nil contacts_in_list
  end

  def test_post_bulk_edit_without_permission
    @request.session[:user_id] = 4
    assert_raises ActiveRecord::RecordNotFound do
      compatible_request :post, :bulk_edit, :ids => [1, 2]
    end
  end

  def test_put_bulk_update
    @request.session[:user_id] = 1

    compatible_request :put, :bulk_update, :ids => [1, 2],
                                           :add_tag_list => 'bulk, edit, tags',
                                           :delete_tag_list => 'main',
                                           :add_projects_list => ['1', '2', '3'],
                                           :delete_projects_list => ['3', '4', '5'],
                                           :note => { :content => 'Bulk note content' },
                                           :contact => { :company => 'Bulk company', :job_title => '' }

    assert_redirected_to :controller => 'contacts', :action => 'index', :project_id => nil
    contacts = Contact.find([1, 2])
    contacts.each do |contact|
      assert_equal 'Bulk company', contact.company
      tag_list = contact.tag_list # Need for 4 rails
      assert tag_list.include?('bulk')
      assert tag_list.include?('edit')
      assert tag_list.include?('tags')
      assert !tag_list.include?('main')
      assert contact.project_ids.include?(1) && contact.project_ids.include?(2)

      assert_equal 'Bulk note content', contact.notes.find_by_content('Bulk note content').content
    end
  end

  def test_put_bulk_update_without_permission
    @request.session[:user_id] = 4

    compatible_request :put, :bulk_update, :ids => [1, 2],
                                           :add_tag_list => 'bulk, edit, tags',
                                           :delete_tag_list => 'main',
                                           :note => { :content => 'Bulk note content' },
                                           :contact => { :company => 'Bulk company', :job_title => '' }
    assert_response 403
  end

  def test_get_contacts_notes
    @request.session[:user_id] = 2

    compatible_request :get, :contacts_notes
    assert_response :success
    assert_select 'h2', /All notes/
    assert_select 'div#contacts_notes table.note_data div.note.content.preview', /Note 1/
  end

  def test_get_context_menu
    @request.session[:user_id] = 1
    compatible_xhr_request :get, :context_menu, :back_url => '/projects/contacts-plugin/contacts', :project_id => 'ecookbook', :ids => ['1', '2']
    assert_response :success
  end

  def test_post_index_with_search
    @request.session[:user_id] = 1
    compatible_xhr_request :post, :index, :search => 'Domoway'
    assert_response :success
    assert_match 'contacts?search=Domoway', response.body
    assert_select 'a', :html => /Domoway/
  end

  def test_post_index_with_search_in_project
    @request.session[:user_id] = 1
    compatible_xhr_request :post, :index, :search => 'Domoway', :project_id => 'ecookbook'
    assert_response :success
    assert_match 'contacts?search=Domoway', response.body
    assert_select 'a', :html => /Domoway/
  end

  def test_post_contacts_notes_with_search
    @request.session[:user_id] = 1
    compatible_xhr_request :post, :contacts_notes, :search_note => 'Note 1'
    assert_response :success
    assert_match 'note_data', response.body
    assert_select 'table.note_data div.note.content.preview', /Note 1/
    assert_select 'table.note_data div.note.content.preview', { :count => 0, :text => /Note 2/ }
  end

  def test_post_contacts_notes_with_search_in_project
    @request.session[:user_id] = 1
    compatible_xhr_request :post, :contacts_notes, :search_note => 'Note 2', :project_id => 'ecookbook'
    assert_response :success
    assert_match 'note_data', response.body
    assert_select 'table.note_data div.note.content.preview', /Note 2/
  end
  def test_should_have_import_csv_link_if_authorized_to
    @request.session[:user_id] = 1
    compatible_request :get, :index, :project_id => 1
    assert_response :success
    assert_select 'a#import_from_csv'
  end

  def test_should_not_have_import_csv_link_if_unauthorized
    @request.session[:user_id] = 4
    compatible_request :get, :index, :project_id => 1
    assert_response :success
    assert_select 'a#import_from_csv', false, 'Should not see CSV import link'
  end

  def test_index_should_omit_page_param_in_csv_export_link
    @request.session[:user_id] = 1
    compatible_request :get, :index, :page => 2
    assert_response :success
    assert_select 'a.csv[href=?]', '/contacts.csv'
    assert_select 'form#csv-export-form[action=?]', '/contacts.csv'
  end

  def test_index_should_include_query_params_in_csv_export_form
    @request.session[:user_id] = 1
    compatible_request :get,
                       :index,
                       {:project_id => 1,
                         :set_filter => 1,
                         :has_deals => 1,
                         :c => ['name', 'job_title'],
                         :sort => 'name'}

    assert_select '#csv-export-form[action=?]', '/projects/ecookbook/contacts.csv'
    assert_select '#csv-export-form[method=?]', 'get'

    assert_select '#csv-export-form' do
      assert_select 'input[name=?][value=?]', 'set_filter', '1'

      assert_select 'input[name=?][value=?]', 'f[]', 'has_deals'
      assert_select 'input[name=?][value=?]', 'op[has_deals]', '='
      assert_select 'input[name=?][value=?]', 'v[has_deals][]', '1'

      assert_select 'input[name=?][value=?]', 'c[]', 'name'
      assert_select 'input[name=?][value=?]', 'c[]', 'job_title'

      assert_select 'input[name=?][value=?]', 'sort', 'name'
    end
  end if Redmine::VERSION::STRING > '3.2.1'

  def test_index_csv_without_filters
    @request.session[:user_id] = 1
    compatible_request :get,
                       :index,
                       {:format => 'csv',
                         :set_filter => 1,
                         :f => ['']}
    assert_response :success
    # -1 for headers
    lines = @response.body.chomp.lines.count - 1
    assert_equal Contact.count, lines
  end if Redmine::VERSION::STRING > '3.3'

  def test_index_csv_with_some_filters
    @request.session[:user_id] = 1
    filter = {:job_title => 'CEO'}
    params = {:format => 'csv', :set_filter => 1}.merge(filter)

    compatible_request :get, :index, params
    assert_response :success
    # -1 for headers
    lines = @response.body.chomp.lines.count - 1
    assert_equal Contact.where(filter).count, lines
  end if Redmine::VERSION::STRING > '3.3'

  def test_index_csv_with_few_columns
    @request.session[:user_id] = 1
    columns = ['id', 'name', 'company', 'job_title']
    compatible_request :get,
                       :index,
                       :format => 'csv',
                       :c => columns
    assert_response :success
    assert_match 'text/csv', @response.content_type
    assert response.body.starts_with?("#,")

    actual_columns = response.body.chomp.lines.first.split(',').count
    assert_equal columns.count, actual_columns
  end

  def test_index_csv_with_all_available_columns
    @request.session[:user_id] = 1
    all_columns = if Redmine::VERSION::STRING < '3.2'
        {:columns => 'all'}
      elsif Redmine::VERSION::STRING < '3.4'
        {:csv => {:columns => 'all'}}
      else
        {:c => ['all_inline']}
      end
    params = {:format => 'csv'}.merge(all_columns)

    compatible_request :get, :index, params
    assert_response :success
    assert_match 'text/csv', @response.content_type
    assert response.body.starts_with?("#,")

    available_columns = ContactQuery.new.available_columns.count
    actual_columns = response.body.chomp.lines.first.split(',').count
    assert_equal available_columns, actual_columns
  end

  def test_index_with_contacts_as_cards_exports_all_columns
    @request.session[:user_id] = 1
    compatible_request :get, :index, :contacts_list_style => 'list_cards'
    assert_response :success
    assert_select 'a[href^="/contacts.csv"][onclick^=?]', 'showModal', false
  end

  def test_index_with_contacts_as_list_allows_to_choose_columns
    @request.session[:user_id] = 1
    compatible_request :get, :index, :contacts_list_style => 'list'
    assert_response :success
    assert_select 'a[href^="/contacts.csv"][onclick^=?]', 'showModal'
  end

  def test_index_properly_exports_tags_as_text_in_csv
    @request.session[:user_id] = 1

    contact = Contact.find(1)
    contact.tags = [RedmineCrm::Tag.new(:name => 'foo')]
    contact.save

    compatible_request :get,
                       :index,
                       :format => 'csv',
                       :c => ['tags']
    assert_response :success
    assert_include "foo\n", @response.body.chomp.lines
  end

  def test_render_tab_partial_on_load_tab
    @request.session[:user_id] = 4
    compatible_xhr_request :get, :load_tab, :id => 3, :tab_name => 'notes', :partial => 'notes', :format => :js
    assert_response :success
    assert_match 'note_data', response.body
  end

  def test_custom_query_saves_grouping
    @request.session[:user_id] = 1
    compatible_request :get, :index, :group_by => 'company'
    assert_response :success
    compatible_request :get, :index, :query_id => ContactQuery.all.first.id, :project_id => 1
    assert_response :success
    assert_select "tr.group"
  end

  def test_custom_query_saves_columns
    @request.session[:user_id] = 1
    compatible_request :get, :index, :c => ['name', 'job_title', 'city'], :contacts_list_style => 'list'
    assert_response :success
    compatible_request :get, :index, :query_id => ContactQuery.all.first.id, :project_id => 1
    assert_response :success
    assert_select 'thead tr', :text => /City/
  end

  def test_post_create_with_avatar
    image = Redmine::Plugin.find(:redmine_contacts).directory + '/test/fixtures/files/image.jpg'
    attach = Attachment.create!(:file => Rack::Test::UploadedFile.new(image, 'image/jpeg'), :author => User.find(1))

    @request.session[:user_id] = 1
    assert_difference 'Contact.count' do
      compatible_request :post, :create, :project_id => 1,
                                         :attachments => { '0' => { 'filename' => 'image.jpg', 'description' => 'avatar', 'token' => attach.token } },
                                         :contact => { :last_name => 'Testov',
                                                       :middle_name => 'Test',
                                                       :first_name => 'Testovich' }
    end

    assert_redirected_to :controller => 'contacts', :action => 'show', :id => Contact.last.id, :project_id => Contact.last.project
    assert_equal 'Contact', Attachment.last.container_type
    assert_equal Contact.last.id, Attachment.last.container_id

    assert_equal 'image.jpg', Attachment.last.diskfile[/image\.jpg/]
  end

  def test_last_notes_for_contact
    contact = Contact.find(1)
    note = contact.notes.create(:content => 'note for contact', :author_id => 1)
    @request.session[:user_id] = 1
    compatible_request :get, :index
    assert_response :success
    assert_select '.note.content', :text => note.content
  end
end
