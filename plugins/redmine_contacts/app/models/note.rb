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

class Note < ActiveRecord::Base
  unloadable
  include Redmine::SafeAttributes

  belongs_to :author, :class_name => 'User', :foreign_key => 'author_id'
  belongs_to :source, :polymorphic => true, :touch => true

  # added as a quick fix to allow eager loading of the polymorphic association for multiprojects

  validates_presence_of :source, :author, :content

  acts_as_customizable
  acts_as_attachable

  acts_as_event :title => Proc.new { |o| "#{l(:label_crm_note_for)}: #{o.source.name}" },
                :type => 'icon issue-note icon-issue-note',
                :group => :source,
                :url => Proc.new { |o| {:controller => 'notes', :action => 'show', :id => o.id } },
                :description => Proc.new {|o| o.content}

  after_create :send_notification

  cattr_accessor :note_types
  @@note_types = { :email => 0, :call => 1, :meeting => 2 }
  cattr_accessor :cut_length
  @@cut_length = 1000

  attr_protected :id if ActiveRecord::VERSION::MAJOR <= 4
  safe_attributes 'subject', 'type_id', 'author_id', 'note_time', 'content', 'created_on', 'custom_field_values'

  def attachments_visible?(user = User.current)
    visible?(user) && user.allowed_to?(source.class.attachable_options[:view_permission], project)
  end

  def attachments_editable?(user = User.current)
    visible?(user) && user.allowed_to?(source.class.attachable_options[:edit_permission], project)
  end

  def attachments_deletable?(user = User.current)
    visible?(user) && user.allowed_to?(source.class.attachable_options[:delete_permission], project)
  end

  def self.note_types
    @@note_types
  end

  def note_time
    created_on.to_s(:time) if created_on.present?
  end

  def note_time=(val)
    if created_on.present? && val.to_s.gsub(/\s/, '').match(/^(\d{1,2}):(\d{1,2})$/)
      self.created_on = created_on.change(:hour => $1.to_i % 24, :min => $2.to_i % 60)
    end
  end

  def visible?(usr = nil)
    source.visible?(usr)
  end

  def project
    source.respond_to?(:project) ? source.project : nil
  end

  def editable_by?(usr, prj = nil)
    prj ||= @project || project
    usr && (usr.allowed_to?(:delete_notes, prj) || (author == usr && usr.allowed_to?(:delete_own_notes, prj)))
    # usr && usr.logged? && (usr.allowed_to?(:edit_notes, project) || (self.author == usr && usr.allowed_to?(:edit_own_notes, project)))
  end

  def destroyable_by?(usr, prj = nil)
    prj ||= @project || project
    usr && (usr.allowed_to?(:delete_notes, prj) || (author == usr && usr.allowed_to?(:delete_own_notes, prj)))
  end

  def created_on
    return nil if super.blank?
    zone = User.current.time_zone
    zone ? super.in_time_zone(zone) : (super.utc? ? super.localtime : super)
  end

  private

  def send_notification
    Mailer.crm_note_add(User.current, self).deliver if Setting.notified_events.include?('crm_note_added')
  end
end
