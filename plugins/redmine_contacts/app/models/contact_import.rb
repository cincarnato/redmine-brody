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

class ContactImport
  extend ActiveModel::Naming
  include ActiveModel::Conversion
  include ActiveModel::Validations
  include CSVImportable

  attr_accessor :file, :project, :tag_list, :quotes_type

  def klass
    Contact
  end

  def build_from_fcsv_row(row)
    ret = Hash[row.to_hash.collect { |k, v| [k.underscore.tr(' ', '_'), force_utf8(v)] if k }].delete_if { |k, _v| !klass.column_names.include?(k) }
    ret[:birthday] = row['birthday'].to_date if row['birthday']
    ActiveRecord::VERSION::MAJOR >= 4 ? ret[:tag_list] = [row['tags'], tag_list] : ret[:tag_list] = [row['tags'], tag_list].join(',')
    ret[:assigned_to_id] = User.find_by_login(row['responsible']).try(:id) unless row['responsible'].blank?
    unless row['address'].blank? && row['city'].blank? && row['street1'].blank? && row['street2'].blank? && row['region'].blank? && row['postcode'].blank? && row['country_code'].blank?
      ret[:address_attributes] = {}
      ret[:address_attributes][:street1] = row['address'] unless row['address'].blank?
      ret[:address_attributes][:street2] = row['street2'] unless row['street2'].blank?
      ret[:address_attributes][:city] = row['city'] unless row['city'].blank?
      ret[:address_attributes][:postcode] = row['postcode'] unless row['postcode'].blank?
      ret[:address_attributes][:postcode] = row['zip'] unless row['zip'].blank?
      ret[:address_attributes][:region] = row['region'] unless row['region'].blank?
      ret[:address_attributes][:country_code] = row['country code'] unless row['country code'].blank?
      ret[:address_attributes][:country] = row['country'] unless row['country'].blank?
      ret[:address_attributes][:region] = row['state'] unless row['state'].blank? && !row["region"].blank?
    end
    ret
  end
end
