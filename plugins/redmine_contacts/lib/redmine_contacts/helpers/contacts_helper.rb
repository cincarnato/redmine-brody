# encoding: utf-8
#
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
  module Helper
    def contact_tag_url(tag_name, options = {})
      { :controller => 'contacts',
        :action => 'index',
        :set_filter => 1,
        :project_id => @project,
        :fields => [:tags],
        :values => { :tags => [tag_name] },
        :operators => { :tags => '=' } }.merge(options)
    end

    def skype_to(skype_name, _name = nil)
      return link_to skype_name, 'skype:' + skype_name + '?call' unless skype_name.blank?
    end

    def tag_link(tag_name, options = {})
      style = ContactsSetting.monochrome_tags? ? { :class => 'tag-label' } : { :class => 'tag-label-color', :style => "background-color: #{tag_color(tag_name)}" }
      tag_count = options.delete(:count)
      link = link_to tag_name, contact_tag_url(tag_name), options
      link += content_tag(:span, "(#{tag_count})", :class => 'tag-count') if tag_count
      content_tag(:span, link, {}.merge(style))
    end

    def tag_color(tag_name)
      "##{'%06x' % (tag_name.unpack('H*').first.hex % 0xffffff)}"
      # "##{"%06x" % (Digest::MD5.hexdigest(tag_name).hex % 0xffffff)}"
      # "##{"%06x" % (tag_name.hash % 0xffffff).to_s}"
    end

    def tag_links(tag_list, options = {})
      content_tag(:span, safe_join(tag_list.map { |tag| tag_link(tag, options) }, ContactsSetting.monochrome_tags? ? ', ' : ' ').html_safe,
                         :class => "tag_list#{' icon icon-tag' if ContactsSetting.monochrome_tags?}") if tag_list
    end

    def link_to_remote_list_update(text, url_params)
      link_to_remote(text, { :url => url_params, :method => :get, :update => 'contact_list', :complete => 'window.scrollTo(0,0)' },
                           { :href => url_for(:params => url_params) }
      )
    end

    def contacts_check_box_tags(name, contacts)
      s = ''
      contacts.each do |contact|
        s << "<label>#{ check_box_tag name, contact.id, false, :id => nil } #{contact_tag(contact, :no_link => true)}#{' (' + contact.company + ')' unless contact.company.blank? || contact.is_company? }</label>\n"
      end
      s.html_safe
    end

    def note_source_url(note_source, options = {})
      polymorphic_path(note_source, options.merge(:project_id => @project))
      # return {:controller => note_source.class.name.pluralize.downcase, :action => 'show', :project_id => @project, :id => note_source.id }
    end

    def link_to_source(note_source, options = {})
      link_to note_source.name, note_source_url(note_source, options)
    end

    def countries_options_for_select(selected = nil)
      default_country = l(:label_crm_countries)[ContactsSetting.default_country.to_s.upcase.to_sym] if ContactsSetting.default_country
      countries = countries_for_select
      countries = [[default_country, ContactsSetting.default_country.to_s.upcase], ['---', '']] | countries if default_country
      options_for_select(countries, :disabled => '', :selected => selected)
    end

    def countries_for_select
      l(:label_crm_countries).map { |k, v| [v, k.to_s] }.sort
    end

    def select_contact_tag(name, contact, options = {})
      cross_project_contacts = ContactsSetting.cross_project_contacts? || !!options.delete(:cross_project_contacts)

      s = select2_tag(
        name,
        options_for_select([[contact.try(:name_with_company), contact.try(:id)]], contact.try(:id)),
        url: auto_complete_contacts_path(project_id: (cross_project_contacts ? nil : @project), is_company: (options[:is_company] ? '1' : nil), multiaddress: options[:multiaddress]),
        placeholder: '',
        style: 'width: 60%;',
        include_blank: true,
        format_state: (options[:multiaddress] ? 'formatStateWithMultiaddress' : 'formatStateWithAvatar'),
        allow_clear: !!options[:include_blank]
      )

      if options[:add_contact] && @project.persisted?
        if authorize_for('contacts', 'new')
          s << link_to(
            image_tag('add.png', style: 'vertical-align: middle; margin-left: 5px;'),
            new_project_contact_path(@project, contact_field_name: name, contacts_is_company: !!options[:is_company]),
            remote: true,
            method: 'get',
            title: l(:label_crm_contact_new),
            id: "#{sanitize_to_id(name)}_add_link",
            tabindex: 200
          )
        end

        s << javascript_include_tag('attachments')
      end

      s.html_safe
    end

    # TODO: Need to add tests for this method (avatar_to).
    def avatar_to(obj, options = {})
      # "https://avt.appsmail.ru/mail/sin23matvey/_avatar"

      options[:size] ||= '64'
      if ActiveRecord::VERSION::MAJOR >= 4
        unless options[:size].to_s.include?('x')
          options[:size] = "#{options[:size]}x#{options[:size]}"
        end
      else
        options[:width] ||= options[:size]
        options[:height] ||= options[:size]
      end

      options[:class] = options[:class].to_s + ' gravatar'

      obj_icon = obj.is_a?(Contact) ? (obj.is_company ? 'company.png' : 'person.png') : (obj.is_a?(Deal) ? 'deal.png' : 'unknown.png')

      return image_tag(obj_icon, options.merge(:plugin => 'redmine_contacts')) if ENV['NO_AVATAR']

      if obj.is_a?(Deal)
        if obj.contact
          avatar_to(obj.contact, options)
        else
          image_tag(obj_icon, options.merge(:plugin => 'redmine_contacts'))
        end
      elsif obj.is_a?(Contact) && (avatar = obj.avatar) && avatar.readable?
        avatar_url = url_for :controller => 'attachments', :action => 'contacts_thumbnail', :id => avatar, :size => options[:size]
        if options[:full_size]
          link_to(image_tag(avatar_url, options), :controller => 'attachments', :action => 'show', :id => avatar, :filename => avatar.filename)
        else
          image_tag(avatar_url, options)
        end
      elsif obj.respond_to?(:facebook) && !obj.facebook.blank?
        image_tag("https://graph.facebook.com/#{obj.facebook.gsub('.*facebook.com\/', '')}/picture?type=square#{'&return_ssl_resources=1' if (request && request.ssl?)}", options)
      elsif Setting.gravatar_enabled? && obj.is_a?(Contact) && obj.primary_email
        # options.merge!({:ssl => (request && request.ssl?), :default => "#{request.protocol}#{request.host_with_port}/plugin_assets/redmine_contacts/images/#{obj_icon}"})
        # gravatar(obj.primary_email.downcase, options) rescue image_tag(obj_icon, options.merge({:plugin => "redmine_contacts"}))
        avatar("<#{obj.primary_email}>", options)
      else
        image_tag(obj_icon, options.merge(:plugin => 'redmine_contacts'))
      end
    end

    def contact_tag(contact, options={})
      avatar_size = options.delete(:size) || 16
      if contact.visible? && !options[:no_link]
        contact_avatar = link_to(avatar_to(contact, :size => avatar_size), contact_path(contact, :project_id => @project), :id => "avatar")
        contact_name = link_to_source(contact, :project_id => @project)
      else
        contact_avatar = avatar_to(contact, :size => avatar_size)
        contact_name = contact.name
      end

      case options.delete(:type).to_s
      when 'avatar'
        contact_avatar.html_safe
      when 'plain'
        contact_name.html_safe
      else
        content_tag(:span, "#{contact_avatar} #{contact_name}".html_safe, :class => 'contact')
      end
    end

    def render_contact_tooltip(contact, options = {})
      @cached_label_crm_company ||= l(:field_contact_company)
      @cached_label_job_title = contact.is_company ? l(:field_company_field) : l(:field_contact_job_title)
      @cached_label_phone ||= l(:field_contact_phone)
      @cached_label_email ||= l(:field_contact_email)

      emails = contact.emails.any? ? contact.emails.map { |email| "<span class=\"email\" style=\"white-space: nowrap;\">#{mail_to email}</span>" }.join(', ') : ''
      phones = contact.phones.any? ? contact.phones.map { |phone| "<span class=\"phone\" style=\"white-space: nowrap;\">#{phone}</span>" }.join(', ') : ''

      s = link_to_contact(contact, options) + '<br /><br />'.html_safe
      s <<  "<strong>#{@cached_label_job_title}</strong>: #{contact.job_title}<br />".html_safe unless contact.job_title.blank?
      s <<  "<strong>#{@cached_label_crm_company}</strong>: #{link_to(contact.contact_company.name, { :controller => 'contacts', :action => 'show', :id => contact.contact_company.id })}<br />".html_safe if !contact.contact_company.blank? && !contact.is_company
      s <<  "<strong>#{@cached_label_email}</strong>: #{emails}<br />".html_safe if contact.emails.any?
      s <<  "<strong>#{@cached_label_phone}</strong>: #{phones}<br />".html_safe if contact.phones.any?
      s
    end

    def link_to_contact(contact, options = {})
      s = ''
      html_options = {}
      html_options = { :class => 'icon icon-vcard' } if options[:icon] == true
      s << avatar_to(contact, :size => '16') if options[:avatar] == true
      s << link_to_source(contact, html_options)

      s << "(#{contact.job_title}) " if (options[:job_title] == true) && !contact.job_title.blank?
      s << " #{l(:label_crm_at_company)} " if (options[:job_title] == true) && !(contact.job_title.blank? || contact.company.blank?)
      if (options[:company] == true) && contact.contact_company
        s << link_to(contact.contact_company.name, { :controller => 'contacts', :action => 'show', :id => contact.contact_company.id })
      else
        h contact.company
      end
      s << "(#{l(:field_contact_tag_names)}: #{contact.tag_list.join(', ')}) " if (options[:tag_list] == true) && !contact.tag_list.blank?
      s.html_safe
    end

    def note_type_icon(note)
      note_type_tag = ''
      case note.type_id
      when 0
        note_type_tag = content_tag('span', '', :class => 'icon icon-email', :title => l(:label_crm_note_type_email))
      when 1
        note_type_tag = content_tag('span', '', :class => 'icon icon-call', :title => l(:label_crm_note_type_call))
      when 2
        note_type_tag = content_tag('span', '', :class => 'icon icon-meeting', :title => l(:label_crm_note_type_meeting))
      end
      context = { :type_tag => note_type_tag, :type_id => note.type_id }
      call_hook(:helper_notes_note_type_tag, context)
      context[:type_tag].html_safe
    end
    def deal_tag(deal, options = {})
      return deal.name unless deal.visible?
      deal_name = options[:no_contact] ? deal.name : deal.full_name
      s = ''
      s << avatar_to(deal, :size => options.delete(:size) || 16) unless options[:plain]
      s << ' ' + link_to(deal_name, deal_path(deal))
      s << " (#{deal.price_to_s}) " unless deal.price.blank? || options[:no_price]
      s << (options[:plain] ? deal.status.name : deal_status_tag(deal.status)) if deal.status
      s.html_safe
    end

    def deal_status_tag(deal_status)
      status_tag = content_tag(:span, deal_status.name)
      content_tag(:span, status_tag, :class => 'tag-label-color', :style => "background-color:#{deal_status.color_name};color:white;")
    end
  end
end

ActionView::Base.send :include, RedmineContacts::Helper
