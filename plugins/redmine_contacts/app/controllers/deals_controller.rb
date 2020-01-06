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

class DealsController < ApplicationController
  unloadable

  PRICE_TYPE_PULLDOWN = [l(:label_price_fixed_bid), l(:label_price_per_hour)]

  before_action :find_deal, :only => [:show, :edit, :update, :destroy]
  before_action :find_project, :only => [:new, :create, :update_form]
  before_action :bulk_find_deals, :only => [:bulk_update, :bulk_edit, :bulk_destroy, :context_menu]
  before_action :authorize, :except => [:index]
  before_action :find_optional_project, :only => [:index]
  before_action :update_deal_from_params, :only => [:edit, :update]
  before_action :build_new_deal_from_params, :only => [:new, :update_form]
  before_action :find_deal_attachments, :only => :show
  skip_before_action :authorize, :only => :add_product_line if RedmineContacts.products_plugin_installed?

  accept_api_auth :index, :show, :create, :update, :destroy

  helper :attachments
  helper :timelog
  helper :watchers
  helper :custom_fields
  helper :context_menus
  helper :sort
  helper :crm_queries
  helper :notes
  helper :queries
  helper :calendars
  include QueriesHelper
  include CrmQueriesHelper
  include WatchersHelper
  include DealsHelper
  include SortHelper
  if RedmineContacts.products_plugin_installed?
    include ProductsHelper
    helper :products
  end

  def index
    retrieve_crm_query('deal')
    sort_init(@query.sort_criteria.empty? ? [['created_on', 'desc']] : @query.sort_criteria)
    sort_update(@query.sortable_columns)
    @query.sort_criteria = sort_criteria.to_a

    if @query.valid?
      case params[:format]
      when 'csv', 'pdf'
        @limit = Setting.issues_export_limit.to_i
      when 'atom'
        @limit = Setting.feeds_limit.to_i
      when 'xml', 'json'
        @offset, @limit = api_offset_and_limit
      else
        @limit = per_page_option
      end

      @deals_count = @query.object_count
      @deals_scope = @query.objects_scope
      @deal_amount = @query.deal_amount
      @deal_weighted_amount = @query.weighted_amount
      @deals_pages = Paginator.new @deals_count, @limit, params['page']
      @offset ||= @deals_pages.offset
      @deal_count_by_group = @query.object_count_by_group
      @deals = @query.results_scope(
        :include => [{ :contact => [:avatar, :projects, :address] }, :author],
        :search => params[:search],
        :order => sort_clause,
        :limit  =>  @limit,
        :offset =>  @offset
      )

      if deals_list_style == 'crm_calendars/crm_calendar'
        retrieve_crm_calendar(:start_date_field => 'due_date')
        @calendar.events = @query.results_scope(
            :include => [:contact],
            :search => params[:search],
            :conditions => ['due_date BETWEEN ? AND ?', @calendar.startdt, @calendar.enddt]
        )
      end

      respond_to do |format|
        format.html { request.xhr? ? render(:partial => deals_list_style, :layout => false) : last_notes }
        format.api
        format.atom { render_feed(@deals, :title => "#{@project || Setting.app_title}: #{l(:label_order_plural)}") }
        format.csv  { send_data(deals_to_csv(@deals), :type => 'text/csv; header=present', :filename => 'deals.csv') }
        format.pdf  { send_data(deals_to_pdf(@deals, @project, @query), :type => 'application/pdf', :filename => 'deals.pdf') }
      end
    else
      respond_to do |format|
        format.html { render(:template => 'deals/index', :layout => !request.xhr?) }
        format.any(:atom, :csv, :pdf) { render(:nothing => true) }
        format.api { render_validation_errors(@query) }
      end
    end
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def show
    @note = DealNote.new(:created_on => Time.now)
    respond_to do |format|
      format.html do
        @deal_issues = @deal.issues.visible
        @deal.viewed
        @deal_events = (@deal.deal_processes.where("#{DealProcess.table_name}.old_value IS NOT NULL").includes([:to, :from, :author]) | @deal.notes.includes([:attachments, :author])).map{|o| {:date => o.is_a?(DealProcess) ? o.created_at : o.created_on, :author => o.author, :object => o} }
        @deal_events.sort! { |x, y| y[:date] <=> x[:date] }
      end
      format.api
    end
  end

  def new
  end

  def create
    @deal = Deal.new
    @deal.safe_attributes = params[:deal]
    @deal.project = @project
    @deal.author ||= User.current
    @deal.price = parsed_price(params[:deal][:price])
    @deal.init_deal_process(User.current)
    if @deal.save
      flash[:notice] = l(:notice_successful_create)
      respond_to do |format|
        format.html { redirect_to(params[:continue] ? { :action => 'new' } : { :action => 'show', :id => @deal }) }
        format.api  { render :action => 'show', :status => :created, :location => deal_url(@deal) }
      end

    else
      respond_to do |format|
        format.html { render :action => 'new' }
        format.api  { render_validation_errors(@deal) }
      end
    end
  end

  def update
    @deal.init_deal_process(User.current)
    @deal.safe_attributes = params[:deal]
    if @deal.save
      # @deal.contacts = [Contact.find(params[:contacts])] if params[:contacts]
      if Redmine::Plugin.load && Redmine::Plugin.installed?(:redmine_products) && Redmine::Plugin.find(:redmine_products).version >= '2.0.2'
        @deal.lines.each(&:save)
      end

      retrieve_crm_query('deal')
      @deals_scope = @query.objects_scope
      flash[:notice] = l(:notice_successful_update)
      respond_to do |format|
        format.html { redirect_back_or_default(:action => 'show', :id => @deal) }
        format.api  { render_api_ok }
        format.js   { render :update_total }
      end
    else
      respond_to do |format|
        format.html { render :action => 'edit' }
        format.api  { render_validation_errors(@deal) }
        format.js   { render "alert('Error!')" }
      end
    end
  end

  def edit
    respond_to do |format|
      format.html {}
      format.xml  {}
    end
  end

  def destroy
    if @deal.destroy
      flash[:notice] = l(:notice_successful_delete)
      respond_to do |format|
        format.html { redirect_to :action => 'index', :project_id => params[:project_id] }
        format.api { render_api_ok }
      end
    else
      flash[:error] = l(:notice_unsuccessful_save)
    end
  end

  def context_menu
    @deal = @deals.first if @deals.size == 1
    @can = { :edit => User.current.allowed_to?(:edit_deals, @projects),
             :delete => User.current.allowed_to?(:delete_deals, @projects) }

    @back = back_url
    render :layout => false
  end

  def bulk_destroy
    @deals.each do |deal|
      begin
        deal.reload.destroy
      rescue ::ActiveRecord::RecordNotFound # raised by #reload if deal no longer exists
        # nothing to do, deal was already deleted (eg. by a parent)
      end
    end
    respond_to do |format|
      format.html { redirect_back_or_default(:action => 'index', :project_id => params[:project_id]) }
      format.api  { head :ok }
    end
  end

  def bulk_edit
    @available_statuses = @projects.map(&:deal_statuses).inject { |memo, w| memo & w }
    @custom_fields = DealCustomField.order(:name)
    @available_categories = @projects.map(&:deal_categories).inject { |memo, w| memo & w }
    @assignables = @projects.map(&:assignable_users).inject { |memo, a| memo & a }
  end

  def bulk_update
    unsaved_deal_ids = []
    @deals.each do |deal|
      deal.reload
      deal.init_deal_process(User.current)
      deal.safe_attributes = parse_params_for_bulk_deal_attributes(params)
      unless deal.save
        # Keep unsaved deal ids to display them in flash error
        unsaved_deal_ids << deal.id
      end
      if params[:note] && !params[:note][:content].blank?
        note = DealNote.new
        note.safe_attributes = params[:note]
        note.author = User.current
        deal.notes << note
      end
    end
    set_flash_from_bulk_contact_save(@deals, unsaved_deal_ids)
    redirect_back_or_default(:controller => 'deals', :action => 'index', :project_id => @project)
  end

  private

  def last_notes(count = 5)
    # TODO: Исправить говнокод этот и выделить все в плагин acts-as-noteble
    scope = DealNote.where({})
    scope = scope.where("#{Deal.table_name}.project_id = ?", @project.id) if @project

    @last_notes = scope.visible.order("#{DealNote.table_name}.created_on DESC").limit(count)
  end

  def build_new_deal_from_params
    if params[:id].blank?
      @deal = Deal.new
      @deal.assigned_to_id = User.current.id
      @deal.name = params[:name] if params[:name]
      @deal.contact = Contact.find(params[:contact_id]) if params[:contact_id]
      if params[:copy_from]
        begin
          @copy_from = Deal.visible.find(params[:copy_from])
          @deal.copy_from(@copy_from)
        rescue ActiveRecord::RecordNotFound
          render_404
          return
        end
      end
    else
      @deal = Deal.visible.find(params[:id])
    end

    @deal.project = @project
    @deal.author ||= User.current
    @deal.safe_attributes = params[:deal]

    @available_watchers = (@deal.project.users.sort + @deal.watcher_users).uniq
  end

  def update_deal_from_params
  end

  def update_form
  end

  def find_deal_attachments
    @deal_attachments = Attachment.where(:container_type => 'Note', :container_id => @deal.notes.map(&:id)).order(:created_on)
  end

  def bulk_find_deals
    @deals = Deal.where(:id => (params[:id] || params[:ids])).includes([:project, :contact])
    raise ActiveRecord::RecordNotFound if @deals.empty?
    if @deals.detect { |deal| !deal.visible? }
      deny_access
      return
    end
    @projects = @deals.collect(&:project).compact.uniq
    @project = @projects.first if @projects.size == 1
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def find_deal
    @deal = Deal.where(:id => params[:id]).includes([:project, :status, :category]).first
    @project = @deal.project
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def find_project(project_id = nil)
    project_id ||= (params[:deal] && params[:deal][:project_id]) || params[:project_id]
    @project = Project.find(project_id)
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def parse_params_for_bulk_deal_attributes(params)
    attributes = (params[:deal] || {}).reject { |_k, v| v.blank? }
    attributes.keys.each { |k| attributes[k] = '' if attributes[k] == 'none' }
    attributes[:custom_field_values].reject! { |_k, v| v.blank? } if attributes[:custom_field_values]
    attributes
  end

  def parsed_price(price)
    return unless price
    price.gsub!(ContactsSetting.thousands_delimiter, '')
    price.gsub!(ContactsSetting.decimal_separator, '.')
    price.to_f
  end
end
