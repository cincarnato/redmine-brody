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
    module IssueQueryPatch
      def self.included(base)
        base.send(:include, InstanceMethods)
        base.send(:include, RedmineContacts::Helper)
        base.class_eval do
          unloadable

          alias_method :available_columns_without_contacts, :available_columns
          alias_method :available_columns, :available_columns_with_contacts

          alias_method :initialize_available_filters_without_contacts, :initialize_available_filters
          alias_method :initialize_available_filters, :initialize_available_filters_with_contacts
        end
      end

      class QueryContactsColumn < QueryColumn
        def css_classes; 'contacts' end
      end

      module InstanceMethods
        def sql_for_contacts_field(_field, operator, value)
          case operator
          when '=', '*'
            compare = 'IN'
          when '!', '!*'
            compare = 'NOT IN'
          end
          contacts_select = "SELECT contacts_issues.issue_id FROM contacts_issues
              WHERE contacts_issues.contact_id IN (#{value.join(',')})"
          issues_with_contacts = 'SELECT DISTINCT(issue_id) FROM contacts_issues'

          "(#{Issue.table_name}.id #{compare} (#{ %w(= !).include?(operator) ? contacts_select : issues_with_contacts }))"
        end

        def sql_for_companies_field(_field, operator, value)
          compare = operator == '=' ? 'IN' : 'NOT IN'
          employes_select = "SELECT contacts_issues.issue_id FROM contacts_issues
              WHERE contacts_issues.contact_id IN
              ( SELECT c_1.id from #{Contact.table_name}
                LEFT OUTER JOIN #{Contact.table_name} AS c_1 ON c_1.company = #{Contact.table_name}.first_name
                WHERE #{Contact.table_name}.id IN (#{value.join(',')})
              )"
          companies_select = "SELECT contacts_issues.issue_id FROM contacts_issues
              WHERE contacts_issues.contact_id IN (#{value.join(',')})"

          "((#{Issue.table_name}.id #{compare} (#{employes_select}))
          OR (#{Issue.table_name}.id #{compare} (#{companies_select})))"
        end

        def sql_for_deal_field(_field, operator, value)
          if operator == '!*'
            compare = 'NOT IN'
            operator = '*'
          else
            compare = 'IN'
          end

          deals_select = "SELECT deals_issues.issue_id FROM deals_issues
              WHERE #{sql_for_field('deal_id', operator, value, 'deals_issues', 'deal_id')}"

          "(#{Issue.table_name}.id #{compare} (#{deals_select}))"
        end

        def available_columns_with_contacts
          if @available_columns.blank?
            @available_columns = available_columns_without_contacts
            @available_columns << QueryColumn.new(:deal, :caption => :label_deal) if User.current.allowed_to?(:view_deals, project, :global => true)
            @available_columns << QueryContactsColumn.new(:contacts_relations, :caption => :label_contact_plural) if User.current.allowed_to?(:view_contacts, project, :global => true)
          else
            available_columns_without_contacts
          end
          @available_columns
        end

        def initialize_available_filters_with_contacts
          initialize_available_filters_without_contacts

          if !available_filters.key?('contacts') && User.current.allowed_to?(:view_contacts, project, global: true)
            add_available_filter('contacts', type: :contact, name: l(:field_contacts))
          end

          if !available_filters.key?('companies') && User.current.allowed_to?(:view_contacts, project, global: true)
            add_available_filter('companies', type: :company, name: l(:field_companies))
          end

          if !available_filters.key?('deal') && User.current.allowed_to?(:view_deals, project, global: true)
            add_available_filter('deal', type: :deal, name: l(:label_deal))
          end
        end
      end
    end
  end
end

unless IssueQuery.included_modules.include?(RedmineContacts::Patches::IssueQueryPatch)
  IssueQuery.send(:include, RedmineContacts::Patches::IssueQueryPatch)
end
