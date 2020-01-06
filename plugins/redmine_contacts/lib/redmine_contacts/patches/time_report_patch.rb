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
    module TimeReportPatch
      def self.included(base)
        base.send(:include, InstanceMethods)

        base.class_eval do
          unloadable
          alias_method :load_available_criteria_without_contacts, :load_available_criteria
          alias_method :load_available_criteria, :load_available_criteria_with_contacts
        end
      end

      module InstanceMethods
        def load_available_criteria_with_contacts
          @available_criteria = load_available_criteria_without_contacts
          @available_criteria['deal'] = { :sql => 'd_deals_issues.deal_id',
                                          :kclass => Deal,
                                          :joins => 'LEFT OUTER JOIN deals_issues d_deals_issues ON d_deals_issues.issue_id = issues.id',
                                          :label => :label_deal } if User.current.allowed_to?(:view_deals, @project, :global => true)
          @available_criteria['deal_contact'] = { :sql => 'd_deals.contact_id',
                                                  :kclass => Contact,
                                         :joins => 'LEFT OUTER JOIN deals_issues c_deals_issues ON c_deals_issues.issue_id = issues.id
                                                    LEFT OUTER JOIN deals d_deals ON c_deals_issues.deal_id = d_deals.id',
                                         :label => :label_crm_deal_contact } if User.current.allowed_to?(:view_deals, @project, :global => true)
          @available_criteria
        end
      end
    end
  end
end

unless Redmine::Helpers::TimeReport.included_modules.include?(RedmineContacts::Patches::TimeReportPatch)
  Redmine::Helpers::TimeReport.send(:include, RedmineContacts::Patches::TimeReportPatch)
end
