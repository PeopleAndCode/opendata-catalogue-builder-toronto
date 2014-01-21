require "opendata_catalogue_builder/toronto/version"
require "nokogiri"
require "open-uri"
require "uri"
require "cgi"
require "mongo"
require "ruby-progressbar"

module OpendataCatalogueBuilder
  module Toronto

    extend self
    include Mongo
    
    @@base_url ="http://www1.toronto.ca"

    def catalogue_list
      @catalogue_list
    end

    def make_list
      first = make_list_xml
      second = make_list_html
      combined = []

      second.each do |guid, values|
        combined.push(first[guid].merge(second[guid]))
      end

      @catalogue_list = combined
    end

    def make_list_html
      url = "#{@@base_url}/wps/portal/contentonly?vgnextoid=1a66e03bb8d1e310VgnVCM10000071d60f89RCRD"
      list = {}
      doc = scrape(url)

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

    def make_list_xml
      url = "#{@@base_url}/cot-templating/views/rss20view.jsp?vgnextoid=1a66e03bb8d1e310VgnVCM10000071d60f89RCRD&compid=1b4eadba5a72e310VgnVCM10000071d60f89RCRD"
      list = {}
      doc = scrape(url, :xml)

      doc.css('item').each do |item|
        title = item.css('title').text
        description = item.css('description').text
        portal_page = item.css('link').text
        guid = item.css('guid').text
        updated = item.css('pubDate').text

        list[guid] = {
          title: title,
          guid: guid,
          description: description,
          portal_page: portal_page,
          updated: updated
        }
      end

      list
    end

    def save_all
      database = database_connect

      progressbar = ProgressBar.create(
        :title => "Uploaded", 
        :total => @catalogue_list.size, 
        :format => '%a %E |%b>>%i| %c of %C / %p%% %t'
      )
      
      system "clear" unless system "cls"

      @catalogue_list.each do |document|
        database.connection.reconnect
        if database.collection('Toronto').update({guid: document["guid"]} , document, {upsert: true})
          progressbar.increment
        else
          return "Error"
        end
      end
    end

    private

    def database_connect
      connection = MongoClient.new(ENV['MONGO_URL'], ENV['MONGO_PORT']).db('opendata_catalogue')
      connection.authenticate(ENV['MONGO_USERNAME'], ENV['MONGO_PASSWORD'])
      connection
    end

    def find_file_formats(object)
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

    def scrape(url, type=:html)
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

  end
end
