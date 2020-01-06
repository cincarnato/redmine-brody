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

class CreateContactsRelations < Rails.version < '5.1' ? ActiveRecord::Migration : ActiveRecord::Migration[4.2]
  def self.up
    create_table :contacts_deals, :id => false do |t|
      t.integer :deal_id
      t.integer :contact_id
    end
    add_index :contacts_deals, :deal_id
    add_index :contacts_deals, :contact_id

    create_table :contacts_issues, :id => false do |t|
      t.integer :issue_id,   :default => 0, :null => false
      t.integer :contact_id, :default => 0, :null => false
    end
    add_index :contacts_issues, :issue_id
    add_index :contacts_issues, :contact_id

    create_table :contacts_projects, :id => false do |t|
      t.integer :project_id, :default => 0, :null => false
      t.integer :contact_id, :default => 0, :null => false
    end
    add_index :contacts_projects, :project_id
    add_index :contacts_projects, :contact_id

  end

  def self.down
    drop_table :contacts_deals
    drop_table :contacts_issues
    drop_table :contacts_projects
  end
end
