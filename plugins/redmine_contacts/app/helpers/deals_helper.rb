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

module DealsHelper
  include ContactsHelper
  def collection_for_status_select
    deal_statuses.collect{|s| [s.name, s.id.to_s]}
  end

  def deal_status_options_for_select(select="")
     options_for_select(collection_for_status_select, select)
  end

  def deal_statuses
    (!@project.blank? ? @project.deal_statuses : DealStatus.order("#{DealStatus.table_name}.status_type, #{DealStatus.table_name}.position")) || []
  end

  def deal_status_url(status_id, options={})
    {:controller => 'deals',
     :action => 'index',
     :set_filter => 1,
     :project_id => @project,
     :fields => [:status_id],
     :values => {:status_id => [status_id]},
     :operators => {:status_id => '='}}.merge(options)
  end

  def pipeline_status_tag(deal_status, count, index)
    total = @processor.scope.count
    width ||= 20 if deal_status.is_won?
    width ||= 40 if deal_status.is_lost?
    width ||= (100 - 20) * (count.to_f / total.to_f) + 20
    width_style = index == 0 ? "" : "width: #{width}%"
    status_tag = content_tag(:span, deal_status.name)
    content_tag(:span, status_tag, :class => "tag-label-color", :style => "background-color:#{deal_status.color_name};color:white; #{width_style}")
  end

  def remove_contractor_link(contact)
    link_to(image_tag('delete.png'),
      {:controller => "deal_contacts", :action => 'delete', :project_id => @project, :deal_id => @deal, :contact_id => contact},
      :remote => true,
      :method => :delete,
      :data => {:confirm => l(:text_are_you_sure)},
      :class  => "delete", :title => l(:button_delete)) if  User.current.allowed_to?(:edit_deals, @project)
  end

  def link_to_deal(deal)
    link_to deal.name, deal_path(deal)
  end

  def deal_list_styles_for_select
    [[l(:label_crm_list_excerpt), "list_excerpt"],
     [l(:label_crm_list_list), "list"],
     [l(:label_crm_list_board), "list_board"],
     [l(:label_calendar), "crm_calendars/crm_calendar"],
     [l(:label_crm_pipeline), "list_pipeline"]]
  end

  def deals_list_style
    list_styles = deal_list_styles_for_select.map(&:last)
    if params[:deals_list_style].blank?
      list_style = list_styles.include?(session[:deals_list_style]) ? session[:deals_list_style] : RedmineContacts.default_list_style.gsub("list_cards", "list_board")
    else
      list_style = list_styles.include?(params[:deals_list_style]) ? params[:deals_list_style] : RedmineContacts.default_list_style.gsub("list_cards", "list_board")
    end
    session[:deals_list_style] = list_style
  end

  def retrieve_deals_query
    if params[:status_id] || !params[:period].blank? || !params[:category_id].blank? || !params[:assigned_to_id].blank?
      session[:deals_query] = {:project_id => (@project ? @project.id : nil),
                               :status_id => params[:status_id],
                               :category_id => params[:category_id],
                               :period => params[:period],
                               :assigned_to_id => params[:assigned_to_id]}
    else
      if api_request? || params[:set_filter] || session[:deals_query].nil? || session[:deals_query][:project_id] != (@project ? @project.id : nil)
        session[:deals_query] = {}
      else
        params.merge!(session[:deals_query])
      end
    end
  end

  def pipeline_prices(scope)
    prices_collection_by_currency(scope.group_by(&:currency).map{|k,v| [k, v.inject(0) { |sum, x| sum + x.price.to_f } ] }).join(' / ').html_safe
  end

  def deals_to_csv(deals)
    return "" unless User.current.allowed_to?(:export_contacts, @project, :global => true)
    decimal_separator = l(:general_csv_decimal_separator)
    encoding = 'utf-8'
    export = FCSV.generate(:col_sep => l(:general_csv_separator)) do |csv|
      # csv header fields
      headers = [ "#",
                  l(:field_name, :locale => :en),
                  l(:field_background, :locale => :en),
                  l(:field_currency, :locale => :en),
                  l(:field_price, :locale => :en),
                  l(:label_crm_probability, :locale => :en),
                  l(:label_crm_expected_revenue, :locale => :en),
                  l(:field_due_date, :locale => :en),
                  l(:field_author, :locale => :en),
                  l(:field_assigned_to, :locale => :en),
                  l(:field_status, :locale => :en),
                  l(:field_contact, :locale => :en),
                  l(:field_category, :locale => :en),
                  l(:field_created_on, :locale => :en),
                  l(:field_updated_on, :locale => :en)
                  ]

      custom_fields = DealCustomField.order(:name)
      custom_fields.each {|f| headers << f.name}
      csv << headers.collect {|c| Redmine::CodesetUtil.from_utf8(c.to_s, encoding) }
      # csv lines
      deals.each do |deal|
        fields = [deal.id,
                  deal.name,
                  deal.background,
                  deal.currency,
                  deal.price,
                  deal.probability,
                  deal.expected_revenue,
                  format_date(deal.due_date),
                  deal.author,
                  deal.assigned_to,
                  deal.status,
                  deal.contact,
                  deal.category,
                  format_date(deal.created_on),
                  format_date(deal.updated_on)
                  ]
        deal.custom_field_values.sort_by{|v| v.custom_field.name}.each {|custom_value| fields << RedmineContacts::CSVUtils.csv_custom_value(custom_value) }
        csv << fields.collect {|c| Redmine::CodesetUtil.from_utf8(c.to_s, encoding) }
      end
    end
    export
  end

  def importer_link
    project_deal_imports_path
  end

  def importer_show_link(importer, project)
    project_deal_import_path(:id => importer, :project_id => project)
  end

  def importer_settings_link(importer, project)
    settings_project_deal_import_path(:id => importer, :project => project)
  end

  def importer_run_link(importer, project)
    run_project_deal_import_path(:id => importer, :project_id => project, :format => 'js')
  end

  def importer_link_to_object(deal)
    link_to deal.name, deal_path(deal)
  end

  def _project_deals_path(project, *args)
    if project
      project_deals_path(project, *args)
    else
      deals_path(*args)
    end
  end
end
