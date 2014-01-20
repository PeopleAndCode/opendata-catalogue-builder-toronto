require "opendata_catalogue_builder/toronto/version"
require "nokogiri"
require "open-uri"
require 'uri'
require "cgi"

module OpendataCatalogueBuilder
  module Toronto
    
    @@base_url ="http://www1.toronto.ca"

    def self.make_list
      first = make_list_xml
      second = make_list_html

      combined = recursive_merge(second, first)
    end

    def self.make_list_xml
      url = "#{@@base_url}/cot-templating/views/rss20view.jsp?vgnextoid=1a66e03bb8d1e310VgnVCM10000071d60f89RCRD&compid=1b4eadba5a72e310VgnVCM10000071d60f89RCRD"
      list = {}
      doc = connect(url, :xml)

      doc.css('item').each do |item|
        title = item.css('title').text
        description = item.css('description').text
        portal_page = item.css('link').text
        guid = item.css('guid').text
        updated = item.css('pubDate').text

        list[guid] = {
          title: title,
          description: description,
          updated: updated,
          portal_page: portal_page
        }
      end

      list
    end

    def self.make_list_html
      url = "#{@@base_url}/wps/portal/contentonly?vgnextoid=1a66e03bb8d1e310VgnVCM10000071d60f89RCRD"
      list = {}
      doc = connect(url)

      doc.css('.alpha .article').each do |item|
        # title = item.css('h4 a').text
        # description = item.css('.description p').text
        portal_page = item.css('h4 a').attr('href').text
        query = URI.parse(portal_page).query
        guid = CGI::parse(query)
        guid = guid["vgnextoid"].first
        format = find_file_formats(item)

        list[guid] = {
          formats: format
        }
      end

      list
    end

    private

    def self.connect(url, type=:html)
      type = type.downcase.to_sym
      if type === :xml
        return Nokogiri::XML(open(url)) do |config|
          config.noblanks
        end
      else
        return Nokogiri::HTML(open(url)) do |config|
          config.noblanks
        end
      end
    end

    def self.find_file_formats(object)
      format = object.css('.format').text.strip.split(", ")
      
      format.each_with_index do |value, key|
        value.strip!
        if value.include?("/")
          format[key] = value.split("/").flatten
        elsif value.include?(" and ")
          format[key] = value.split(" and ")
        elsif value === "CSV File"
          format[key] = value = "CSV"
        elsif value === "XLS File"
          format[key] = value = "XLS"
        end
      end

      format.flatten
    end

    def self.recursive_merge( merge_from, merge_to )
      merged_hash = merge_to.clone
      first_key = merge_from.keys[0]
      if merge_to.has_key?(first_key)
          merged_hash[first_key] = recursive_merge( merge_from[first_key], merge_to[first_key] )
      else
          merged_hash[first_key] = merge_from[first_key]
      end
      merged_hash
    end

  end
end
