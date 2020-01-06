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

module RedmineContacts
  module Patches
    module ProjectPatch
      def self.included(base) # :nodoc:
        base.class_eval do
          unloadable # Send unloadable so it will not be unloaded in development

          has_many :deals, :dependent => :delete_all
          if ActiveRecord::VERSION::MAJOR >= 4
            has_and_belongs_to_many :contacts, lambda { order("#{Contact.table_name}.last_name, #{Contact.table_name}.first_name") }

            has_many :deal_categories, lambda { order("#{DealCategory.table_name}.name") }, :dependent => :delete_all
            has_and_belongs_to_many :deal_statuses, lambda { order("#{DealStatus.table_name}.status_type, #{DealStatus.table_name}.position") }
          else
            has_and_belongs_to_many :contacts, :order => "#{Contact.table_name}.last_name, #{Contact.table_name}.first_name"

            has_many :deal_categories, :order => "#{DealCategory.table_name}.name", :dependent => :delete_all
            has_and_belongs_to_many :deal_statuses, :order => "#{DealStatus.table_name}.status_type, #{DealStatus.table_name}.position", :uniq => true
          end
        end
      end
    end
  end
end

unless Project.included_modules.include?(RedmineContacts::Patches::ProjectPatch)
  Project.send(:include, RedmineContacts::Patches::ProjectPatch)
end
