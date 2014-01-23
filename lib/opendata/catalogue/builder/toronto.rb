require "opendata/catalogue/builder/toronto/version"
require "mongo"
require "nokogiri"
require "open-uri"
require "uri"
require "ruby-progressbar"

module Opendata
  module Catalogue
    module Builder
      module Toronto

        extend self
        include Mongo
        
        @@base_url ="http://www1.toronto.ca"

        attr_reader :catalogue_list, :passed, :failed

        def add_datasets
          make_datasets(@catalogue_list)
          self
        end

        def get_datasets(url)
          dataset = []
          doc = scrape(url)
          links = doc.css('.single-item dd').last.css('li a').to_a ||= []

          if !links.empty?
            links.each do |item|
              title = item.text
              href = URI.encode(item.attr('href'))
              uri = URI.parse(href)

              link = !!uri.host ? "#{item.attr('href')}" : "#{@@base_url}#{href}"

              if link.include?("google.com")
                google_doc = URI.parse(link)
                file_name = google_doc.query
                file_type = google_doc.path.split('/')[1]
                if file_type === "fusiontables"
                  file_type = "Google Fusion Table"

                elsif file_type === "spreadsheet"
                  file_type = "Google Spread Sheet"
                else
                  file_type = "Google Doc"
                end
              else
                file_name = Pathname.new(href).basename.to_s
                file_type = File.extname(file_name)
              end

              dataset.push({
                title: title,
                file: {
                  file_name: file_name,
                  file_type: file_type,
                  link: link
                }
              })
            end
          end

          dataset.empty? ? nil : dataset
        end

        def make_datasets(list)
          @passed = 0
          @failed = {}

          puts "Getting datasets...process may pause briefly..."

          progressbar = progress(list, "Datasets Completed")

          list.each do |(guid, document)|
            progressbar.increment
            dataset = get_datasets(document[:portal_page])

            if dataset
              document[:datasets] = dataset
              @catalogue_list[guid] = document

              @passed += 1
            else
              @failed[guid] = document

            end
          end
          puts "Complete: #{@passed} passed | #{@failed.size} failed."

        end

        def make_list
          @catalogue_list = {}
          first = make_list_xml
          second = make_list_html

          if first && second
            second.each do |guid, values|
              @catalogue_list[guid] = first[guid].merge(second[guid])
            end
          end

          @catalogue_list ? self : nil
        end

        def make_list_html
          url = "#{@@base_url}/wps/portal/contentonly?vgnextoid=1a66e03bb8d1e310VgnVCM10000071d60f89RCRD"
          list = {}
          doc = scrape(url)
          doc = doc.css('.alpha .article').to_a
          
          puts "Scraping HTML..."

          if doc
            progressbar = progress(doc, "Done Scraping HTML")

            doc.each do |item|
              # title = item.css('h4 a').text
              # description = item.css('.description p').text
              portal_page = item.css('h4 a').attr('href').text
              query = URI.parse(portal_page).query
              guid = CGI::parse(query)
              guid = guid["vgnextoid"].first
              format = file_formats(item)

              list[guid] = {
                formats: format
              }

              progressbar.increment
            end
          else
            nil
          end

          puts "Finished scraping HTML.\n\r"

          list
        end

        def make_list_xml

          url = "#{@@base_url}/cot-templating/views/rss20view.jsp?vgnextoid=1a66e03bb8d1e310VgnVCM10000071d60f89RCRD&compid=1b4eadba5a72e310VgnVCM10000071d60f89RCRD"
          list = {}
          doc = scrape(url, :xml)
          doc= doc.css('item').to_a

          puts "Parsing XML..."

          if doc
            progressbar = progress(doc, "Done Parsing XML")

            doc.each do |item|
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

              progressbar.increment
            end
          else
            nil
          end

          puts "Finished parsing XML.\n\r"

          list
        end

        def run
          system "clear" unless system "cls"

          make_list
          add_datasets
          save
        end

        def save
          @saved = 0
          @errors = {}

          database = database_connect

          puts "Saving to database..."

          progressbar = progress(@catalogue_list, "Saved")

          @catalogue_list.each do |(guid, document)|
            database.connection.reconnect
            if database.collection('toronto').update({guid: document[:guid]} , document, {upsert: true})
              progressbar.increment
              @saved += 1
            else
              @errors[guid] = document
              puts "There was a save error."
              next
            end
            database.connection.close
          end

          puts "Completed: #{@saved} saved  | #{@errors.size} errors.\n\r"
          self
        end

        def scrape(url, type=:html, options={})
          attempts = 0
          max_attempts = options[:max_attempts] ||= 2
          connection = nil

          type = type.downcase.to_sym
          
          begin
            if type === :xml
              connection = Nokogiri::XML(open(url)) do |config|
                config.noblanks
              end
            else
              connection = Nokogiri::HTML(open(url)) do |config|
                config.noblanks
              end
            end
          rescue Exception => ex
            attempts += 1
            retry if(attempts < max_attempts)
          end

          connection
        end

        private

        def database_connect
          connection = MongoClient.new(ENV['MONGO_URL'], ENV['MONGO_PORT']).db('opendata_catalogue')
          connection.authenticate(ENV['MONGO_USERNAME'], ENV['MONGO_PASSWORD'])
          connection
        end

        def file_formats(object)
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

        def progress(array, title)
          return ProgressBar.create(
            :title => title, 
            :total => array.size, 
            :format => '%a %E |%b>>%i| %c of %C / %p%% %t',
            :smoothing => 0.6
          )
        end      

      end
    end
  end
end