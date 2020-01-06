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
    module IssuesControllerPatch
      def self.included(base) # :nodoc:
        base.send(:include, InstanceMethods)

        base.class_eval do
          unloadable
          alias_method :build_new_issue_from_params_without_contacts, :build_new_issue_from_params
          alias_method :build_new_issue_from_params, :build_new_issue_from_params_with_contacts
        end
      end

      module InstanceMethods
        def build_new_issue_from_params_with_contacts
          build_new_issue_from_params_without_contacts
          return if @issue.blank? || params[:deal_id].blank?
          deal = Deal.visible.where(:id => params[:deal_id]).first
          @issue.deals_issue = DealsIssue.new(:issue => @issue, :deal => deal) if deal
        end
      end
    end
  end
end

unless IssuesController.included_modules.include?(RedmineContacts::Patches::IssuesControllerPatch)
  IssuesController.send(:include, RedmineContacts::Patches::IssuesControllerPatch)
end
