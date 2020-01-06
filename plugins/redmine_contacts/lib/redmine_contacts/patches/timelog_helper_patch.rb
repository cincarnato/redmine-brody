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
    module TimelogHelperPatch
      def self.included(base)
        base.send(:include, InstanceMethods)

        base.class_eval do
          unloadable
          alias_method :format_criteria_value_without_contacts, :format_criteria_value
          alias_method :format_criteria_value, :format_criteria_value_with_contacts
        end
      end

      module InstanceMethods
        def format_criteria_value_with_contacts(criteria_options, *value)
          splatted_value = value.first
          if splatted_value.present? && criteria_options[:kclass] == Contact && obj = Contact.find_by_id(splatted_value.to_i)
            obj.visible? ? obj.name : "#{l(:label_contact)} - ##{obj.id}"
          elsif splatted_value.present? && criteria_options[:kclass] == Deal && obj = Deal.find_by_id(splatted_value.to_i)
            obj.visible? ? "#{obj.full_name} (#{obj.info})" : "#{l(:label_deal)} - ##{obj.id}"
          else
            format_criteria_value_without_contacts(criteria_options, *value)
          end
        end
      end
    end
  end
end

unless TimelogHelper.included_modules.include?(RedmineContacts::Patches::TimelogHelperPatch)
  TimelogHelper.send(:include, RedmineContacts::Patches::TimelogHelperPatch)
end
