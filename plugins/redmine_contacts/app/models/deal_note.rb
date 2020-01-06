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

class DealNote < Note
  unloadable
  include Redmine::SafeAttributes
  belongs_to :deal, :foreign_key => :source_id

  attr_protected :id if ActiveRecord::VERSION::MAJOR <= 4
  safe_attributes 'subject', 'type_id', 'content'
  if ActiveRecord::VERSION::MAJOR >= 4
    if ActiveRecord::Base.connection.table_exists?('notes')
      acts_as_activity_provider :type => 'deals',
                                :permission => :view_deals,
                                :author_key => :author_id,
                                :scope => joins(:deal => :project).where(:source_type => 'Deal')
    end
  else
    acts_as_activity_provider :type => 'deals',
                              :permission => :view_deals,
                              :author_key => :author_id,
                              :find_options => { :joins => [:deal => :project],
                                                 :conditions => { :source_type => 'Deal' } }
  end

  scope :visible, lambda {|*args| joins(:deal => :project).
                                  where(Project.allowed_to_condition(args.first || User.current, :view_deals) +
                                                         " AND (#{DealNote.table_name}.source_type = 'Deal')") }
  acts_as_attachable :view_permission => :view_deals,
                     :delete_permission => :edit_deals

  def custom_field_values
    Note.new.custom_field_values
  end
end
