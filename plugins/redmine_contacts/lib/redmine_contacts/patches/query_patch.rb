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

require_dependency 'query'

module RedmineContacts
  module Patches
    module QueryPatch
      def self.included(base)
        base.send(:include, InstanceMethods)
        base.class_eval do
          unloadable

          alias_method :add_filter_without_contacts, :add_filter
          alias_method :add_filter, :add_filter_with_contacts

          alias_method :add_available_filter_without_contacts, :add_available_filter
          alias_method :add_available_filter, :add_available_filter_with_contacts
        end
      end

      module InstanceMethods
        def add_available_filter_with_contacts(field, options)
          add_available_filter_without_contacts(field, options)
          values = filters[field].blank? ? [] : filters[field][:values]
          initialize_values_for_select2(field, values)
          @available_filters
        end

        def add_filter_with_contacts(field, operator, values = nil)
          add_filter_without_contacts(field, operator, values)
          return unless available_filters[field]
          initialize_values_for_select2(field, values)
          true
        end

        def initialize_values_for_select2(field, values)
          case @available_filters[field][:type]
          when :contact, :company
            @available_filters[field][:values] = ids_to_names_with_ids(values, Contact)
          when :deal
            @available_filters[field][:values] = ids_to_names_with_ids(values, Deal)
          end
        end

        def ids_to_names_with_ids(ids, model)
          ids.blank? ? [] : model.visible.where(:id => ids).map { |r| [r.name, r.id.to_s] }
        end
      end
    end
  end
end

unless Query.included_modules.include?(RedmineContacts::Patches::QueryPatch)
  Query.send(:include, RedmineContacts::Patches::QueryPatch)
end
