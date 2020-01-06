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

require_dependency 'queries_helper'

module RedmineContacts
  module Patches
    module QueriesHelperPatch
      def self.included(base)
        base.send(:include, InstanceMethods)

        base.class_eval do
          unloadable
          alias_method :column_value_without_contacts, :column_value
          alias_method :column_value, :column_value_with_contacts
        end
      end

      module InstanceMethods
        def column_value_with_contacts(column, list_object, value)
          if column.name == :id && list_object.is_a?(Contact)
            link_to(value, contact_path(value))
          elsif column.name == :name && list_object.is_a?(Contact)
            contact_tag(list_object)
          elsif column.name == :name && list_object.is_a?(Deal)
            link_to(list_object.name, deal_path(list_object))
          elsif column.name == :price && list_object.is_a?(Deal)
            list_object.price_to_s
          elsif column.name == :expected_revenue && list_object.is_a?(Deal)
            list_object.expected_revenue_to_s
          elsif column.name == :probability && !value.blank? && list_object.is_a?(Deal)
            "#{value.to_i}%"
          elsif value.is_a?(Deal)
            deal_tag(value, :no_contact => true, :plain => true)
          elsif value.is_a?(Contact)
            contact_tag(value)
          elsif column.name == :contacts_relations
            contacts_span = []
            [value].flatten.each do |contact|
              contacts_span << contact_tag(contact)
            end
            contacts_span.join(', ').html_safe
          elsif column.name == :tags && list_object.is_a?(Contact)
            contact_tags = []
            [value].flatten.each do |tag|
              contact_tags << tag.name
            end
            contact_tags.join(', ')
          else
            column_value_without_contacts(column, list_object, value)
          end
        end
      end
    end
  end
end

unless QueriesHelper.included_modules.include?(RedmineContacts::Patches::QueriesHelperPatch)
  QueriesHelper.send(:include, RedmineContacts::Patches::QueriesHelperPatch)
end
