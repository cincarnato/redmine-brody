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

class ContactsVcfController < ApplicationController
  unloadable

  before_action :find_project_by_project_id, :authorize

  def load
    begin
      vcard = Vcard::Vcard.decode(params[:contact_vcf]).first
      contact = {}
      fill_name(vcard, contact)
      contact[:phone] = vcard.telephones.join(', ')
      contact[:email] = vcard.emails.join(', ')
      contact[:website] = vcard.url.uri if vcard.url
      contact[:birthday] = vcard.birthday
      fill_background(vcard, contact)
      fill_title(vcard, contact)
      fill_address(vcard, contact) if vcard['ADR']
      fill_company(vcard, contact) if vcard.org

      respond_to do |format|
        format.html { redirect_to :controller => 'contacts', :action => 'new', :project_id => @project, :contact => contact }
      end
    rescue Exception => e
      flash[:error] = ERB::Util.html_escape(e.message)
      respond_to do |format|
        format.html { redirect_to :back }
      end
    end
  end

  private

  def fill_name(vcard, contact)
    vcard_charset = get_field_encoding(vcard, 'N')
    contact[:first_name]  = encode(vcard_charset, vcard.name.given)
    contact[:middle_name] = encode(vcard_charset, vcard.name.additional)
    contact[:last_name]   = encode(vcard_charset, vcard.name.family)
  end

  def fill_address(vcard, contact)
    vcard_charset = get_field_encoding(vcard, 'ADR')
    contact[:address_attributes] = {}
    contact[:address_attributes][:street1]  = encode(vcard_charset, vcard.address.street)
    contact[:address_attributes][:city]     = encode(vcard_charset, vcard.address.locality)
    contact[:address_attributes][:postcode] = encode(vcard_charset, vcard.address.postalcode)
    contact[:address_attributes][:region]   = encode(vcard_charset, vcard.address.region)
  end

  def fill_background(vcard, contact)
    vcard_charset = get_field_encoding(vcard, 'NOTE')
    contact[:background] = encode(vcard_charset, vcard.note)
  end

  def fill_company(vcard, contact)
    vcard_charset = get_field_encoding(vcard, 'ORG')
    contact[:company] = encode(vcard_charset, vcard.org.first)
  end

  def fill_title(vcard, contact)
    vcard_charset = get_field_encoding(vcard, 'TITLE')
    contact[:job_title] = encode(vcard_charset, vcard.title)
  end

  def get_field_encoding(vcard, field_name)
    vcard.fields.find { |field| field.name == field_name }.try(:pvalue, 'CHARSET')
  end

  def encode(vcard_charset, field)
    return field if vcard_charset.nil?
    if RUBY_VERSION < '1.9'
      Iconv.conv('UTF-8', vcard_charset, field)
    else
      field.force_encoding(vcard_charset).encode('UTF-8')
    end
  end

end
