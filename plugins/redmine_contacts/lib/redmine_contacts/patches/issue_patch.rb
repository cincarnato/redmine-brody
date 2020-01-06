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

require_dependency 'issue'
require_dependency 'contact'

module RedmineContacts
  module Patches
    module IssuePatch
      def self.included(base) # :nodoc:
        base.send(:include, InstanceMethods)
        base.class_eval do
          unloadable # Send unloadable so it will not be unloaded in development
          has_and_belongs_to_many :contacts, :uniq => true
          has_one :deals_issue
          has_one :deal, :through => :deals_issue
          accepts_nested_attributes_for :deals_issue, :reject_if => :reject_deal, :allow_destroy => true

          safe_attributes 'deals_issue_attributes',
            :if => lambda { |issue, user| user.allowed_to?(:edit_deals, issue.project) }
        end
      end

      class ContactsRelations < IssueRelation::Relations
        def to_s(*args)
          map(&:to_s).join(", ")
        end
      end

      module InstanceMethods
        def reject_deal(attributes)
          exists = attributes['id'].present?
          empty = attributes[:deal_id].blank?
          attributes[:_destroy] = 1 if exists && empty
          !exists && empty
        end

        def contacts_relations
          ContactsRelations.new(self, contacts.to_a)
        end
      end
    end
  end
end

unless Issue.included_modules.include?(RedmineContacts::Patches::IssuePatch)
  Issue.send(:include, RedmineContacts::Patches::IssuePatch)
end
