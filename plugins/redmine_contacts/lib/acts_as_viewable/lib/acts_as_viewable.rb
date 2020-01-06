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

module ActsAsViewable
  module Viewable
    def self.included(base)
      base.extend ClassMethods
    end

    module ClassMethods
      def acts_as_viewable(options = {})
        cattr_accessor :viewable_options
        self.viewable_options = {}
        viewable_options[:info] = options.delete(:info) || "info".to_sym
        if ActiveRecord::VERSION::MAJOR >= 4
          has_many :views, lambda { order("#{RecentlyViewed.table_name}.updated_at DESC") }, :class_name => "RecentlyViewed", :as => :viewed, :dependent => :delete_all
        else
          has_many :views, :order => "#{RecentlyViewed.table_name}.updated_at DESC", :class_name => "RecentlyViewed", :as => :viewed, :dependent => :delete_all
        end

        # attr_reader :info

        send :include, ActsAsViewable::Viewable::InstanceMethods
      end
    end

    module InstanceMethods
      def self.included(base)
        base.extend ClassMethods
      end

      def viewed(user = User.current)
        rv = (self.views.where(:viewer_id => User.current.id).first || self.views.new(:viewer => user))
        rv.increment(:views_count)
        rv.save!
      end

      module ClassMethods
      end
    end

  end
end
