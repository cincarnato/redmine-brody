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

module CrmQueriesHelper

  def retrieve_crm_query(object_type)
    query_class = Object.const_get("#{object_type.camelcase}Query")
    query_sym = "#{object_type}_query".to_sym
    if params[:query_id].present?
      cond = 'project_id IS NULL'
      cond << " OR project_id = #{@project.id}" if @project
      @query = query_class.where(cond).find(params[:query_id])
      raise ::Unauthorized unless @query.visible?
      @query.project = @project
      @query.group_by = session[query_sym][:group_by] if session[query_sym] && session[query_sym][:group_by]
      @query.column_names = session[query_sym][:column_names] if session[query_sym] && session[query_sym][:column_names]
      session[query_sym] = { id: @query.id, project_id: @query.project_id }
      sort_clear
    elsif api_request? || params[:set_filter] || session[query_sym].nil? || session[query_sym][:project_id] != (@project ? @project.id : nil)
      # Give it a name, required to be valid
      @query = query_class.new(:name => '_')
      @query.project = @project
      @query.build_from_params(params)
      session[query_sym] = { project_id: @query.project_id, filters: @query.filters, group_by: @query.group_by, column_names: @query.column_names }
    else
      # retrieve from session
      @query = query_class.find(session[query_sym][:id]) if session[query_sym][:id]
      @query ||= query_class.new(name: '_', filters: session[query_sym][:filters], group_by: session[query_sym][:group_by], column_names: session[query_sym][:column_names])
      @query.project = @project
    end
  end

  def retrieve_crm_calendar(options = {})
    if params[:year] and params[:year].to_i > 1900
      @year = params[:year].to_i
      if params[:month] and params[:month].to_i > 0 and params[:month].to_i < 13
        @month = params[:month].to_i
      end
    end
    @year ||= Date.today.year
    @month ||= Date.today.month

    @calendar = RedmineContacts::Helpers::CrmCalendar.new(Date.civil(@year, @month, 1), options)
  end

  def sidebar_crm_queries(query_class)
    unless @sidebar_queries
      @sidebar_queries = query_class.visible.
        where(@project.nil? ? ["project_id IS NULL"] : ["project_id IS NULL OR project_id = ?", @project.id]).
        order("#{query_class.table_name}.name ASC")
    end
    @sidebar_queries
  end

  def crm_query_links(title, queries, object_type)
    # links to #index on contacts/show
    return '' unless queries.any?
    url_params = controller_name == "#{object_type}s" ? { controller: "#{object_type}s", action: 'index', project_id: @project } : {}
    content_tag('h3', title) + "\n" +
      content_tag('ul',
        queries.collect { |query|
            css = 'query'
            css << ' selected' if query == @query
            content_tag('li', link_to(query.name, url_params.merge(query_id: query), class: css))
          }.join("\n").html_safe,
        class: 'queries'
      ) + "\n"
  end

  def render_sidebar_crm_queries(object_type)
    query_class = Object.const_get("#{object_type.camelcase}Query")
    out = ''.html_safe
    out << crm_query_links(l(:label_my_queries), sidebar_crm_queries(query_class).select(&:is_private?), object_type)
    out << crm_query_links(l(:label_query_plural), sidebar_crm_queries(query_class).reject(&:is_private?), object_type)
    out
  end

end
