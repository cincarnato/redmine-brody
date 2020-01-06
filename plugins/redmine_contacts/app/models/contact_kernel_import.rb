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

class ContactKernelImport < Import

  def klass
    Contact
  end

  def saved_objects
    object_ids = saved_items.pluck(:obj_id)
    Contact.where(:id => object_ids).order(:id)
  end

  def project=(project)
    settings['project'] = project.id
  end

  def project
    settings['project']
  end

  private

  def build_object(row, _item = nil)
    contact = Contact.new
    contact.project = Project.find(settings['project'])
    contact.author = user

    attributes = {}
    if is_company = row_value(row, 'is_company')
      attributes['is_company'] = '1' if yes?(is_company)
    end
    if first_name = row_value(row, 'first_name')
      attributes['first_name'] = first_name
    end
    if middle_name = row_value(row, 'middle_name')
      attributes['middle_name'] = middle_name
    end
    if last_name = row_value(row, 'last_name')
      attributes['last_name'] = last_name
    end
    if job_title = row_value(row, 'job_title')
      attributes['job_title'] = job_title
    end
    if company = row_value(row, 'company')
      attributes['company'] = company
    end
    if phone = row_value(row, 'phone')
      attributes['phone'] = phone
    end
    if email = row_value(row, 'email')
      attributes['email'] = email
    end

    address_attributes = {}
    if address_street = row_value(row, 'address_street')
      address_attributes['street1'] = address_street
    end
    if address_country_code = row_value(row, 'address_country_code')
      address_attributes['country_code'] = address_country_code
    end
    if address_zip = row_value(row, 'address_zip')
      address_attributes['postcode'] = address_zip
    end
    if address_state = row_value(row, 'address_state')
      address_attributes['region'] = address_state
    end
    if address_city = row_value(row, 'address_city')
      address_attributes['city'] = address_city
    end
    attributes['address_attributes'] = address_attributes

    if skype_name = row_value(row, 'skype_name')
      attributes['skype_name'] = skype_name
    end
    if website = row_value(row, 'website')
      attributes['website'] = website
    end
    if birthday = row_value(row, 'birthday')
      attributes['birthday'] = birthday
    end
    if tag_list = row_value(row, 'tag_list')
      attributes['tag_list'] = tag_list
    end
    if background = row_value(row, 'background')
      attributes['background'] = background
    end

    attributes['custom_field_values'] = contact.custom_field_values.inject({}) do |h, v|
      value = case v.custom_field.field_format
              when 'date'
                row_date(row, "cf_#{v.custom_field.id}")
              when 'list'
                row_value(row, "cf_#{v.custom_field.id}").try(:split, ',')
              else
                row_value(row, "cf_#{v.custom_field.id}")
              end
      if value
        h[v.custom_field.id.to_s] =
          if value.is_a?(Array)
            value.map { |val| v.custom_field.value_from_keyword(val.strip, contact) }.compact.flatten
          else
            v.custom_field.value_from_keyword(value, contact)
          end
      end
      h
    end

    contact.send :safe_attributes=, attributes, user
    contact
  end

end
