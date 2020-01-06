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

class DealStatus < ActiveRecord::Base
  unloadable
  include Redmine::SafeAttributes

  OPEN_STATUS = 0
  WON_STATUS = 1
  LOST_STATUS = 2

  before_destroy :check_integrity

  attr_protected :id if ActiveRecord::VERSION::MAJOR <= 4
  safe_attributes 'name', 'is_default', 'status_type', 'move_to', 'color_name', 'position'

  has_and_belongs_to_many :projects
  has_many :deals, :foreign_key => 'status_id', :dependent => :nullify
  has_many :deal_processes_from, :class_name => 'DealProcess',:foreign_key => 'old_value', :dependent => :delete_all
  has_many :deal_processes_to, :class_name => 'DealProcess', :foreign_key => 'value', :dependent => :delete_all
  rcrm_acts_as_list :scope => 'status_type = #{status_type}'

  scope :open, lambda { where(:status_type => DealStatus::OPEN_STATUS) }
  scope :won, lambda { where(:status_type => DealStatus::WON_STATUS) }
  scope :lost, lambda { where(:status_type => DealStatus::LOST_STATUS) }
  scope :closed, lambda { where("#{DealStatus.table_name}.status_type <> #{DealStatus::OPEN_STATUS}") }

  after_save     :update_default

  validates_presence_of :name
  validates_uniqueness_of :name
  validates_length_of :name, :maximum => 30

  def update_default
    DealStatus.where('id <> ?', id).update_all(:is_default => false) if is_default?
  end

  # Returns the default status for new Deals
  def self.default
    where(:is_default => true).first
  end

  def is_open?
    status_type == OPEN_STATUS
  end

  def is_won?
    status_type == WON_STATUS
  end

  def is_lost?
    status_type == LOST_STATUS
  end

  def is_closed?
    !is_open?
  end

  def status_type_name
    case status_type
    when OPEN_STATUS then l(:label_open_issues)
    when WON_STATUS then l(:label_crm_deal_status_won)
    when LOST_STATUS then l(:label_crm_deal_status_lost)
    else ''
    end
  end

  def new_status_allowed_to?(status, roles, tracker)
    if status && roles && tracker
      !workflows.where(:new_status_id => status.id).where(:role_id => roles.collect(&:id)).where(:tracker_id => tracker.id).first.nil?
    else
      false
    end
  end

  def color_name
    return '#' + "%06x" % color unless color.nil?
  end

  def color_name=(clr)
    self.color = clr.from(1).hex
  end

  def <=>(status)
    position <=> status.position
  end

  def to_s; name end

  private

  def check_integrity
    raise "Can't delete status" if Deal.where(:status_id => id).any?
  end

  # Deletes associated workflows
  def delete_workflows
    Workflow.delete_all(['old_status_id = :id OR new_status_id = :id', { :id => id }])
  end
end
