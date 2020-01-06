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

class Deal < ActiveRecord::Base
  unloadable
  include Redmine::SafeAttributes

  belongs_to :project
  belongs_to :author, :class_name => 'User', :foreign_key => 'author_id'
  belongs_to :assigned_to, :class_name => 'User', :foreign_key => 'assigned_to_id'
  belongs_to :category, :class_name => 'DealCategory', :foreign_key => 'category_id'
  belongs_to :contact
  belongs_to :status, :class_name => 'DealStatus', :foreign_key => 'status_id'
  has_many :deals, :class_name => 'Deal', :foreign_key => 'reference_id'
  has_many :notes, :as => :source, :class_name => 'DealNote', :dependent => :delete_all
  has_many :deal_processes, :dependent => :delete_all
  has_many :deals_issues, :dependent => :destroy
  has_many :issues, :through => :deals_issues

  if Redmine::Plugin.load && Redmine::Plugin.installed?(:redmine_products) && Redmine::Plugin.find(:redmine_products).version >= '2.0.2'
    has_many :lines, :class_name => 'ProductLine', :as => :container, :dependent => :delete_all
    has_many :products, :through => :lines, :uniq => true, :select => "#{Product.table_name}.*, #{ProductLine.table_name}.position"

    accepts_nested_attributes_for :lines, :allow_destroy => true
    safe_attributes 'lines_attributes'
    acts_as_priceable :amount, :tax_amount, :subtotal, :total

    before_validation :assign_lines
    before_save :calculate_price
  end

  if ActiveRecord::VERSION::MAJOR >= 4
    has_and_belongs_to_many :related_contacts, lambda { order("#{Contact.table_name}.last_name, #{Contact.table_name}.first_name") }, :uniq => true, :class_name => 'Contact'
  else
    has_and_belongs_to_many :related_contacts, :order => "#{Contact.table_name}.last_name, #{Contact.table_name}.first_name", :uniq => true, :class_name => 'Contact'
  end

  scope :visible, lambda {|*args|
    joins(:project).where(Project.allowed_to_condition(args.shift || User.current, :view_deals, *args))
  }
  scope :by_project, lambda { |project_id| where(:project_id => project_id) unless project_id.blank? }
  scope :deletable, lambda { |*args| joins(:project).where(Project.allowed_to_condition(args.first || User.current, :delete_deals)) }

  scope :live_search, lambda { |search| where("(#{Deal.table_name}.name LIKE ?)", "%#{search}%") }
  scope :live_search_with_contact, ->(search) do
    conditions = []
    values = {}
    search.split(' ').each_with_index { |word, index|
      key = :"v#{index}"
      conditions << "LOWER(#{Contact.table_name}.first_name) LIKE LOWER(:#{key})"
      conditions << "LOWER(#{Contact.table_name}.last_name) LIKE LOWER(:#{key})"
      conditions << "LOWER(#{Contact.table_name}.company) LIKE LOWER(:#{key})"
      conditions << "LOWER(#{Contact.table_name}.email) LIKE LOWER(:#{key})"
      values[key] = "%#{word}%"
    }
    sql = conditions.join(' OR ')
    joins(:contact).where(sql, values)
  end

  scope :open, lambda { joins(:status).where("(#{DealStatus.table_name}.status_type = ? OR #{DealStatus.table_name}.status_type IS NULL)", DealStatus::OPEN_STATUS) }
  scope :closed, lambda { joins(:status).where("#{DealStatus.table_name}.status_type <> ?", DealStatus::OPEN_STATUS) }
  scope :won, lambda { joins(:status).where("#{DealStatus.table_name}.status_type = ?", DealStatus::WON_STATUS) }
  scope :lost, lambda { joins(:status).where("#{DealStatus.table_name}.status_type = ?", DealStatus::LOST_STATUS) }
  scope :was_in_status, lambda { |status_id| joins(:deal_processes).where(["#{DealProcess.table_name}.old_value = ? OR #{DealProcess.table_name}.value = ?", status_id, status_id]).uniq }
  scope :with_status, lambda { |status_id| where(:status_id => status_id) }

  acts_as_priceable :price, :expected_revenue
  acts_as_customizable
  acts_as_viewable
  acts_as_watchable
  acts_as_attachable :view_permission => :view_deals,
                     :delete_permission => :edit_deals

  acts_as_event :datetime => :created_on,
                :url => Proc.new { |o| { :controller => 'deals', :action => 'show', :id => o } },
                :type => 'icon icon-add-deal',
                :title => Proc.new { |o| o.name },
                :description => Proc.new { |o| [o.price_to_s, o.contact ? o.contact.name : nil, o.background].join(' ').strip }

  if ActiveRecord::VERSION::MAJOR >= 4
    acts_as_activity_provider :type => 'deals',
                              :permission => :view_deals,
                              :author_key => :author_id,
                              :scope => joins(:project)

    acts_as_searchable :columns => ["#{table_name}.name",
                                    "#{table_name}.background",
                                    "#{DealNote.table_name}.content"],
                       :scope => includes([:project, :notes]),
                       :date_column => :created_on
  else
    acts_as_activity_provider :type => 'deals',
                              :permission => :view_deals,
                              :author_key => :author_id,
                              :find_options => { :include => :project }

    acts_as_searchable :columns => ["#{table_name}.name",
                                    "#{table_name}.background",
                                    "#{DealNote.table_name}.content"],
                       :include => [:project, :notes],
                       :order_column => "#{table_name}.id"
  end

  validates_presence_of :name, :project, :status
  validates_numericality_of :price, :allow_nil => true
  validates :name, length: { maximum: 255 }

  after_update :create_deal_process
  after_create :send_notification

  attr_protected :id if ActiveRecord::VERSION::MAJOR <= 4
  safe_attributes 'name',
                  'background',
                  'currency',
                  'price',
                  'price_type',
                  'duration',
                  'project_id',
                  'author_id',
                  'assigned_to_id',
                  'status_id',
                  'contact_id',
                  'category_id',
                  'probability',
                  'due_date',
                  'custom_field_values',
                  'custom_fields',
                  'watcher_user_ids',
                  :if => lambda { |deal, user| deal.new_record? || user.allowed_to?(:edit_deals, deal.project) }

  def initialize(attributes = nil, *args)
    super
    return unless new_record?
    # set default values for new records only
    self.status_id = DealStatus.default.try(:id)
    self.currency ||= ContactsSetting.default_currency
  end

  def avatar
  end

  def expected_revenue
    probability ? (probability.to_f / 100) * price.to_f : price
  end

  def full_name
    result = ''
    result << contact.name + ': ' unless contact.blank?
    result << name
  end

  def all_contacts
    @all_contacts ||= ([contact] + related_contacts).uniq
  end

  def self.available_users(prj = nil)
    cond = '(1=1)'
    cond << " AND #{Deal.table_name}.project_id = #{prj.id}" if prj
    User.active.select("DISTINCT #{User.table_name}.*").
                joins("JOIN #{Deal.table_name} ON #{Deal.table_name}.assigned_to_id = #{User.table_name}.id").
                where(cond).
                order("#{User.table_name}.lastname, #{User.table_name}.firstname")
  end

  def open?
    status.blank? || status.is_open?
  end

  def init_deal_process(author)
    @current_deal_process ||= DealProcess.new(:deal => self, :author => (author || User.current))
    @deal_status_before_change = new_record? ? nil : status_id
    @current_deal_process
  end

  def create_deal_process
    if @current_deal_process && @deal_status_before_change && !(@deal_status_before_change == status_id)
      @current_deal_process.old_value = @deal_status_before_change
      @current_deal_process.value = status_id
      @current_deal_process.save
      init_deal_process @current_deal_process.author
    end
  end

  def visible?(usr = nil)
    (usr || User.current).allowed_to?(:view_deals, project)
  end

  def editable?(usr = nil)
    (usr || User.current).allowed_to?(:edit_deals, project)
  end

  def destroyable?(usr = nil)
    (usr || User.current).allowed_to?(:delete_deals, project)
  end

  # Returns an array of projects that user can move deal to
  def self.allowed_target_projects(user = User.current)
    Project.where(Project.allowed_to_condition(user, :add_deals))
  end

  # Returns the mail adresses of users that should be notified
  def recipients
    notified = []
    # Author and assignee are always notified unless they have been
    # locked or don't want to be notified
    notified << author if author
    if assigned_to
      notified += (assigned_to.is_a?(Group) ? assigned_to.users : [assigned_to])
    end

    notified += project.notified_users
    notified = notified.select { |u| u.active? }
    notified.uniq!
    # Remove users that can not view the contact
    notified.reject! { |user| !visible?(user) }
    notified.collect(&:mail)
  end

  def status_was
    if status_id_changed? && status_id_was.present?
      @status_was ||= DealStatus.find_by_id(status_id_was)
    end
  end

  def copy_from(arg)
    deal = arg.is_a?(Deal) ? arg : Deal.visible.find(arg)
    self.attributes = deal.attributes.dup.except('id', 'created_at', 'updated_at')
    self.custom_field_values = deal.custom_field_values.inject({}) { |h, v| h[v.custom_field_id] = v.value ; h }
    if Redmine::Plugin.load && Redmine::Plugin.installed?(:redmine_products) && Redmine::Plugin.find(:redmine_products).version >= '2.0.2'
      deal.lines.each do |line|
        lines.build(line.attributes)
      end
    end
    self
  end

  def contact_country
    try(:contact).try(:address).try(:country)
  end

  def contact_city
    try(:contact).try(:address).try(:city)
  end

  if Redmine::Plugin.load && Redmine::Plugin.installed?(:redmine_products) && Redmine::Plugin.find(:redmine_products).version >= '2.0.2'
    def has_taxes?
      !lines.map(&:tax).all? { |t| t == 0 || t.blank? }
    end

    def has_discounts?
      !lines.map(&:discount).all? { |t| t == 0 || t.blank? }
    end

    def tax_amount
      lines.select { |l| !l.marked_for_destruction? }.inject(0) { |sum, l| sum + l.tax_amount }.to_f
    end

    def subtotal
      lines.select { |l| !l.marked_for_destruction? }.inject(0) { |sum, l| sum + l.total }.to_f
    end

    def total_units
      lines.inject(0) { |sum, l| sum + (l.product.blank? ? 0 : l.quantity) }
    end

    def calculate_price
      return true if lines.select { |l| !l.marked_for_destruction? }.empty?
      self.price = subtotal + (ContactsSetting.tax_exclusive? ? tax_amount : 0)
    end
  end

  def info
    result = ''
    result = status.name if status
    result = result + ' - ' + price_to_s unless price.blank?
    result.html_safe
  end
  private

  def send_notification
    Mailer.crm_deal_add(User.current, self).deliver if Setting.notified_events.include?('crm_deal_added')
  end

  if Redmine::Plugin.load && Redmine::Plugin.installed?(:redmine_products) && Redmine::Plugin.find(:redmine_products).version >= '2.0.2'
    def assign_lines
      return unless new_record?
      lines.each { |l| l.container = self }
    end
  end
end
