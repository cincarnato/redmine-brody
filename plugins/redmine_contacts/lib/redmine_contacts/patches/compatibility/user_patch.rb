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
    module UserPatch
      def self.included(base)
        base.class_eval do
          scope :having_mail, lambda {|arg|
            addresses = Array.wrap(arg).map {|a| a.to_s.downcase}
            if addresses.any?
              joins(:email_addresses).where("LOWER(#{EmailAddress.table_name}.address) IN (?)", addresses).uniq
            else
              none
            end
          }

          def self.find_by_mail(mail)
            if ActiveRecord::VERSION::MAJOR >= 4
              mail.is_a?(Array) ? mail : [mail]
              having_mail(mail).first
            else
              where("LOWER(mail) = ?", mail.to_s.downcase).first
            end
          end
        end
      end
    end
  end
end

unless User.included_modules.include?(RedmineContacts::Patches::UserPatch)
  User.send(:include, RedmineContacts::Patches::UserPatch)
end
