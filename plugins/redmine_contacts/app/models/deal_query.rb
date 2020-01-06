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

class DealQuery < Query
  include CrmQuery
  include RedmineCrm::MoneyHelper

  self.queried_class = Deal
  self.view_permission = :view_deals if Redmine::VERSION.to_s >= '3.4' || RedmineContacts.unstable_branch?

  self.available_columns = [
    QueryColumn.new(:name, :sortable => "#{Deal.table_name}.name", :caption => :field_deal_name),
    QueryColumn.new(:price, :sortable => ["#{Deal.table_name}.currency", "#{Deal.table_name}.price"], :default_order => 'desc', :caption => :field_price),
    QueryColumn.new(:status, :sortable => "#{Deal.table_name}.status_id", :groupable => true, :caption => :field_contact_status),
    QueryColumn.new(:currency, :sortable => "#{Deal.table_name}.currency", :groupable => true, :caption => :field_currency),
    QueryColumn.new(:contact, :sortable => lambda { Contact.fields_for_order_statement }, :groupable => true, :caption => :label_contact),
    QueryColumn.new(:category, :sortable => "#{Deal.table_name}.category_id", :groupable => true),
    QueryColumn.new(:probability, :sortable => "#{Deal.table_name}.probability", :groupable => "#{Deal.table_name}.probability", :caption => :label_crm_probability),
    QueryColumn.new(:expected_revenue, :sortable => ["#{Deal.table_name}.currency", "#{Deal.table_name}.price * (#{Deal.table_name}.probability / 100)"], :caption => :label_crm_expected_revenue),
    QueryColumn.new(:contact_city, :caption => :label_crm_contact_city, :groupable => "#{Address.table_name}.city", :sortable => "#{Address.table_name}.city"),
    QueryColumn.new(:contact_country, :caption => :label_crm_contact_country, :groupable => "#{Address.table_name}.country_code", :sortable => "#{Address.table_name}.country_code"),
    QueryColumn.new(:due_date, :sortable => "#{Deal.table_name}.due_date"),
    QueryColumn.new(:due_date, :sortable => "#{Deal.table_name}.due_date"),
    QueryColumn.new(:project, :sortable => "#{Project.table_name}.name", :groupable => true),
    QueryColumn.new(:created_on, :sortable => "#{Deal.table_name}.created_on"),
    QueryColumn.new(:updated_on, :sortable => "#{Deal.table_name}.updated_on"),
    QueryColumn.new(:assigned_to, :sortable => lambda { User.fields_for_order_statement }, :groupable => true),
    QueryColumn.new(:author, :sortable => lambda { User.fields_for_order_statement('authors') }),
    QueryColumn.new(:background)
  ]

  def initialize(attributes = nil, *args)
    super attributes
    self.filters ||= { 'status_id' => { :operator => 'o', :values => [''] } }
  end

  def initialize_available_filters
    add_available_filter 'ids', :type => :integer, :label => :label_deal if Redmine::VERSION.to_s >= '3.3'
    add_available_filter 'price', :type => :float, :label => :field_price
    add_available_filter 'currency', :type => :list,
                                     :label => :field_currency,
                                     :values => collection_for_currencies_select(ContactsSetting.default_currency, ContactsSetting.major_currencies)
    add_available_filter 'background', :type => :text, :label => :field_background
    add_available_filter 'due_date', :type => :date, :order => 20
    add_available_filter 'updated_on', :type => :date_past, :order => 20
    add_available_filter 'created_on', :type => :date, :order => 21
    add_available_filter 'probability', :type => :float, :label => :label_crm_probability

    deal_statuses = (project.blank? ? DealStatus.order("#{DealStatus.table_name}.status_type, #{DealStatus.table_name}.position") : project.deal_statuses) || []
    add_available_filter('status_id',
      :type => :list_status, :values => deal_statuses.map { |a| [a.name, a.id.to_s] }, :label => :field_contact_status, :order => 1
    ) unless deal_statuses.empty?

    initialize_project_filter
    initialize_author_filter
    initialize_assignee_filter
    initialize_contact_country_filter
    initialize_contact_city_filter

    add_custom_fields_filters(DealCustomField.where(:is_filter => true))
    add_associations_custom_fields_filters :contact, :notes, :author, :assigned_to
    if RedmineContacts.products_plugin_installed?
      products = Product.visible.all
      add_available_filter('products', :type => :list_optional,
                                       :values => products.map { |a| [a.name, a.id.to_s] }, :label => :label_product_plural
      ) unless products.empty?

      product_categories = []
      ProductCategory.category_tree(ProductCategory.order(:lft)) do |product_category, level|
        name_prefix = (level > 0 ? '-' * 2 * level + ' ' : '').html_safe
        product_categories << [(name_prefix + product_category.name).html_safe, product_category.id.to_s]
      end
      add_available_filter('product_category_id', :type => :list,
                                                  :label => :label_products_category_filter,
                                                  :values => product_categories
      ) if product_categories.any?
      add_associations_custom_fields_filters :products, :lines
    end
  end

  def available_columns
    return @available_columns if @available_columns
    @available_columns = self.class.available_columns.dup
    @available_columns += CustomField.where(:type => 'DealCustomField').all.map { |cf| QueryCustomFieldColumn.new(cf) }
    @available_columns += CustomField.where(:type => 'ContactCustomField').all.map { |cf| QueryAssociationCustomFieldColumn.new(:contact, cf) }
    @available_columns << QueryColumn.new(:products, :caption => :label_product_plural) if RedmineContacts.products_plugin_installed?
    @available_columns
  end

  def default_columns_names
    @default_columns_names ||= [:id, :name, :contact, :price]
  end
  if RedmineContacts.products_plugin_installed?
    def sql_for_products_field(_field, operator, value)
      if operator == '*'
        products = Product.visible.all
        operator = '='
      elsif operator == '!*'
        products = Product.visible.all
        operator = '!'
      else
        products = Product.visible.where(:id => value)
      end
      products ||= []

      order_products = products.map(&:id).uniq.compact.sort.collect(&:to_s)
      '(' + sql_for_field('product_id', operator, order_products, ProductLine.table_name, 'product_id', false) + ')'
    end

    def sql_for_product_category_id_field(field, operator, value)
      category_ids = value
      category_ids += ProductCategory.where(:id => value).map(&:descendants).flatten.collect { |c| c.id.to_s }.uniq
      sql_for_field(field, operator, category_ids, Product.table_name, 'category_id')
    end
  end

  def sql_for_status_id_field(field, operator, value)
    sql = ''
    case operator
    when "o"
      sql = "#{queried_table_name}.status_id IN (SELECT id FROM #{DealStatus.table_name} WHERE status_type = #{DealStatus::OPEN_STATUS})" if field == "status_id"
    when "c"
      sql = "#{queried_table_name}.status_id IN (SELECT id FROM #{DealStatus.table_name} WHERE status_type IN (#{DealStatus::WON_STATUS}, #{DealStatus::LOST_STATUS}))" if field == "status_id"
    else
      sql_for_field(field, operator, value, queried_table_name, field)
    end
  end

  def deal_amount
    @deal_amount ||= objects_scope.group("#{Deal.table_name}.currency").sum(:price)
  rescue ::ActiveRecord::StatementInvalid => e
    raise Query::StatementInvalid.new(e.message)
  end

  def weighted_amount
    @weighted_amount ||= objects_scope.open.group("#{Deal.table_name}.currency").sum("#{Deal.table_name}.price * #{Deal.table_name}.probability / 100")
  rescue ::ActiveRecord::StatementInvalid => e
    raise Query::StatementInvalid.new(e.message)
  end

  def objects_scope(options={})
    scope = Deal.visible
    options[:search].split(' ').collect{ |search_string| scope = scope.live_search(search_string) } unless options[:search].blank?
    scope = scope.includes((query_includes + (options[:include] || [])).uniq).
      where(statement).
      where(options[:conditions])
    scope
  end

  def query_includes
    includes = [:status, :project]
    includes << { :contact => :address } if self.filters['contact_country'] ||
                                            self.filters['contact_city'] ||
                                            [:contact_country, :contact_city].include?(group_by_column.try(:name))
    includes << :assigned_to if self.filters['assigned_to_id'] || (group_by_column && [:assigned_to].include?(group_by_column.name))
    if RedmineContacts.products_plugin_installed?
      includes << :products if filters['products']
      includes << :products if filters['product_category_id']
    end
    includes
  end
end
