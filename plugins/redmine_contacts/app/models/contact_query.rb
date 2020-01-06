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

class ContactQuery < Query
  include CrmQuery

  class QueryMultipleValuesColumn < QueryColumn
    def value_object(object)
      value = super
      value.respond_to?(:to_a) ? value.to_a : value
    end
  end

  self.queried_class = Contact
  self.view_permission = :view_contacts if Redmine::VERSION.to_s >= '3.4' || RedmineContacts.unstable_branch?
  self.operators_by_filter_type[:contact] = self.operators_by_filter_type[:list_optional]
  self.operators_by_filter_type[:contact_tags] = self.operators_by_filter_type[:list_optional]
  self.operators_by_filter_type[:company] = self.operators_by_filter_type[:list_optional]

  self.available_columns = [
    QueryColumn.new(:id, :sortable => "#{Contact.table_name}.id", :default_order => 'desc', :caption => '#'),
    QueryColumn.new(:name, :sortable => lambda {Contact.fields_for_order_statement}, :caption => :field_contact_full_name),
    QueryColumn.new(:first_name, :sortable => "#{Contact.table_name}.first_name"),
    QueryColumn.new(:last_name, :sortable => "#{Contact.table_name}.last_name"),
    QueryColumn.new(:middle_name, :sortable => "#{Contact.table_name}.middle_name", :caption => :field_contact_middle_name),
    QueryColumn.new(:job_title, :sortable => "#{Contact.table_name}.job_title", :caption => :field_contact_job_title, :groupable => true),
    QueryColumn.new(:company, :sortable => "#{Contact.table_name}.company", :groupable => "#{Contact.table_name}.company", :caption => :field_contact_company),
    QueryColumn.new(:phones, :sortable => "#{Contact.table_name}.phone", :caption => :field_contact_phone),
    QueryColumn.new(:emails, :sortable => "#{Contact.table_name}.email", :caption => :field_contact_email),
    QueryColumn.new(:address, :sortable => "#{Address.table_name}.full_address", :caption => :label_crm_address),
    QueryColumn.new(:street1, :sortable => "#{Address.table_name}.street1", :caption => :label_crm_street1),
    QueryColumn.new(:street2, :sortable => "#{Address.table_name}.street2", :caption => :label_crm_street2),
    QueryColumn.new(:city, :sortable => "#{Address.table_name}.city", :groupable => "#{Address.table_name}.city", :caption => :label_crm_city),
    QueryColumn.new(:region, :sortable => "#{Address.table_name}.region", :caption => :label_crm_region),
    QueryColumn.new(:postcode, :sortable => "#{Address.table_name}.postcode", :caption => :label_crm_postcode),
    QueryColumn.new(:country, :sortable => "#{Address.table_name}.country_code", :groupable => "#{Address.table_name}.country_code", :caption => :label_crm_country),
    QueryMultipleValuesColumn.new(:tags, :caption => :label_crm_tags_plural),
    QueryColumn.new(:created_on, :sortable => "#{Contact.table_name}.created_on"),
    QueryColumn.new(:updated_on, :sortable => "#{Contact.table_name}.updated_on"),
    QueryColumn.new(:assigned_to, :sortable => lambda {User.fields_for_order_statement}, :groupable => true),
    QueryColumn.new(:author, :sortable => lambda {User.fields_for_order_statement("authors")})
  ]


  def initialize(attributes=nil, *args)
    super attributes
    self.filters ||= {}
  end

  def initialize_available_filters
    add_available_filter 'ids', type: :contact, label: :label_contact if Redmine::VERSION.to_s >= '3.3'
    add_available_filter "first_name", :type => :string, :order => 0
    add_available_filter "last_name", :type => :string, :order => 1
    add_available_filter "middle_name", :type => :string, :order => 2
    add_available_filter "job_title", :type => :string, :order => 3
    add_available_filter "company", :type => :string, :order => 4
    add_available_filter "phone", :type => :text, :order => 5
    add_available_filter "email", :type => :text, :order => 6
    add_available_filter "full_address", :type => :text, :order => 7, :name => l(:label_crm_address)
    add_available_filter "street1", :type => :text, :order => 8, :name => l(:label_crm_street1)
    add_available_filter "street2", :type => :text, :order => 8, :name => l(:label_crm_street2)
    add_available_filter "city", :type => :text, :order => 8, :name => l(:label_crm_city)
    add_available_filter "region", :type => :text, :order => 9, :name => l(:label_crm_region)
    add_available_filter "postcode", :type => :text, :order => 10, :name => l(:label_crm_postcode)
    add_available_filter "country", :type => :list_optional, :values => l(:label_crm_countries).map{|k, v| [v, k]}, :order => 11, :name => l(:label_crm_country)
    add_available_filter "is_company", :type => :list, :values => [[l(:general_text_yes), ActiveRecord::Base.connection.quoted_true.gsub(/'/, '')], [l(:general_text_no), ActiveRecord::Base.connection.quoted_false.gsub(/'/, '')]], :order => 12
    add_available_filter "last_note", :type => :date_past, :order => 13
    add_available_filter "has_deals", :type => :list, :values => [[l(:general_text_yes), "1"], [l(:general_text_no), "0"]], :order => 14, :name => l(:label_crm_has_deals)
    add_available_filter "updated_on", :type => :date_past, :order => 20
    add_available_filter "created_on", :type => :date, :order => 21
    add_available_filter 'tags', type: :contact_tags, values: Contact.available_tags(project.blank? ? {} : { project: project.id}).collect{ |t| [t.name, t.name] }, order: 12
    initialize_author_filter
    initialize_assignee_filter

    add_available_filter("has_open_issues",
      :type => :list_optional, :values => users_values, :label => :label_crm_has_open_issues
    ) unless users_values.empty?

    add_custom_fields_filters(ContactCustomField.where(:is_filter => true))
    add_associations_custom_fields_filters :author, :assigned_to
  end

  def available_columns
    return @available_columns if @available_columns
    @available_columns = self.class.available_columns.dup
    @available_columns += CustomField.where(:type => 'ContactCustomField').all.map {|cf| QueryCustomFieldColumn.new(cf) }
    @available_columns
  end

  def default_columns_names
    @default_columns_names ||= [:id, :name, :job_title, :company, :phone, :email, :address]
  end

  def sql_for_tags_field(field, operator, value)
    compare   = operator_for('tags').eql?('=') ? 'IN' : 'NOT IN'
    ids_list  = Contact.tagged_with(value, match_all: true).collect{|contact| contact.id }.push(0).join(',')
    "( #{Contact.table_name}.id #{compare} (#{ids_list}) ) "
  end

  def sql_for_ids_field(field, operator, value)
    sql_for_field(field, operator, value, Contact.table_name, 'id')
  end if Redmine::VERSION.to_s >= '3.3'

  def sql_for_is_company_field(field, operator, value)
    if Rails.version >= '5.2'
      value.map! { |v| v == ActiveRecord::Base.connection.quoted_true.gsub(/'/, '') ? true : false }
    end
    sql_for_field(field, operator, value, Contact.table_name, 'is_company')
  end

  def sql_for_project_field(field, operator, value)
    '(' + sql_for_field(field, operator, value, Project.table_name, "id", false) + ')'
  end

  def sql_for_country_field(field, operator, value)
    if operator == '*' # Any group
      contact_countries = l(:label_crm_countries).map{|k, v| k.to_s}
      operator = '=' # Override the operator since we want to find by assigned_to
    elsif operator == "!*"
      contact_countries = l(:label_crm_countries).map{|k, v| k.to_s}
      operator = '!' # Override the operator since we want to find by assigned_to
    else
      contact_countries = value
    end
    '(' + sql_for_field("address_id", operator, contact_countries, Address.table_name, "country_code", false) + ')'
  end

  def sql_for_city_field(field, operator, value)
     sql_for_field(field, operator, value, Address.table_name, "city")
  end

  def sql_for_street1_field(field, operator, value)
     sql_for_field(field, operator, value, Address.table_name, "street1")
  end

  def sql_for_street2_field(field, operator, value)
     sql_for_field(field, operator, value, Address.table_name, "street2")
  end

  def sql_for_full_address_field(field, operator, value)
     sql_for_field(field, operator, value, Address.table_name, "full_address")
  end

  def sql_for_region_field(field, operator, value)
     sql_for_field(field, operator, value, Address.table_name, "region")
  end

  def sql_for_postcode_field(field, operator, value)
     sql_for_field(field, operator, value, Address.table_name, "postcode")
  end

  def sql_for_has_deals_field(field, operator, value)
    db_table = Deal.table_name
    if operator == "!"
      "#{Contact.table_name}.id IN (
        SELECT #{db_table}.contact_id FROM #{db_table}
        GROUP BY #{db_table}.contact_id
        HAVING COUNT(#{db_table}.id) = 0)"
    else operator == "="
      "#{Contact.table_name}.id IN (
        SELECT #{db_table}.contact_id FROM #{db_table}
        GROUP BY #{db_table}.contact_id
        HAVING COUNT(#{db_table}.id) > 0)"
    end
  end

  def sql_for_has_open_issues_field(field, operator, value)
    db_table = ContactNote.table_name
    if operator == "!*"
      "#{Contact.table_name}.id IN (
        SELECT #{Contact.table_name}.id FROM #{Contact.table_name}
        LEFT JOIN contacts_issues ON contacts_issues.contact_id = #{Contact.table_name}.id
        LEFT JOIN #{Issue.table_name} ON contacts_issues.issue_id = #{Issue.table_name}.id
        LEFT JOIN #{IssueStatus.table_name} ON #{IssueStatus.table_name}.id = #{Issue.table_name}.status_id
        WHERE (#{IssueStatus.table_name}.is_closed = #{ActiveRecord::Base.connection.quoted_false}) OR (#{IssueStatus.table_name}.is_closed IS NULL)
        GROUP BY #{Contact.table_name}.id
        HAVING COUNT(#{Issue.table_name}.id) = 0)"
    elsif operator == "*"
      "#{Contact.table_name}.id IN (
        SELECT contacts_issues.contact_id FROM contacts_issues
        INNER JOIN #{Issue.table_name} ON contacts_issues.issue_id = #{Issue.table_name}.id
        INNER JOIN #{IssueStatus.table_name} ON #{IssueStatus.table_name}.id = #{Issue.table_name}.status_id
        WHERE #{IssueStatus.table_name}.is_closed = #{ActiveRecord::Base.connection.quoted_false}
        GROUP BY contacts_issues.contact_id
        HAVING COUNT(#{Issue.table_name}.id) > 0)"
    else
      "#{Contact.table_name}.id IN (
        SELECT contacts_issues.contact_id FROM contacts_issues
        INNER JOIN #{Issue.table_name} ON contacts_issues.issue_id = #{Issue.table_name}.id
        INNER JOIN #{IssueStatus.table_name} ON #{IssueStatus.table_name}.id = #{Issue.table_name}.status_id
        WHERE #{IssueStatus.table_name}.is_closed = #{ActiveRecord::Base.connection.quoted_false}
          AND #{sql_for_field("assigned_to_id", operator, value, Issue.table_name, 'assigned_to_id')}
        GROUP BY contacts_issues.contact_id)"
    end
  end

  def sql_for_last_note_field(field, operator, value)
    db_table = ContactNote.table_name
    if operator == "!*"
      "#{Contact.table_name}.id IN (
        SELECT #{Contact.table_name}.id FROM #{Contact.table_name}
        LEFT JOIN #{db_table} ON #{db_table}.source_id = #{Contact.table_name}.id and #{db_table}.source_type = 'Contact'
        GROUP BY #{Contact.table_name}.id
        HAVING COUNT(#{db_table}.id) = 0)"
    elsif operator == "*"
      "#{Contact.table_name}.id IN (
        SELECT #{Contact.table_name}.id FROM #{Contact.table_name}
        INNER JOIN #{db_table} ON #{db_table}.source_id = #{Contact.table_name}.id and #{db_table}.source_type = 'Contact'
        GROUP BY #{Contact.table_name}.id
        HAVING COUNT(#{db_table}.id) > 0)"
    else
      "#{Contact.table_name}.id IN (
        SELECT #{db_table}.source_id
        FROM #{db_table}
        WHERE #{db_table}.source_type='Contact'
        AND #{db_table}.id IN
          (SELECT MAX(#{db_table}.id)
           FROM #{db_table}
           WHERE #{db_table}.source_type='Contact'
           GROUP BY #{db_table}.source_id)
        AND #{sql_for_field(field, operator, value, db_table, 'created_on')}
      )"
    end
  end

  def objects_scope(options={})
    scope = Contact.visible
    options[:search].split(' ').collect{ |search_string| scope = scope.live_search(search_string) } unless options[:search].blank?
    scope = scope.includes((query_includes + (options[:include] || [])).uniq).
      where(statement).
      where(options[:conditions])
    scope
  end

  def query_includes
    [:address, :projects, :assigned_to]
  end
end
