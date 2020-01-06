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

require 'redmine_contacts/patches/compatibility/application_helper_patch'
require 'redmine_contacts/helpers/contacts_helper'
require 'redmine_contacts/helpers/crm_calendar_helper'

# Plugins
require 'acts_as_viewable/init'
require 'acts_as_priceable/init'
require 'contact_custom_field_format'
require 'company_custom_field_format'

require 'redmine_contacts/utils/thumbnail'
require 'redmine_contacts/utils/check_mail'
require 'redmine_contacts/utils/date_utils'
require 'redmine_contacts/utils/csv_utils'
require 'redmine_contacts/contacts_project_setting'

# Patches
require 'redmine_contacts/patches/compatibility/active_record_base_patch'
require 'redmine_contacts/patches/compatibility/active_record_sanitization_patch.rb'
require 'redmine_contacts/patches/compatibility/user_patch.rb'
require 'redmine_contacts/patches/compatibility_patch'
require 'redmine_contacts/patches/issue_patch'
require 'redmine_contacts/patches/project_patch'
require 'redmine_contacts/patches/mailer_patch'
require 'redmine_contacts/patches/notifiable_patch'
require 'redmine_contacts/patches/application_controller_patch'
require 'redmine_contacts/patches/attachments_controller_patch'
require 'redmine_contacts/patches/auto_completes_controller_patch'
require 'redmine_contacts/patches/issue_query_patch'
require 'redmine_contacts/patches/query_patch'
if Redmine::VERSION.to_s >= '3.4' || Redmine::VERSION::BRANCH != 'stable'
  require 'redmine_contacts/patches/query_filter_patch'
  require 'redmine_contacts/patches/issues_helper_patch'
end
require 'redmine_contacts/patches/users_controller_patch'
require 'redmine_contacts/patches/issues_controller_patch'
require 'redmine_contacts/patches/custom_fields_helper_patch'
require 'redmine_contacts/patches/time_report_patch'
require 'redmine_contacts/patches/queries_helper_patch'
require 'redmine_contacts/patches/timelog_helper_patch'
require 'redmine_contacts/patches/projects_helper_patch'

require 'redmine_contacts/wiki_macros/contacts_wiki_macros'

# Hooks
require 'redmine_contacts/hooks/views_projects_hook'
require 'redmine_contacts/hooks/views_issues_hook'
require 'redmine_contacts/hooks/views_layouts_hook'
require 'redmine_contacts/hooks/views_users_hook'
require 'redmine_contacts/hooks/views_custom_fields_hook'
require 'redmine_contacts/hooks/controllers_time_entry_reports_hook'

require 'redmine_contacts/liquid/liquid' if Object.const_defined?("Liquid") rescue false

module RedmineContacts
  def self.companies_select
    RedmineContacts.settings["select_companies_to_deal"]
  end

  def self.settings() Setting[:plugin_redmine_contacts].blank? ? {} : Setting[:plugin_redmine_contacts]  end

  def self.default_list_style
    return (%w(list list_excerpt list_cards) && [RedmineContacts.settings["default_list_style"]]).first || "list_excerpt"
    return 'list_excerpt'
  end

  def self.products_plugin_installed?
    @@products_plugin_installed ||= (Redmine::Plugin.installed?(:redmine_products) && Redmine::Plugin.find(:redmine_products).version >= '2.0.2')
  end

  def self.unstable_branch?
    Redmine::VERSION::BRANCH != 'stable'
  end
end
