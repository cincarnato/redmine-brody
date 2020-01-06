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
    module ApplicationHelperPatch
      def self.included(base) # :nodoc:
        base.class_eval do
          unloadable # Send unloadable so it will not be unloaded in development

          def stocked_reorder_link(object, name = nil, url = {}, method = :post)
            Redmine::VERSION.to_s > '3.3' ? reorder_handle(object, :param => name) : reorder_links(name, url, method)
          end
        end
      end
    end
  end
end

unless ApplicationHelper.included_modules.include?(RedmineContacts::Patches::ApplicationHelperPatch)
  ApplicationHelper.send(:include, RedmineContacts::Patches::ApplicationHelperPatch)
end
