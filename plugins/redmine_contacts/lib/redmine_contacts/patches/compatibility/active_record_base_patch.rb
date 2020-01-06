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
    module ActiveRecordBasePatch
      def self.included(base)
        base.send(:include, InstanceMethods)
        base.class_eval do
          alias_method :has_many_without_contacts, :has_many
          alias_method :has_many, :has_many_with_contacts
        end
      end

      module InstanceMethods
        def has_many_with_contacts(name, param2 = nil, *param3, &extension)
          return has_many_without_contacts(name, param2, *param3, &extension) if param3 && param3.is_a?(Array) && param3[0] && param3[0][:through]
          if param2.nil?
            options = {}
          else
            if param2.is_a?(Proc)
              scope = param2
              options = param3.empty? ? {} : param3[0]
            else
              options = param2
            end
          end
          if ActiveRecord::VERSION::MAJOR >= 4
            scope, options = build_scope_and_options(options) if scope.nil?
            has_many_without_contacts(name, scope, options, &extension)
          else
            has_many_without_contacts(name, options, &extension)
          end
        end

        def build_scope_and_options(options)
          scope_opts, opts = parse_options(options)

          unless scope_opts.empty?
            scope = lambda do
              scope_opts.inject(self) { |result, hash| result.send *hash }
            end
          end
          [defined?(scope) ? scope : nil, opts]
        end

        def parse_options(opts)
          scope_opts = {}
          [:order, :having, :select, :group, :limit, :offset, :readonly].each do |o|
            scope_opts[o] = opts.delete o if opts[o]
          end
          scope_opts[:where] = opts.delete :conditions if opts[:conditions]
          scope_opts[:joins] = opts.delete :include if opts [:include]
          scope_opts[:distinct] = opts.delete :uniq if opts[:uniq]

          [scope_opts, opts]
        end
      end
    end
  end
end

if defined?(ActiveRecord::Base)
  ActiveRecord::Base.extend RedmineContacts::Patches::ActiveRecordBasePatch::InstanceMethods
  unless ActiveRecord::Associations::ClassMethods.included_modules.include?(RedmineContacts::Patches::ActiveRecordBasePatch)
    ActiveRecord::Associations::ClassMethods.send(:include, RedmineContacts::Patches::ActiveRecordBasePatch)
  end
end
