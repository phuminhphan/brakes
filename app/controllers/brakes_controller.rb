require 'net/http'
require 'uri'
require 'nokogiri'
require 'json/ext' # to use the C based extension instead of json/pure

class BrakesController < ApplicationController

  def index
    @products = Product.all
  end

  # GET gather_brake_data()
  def gather_brake_data
    years = (2016..2016).to_a #1 year only for now
    uri = URI.parse('https://www.r1concepts.com/home/allMake') #Get the makes

    http_client = Net::HTTP.new(uri.host, uri.port)
    http_client.use_ssl = true

    request = Net::HTTP::Post.new(uri.path) # For some reason, getting the makes require a HTTP POST
    request['X-Requested-With'] = 'XMLHttpRequest' #Specifies that this is AJAX

    complete_data = {}
    initialize_hash_keys(complete_data, years)

    years.each do |year|
      request.set_form_data({'year' => year})
      response = http_client.request(request)
      page = Nokogiri::HTML(response.body)  # Read up on Nokogiri, it basically takes a string and turns into a virtual DOM
      makes = page.css('li').collect {|make_li| make_li.text} # With nokogiri, we can get the HTTP Response, turn it into a DOM, and run CSS3 selectors!

      initialize_hash_keys(complete_data[year], makes) #makes becomes the keys in the hash of complete_data
      makes.each do |make|
        make_get_uri = URI.parse("https://www.r1concepts.com/home/allModel?make=#{make}&year=#{year}")
        make_get_request = Net::HTTP::Get.new(make_get_uri) # Now for some reason, getting models is a HTTP GET LOL
        response = http_client.request(make_get_request)
        page = Nokogiri::HTML(response.body)

        models = page.css('li').collect {|model_li| model_li.text}

        initialize_hash_keys(complete_data[year][make], models)

        models.each do |model|
          submodel_get_uri = URI.parse("https://www.r1concepts.com/home/allSubmodel?make=#{make}&year=#{year}&model=#{model}")
          submodel_get_request = Net::HTTP::Get.new(submodel_get_uri)
          puts ("Requesting #{year} - #{make} - #{model}")
          response = http_client.request(submodel_get_request)
          page = Nokogiri::HTML(response.body)
          submodels = page.css('li').collect {|submodel_li| submodel_li.text}
          submodels.delete("All")
          initialize_hash_keys(complete_data[year][make][model], submodels)
          
          # NOW MAKE THIS CALL: #https://www.r1concepts.com/listing/search/2016/Cadillac/SRX/4.6L_4627CC_V8_GAS_DOHC_Naturally_Aspirated
          # This call should get the products and go on from there.  Please take a look at db/migrate/create_products migration to see the attribute to fill in
        end

      end

    end

    puts "@@@@@@@@@@@@@@@@complete_data now", JSON.pretty_generate(complete_data)

    #Inserting into the Products table
    complete_data.each do |year, year_hash|
      year_hash.each do |make, make_hash|
        make_hash.each do |model, model_hash|
          model_hash.each do |submodel|
            Product.find_or_create_by({year: year, make: make, model: model, submodel: submodel[0], product_name: "n/a"})
            # for now add row to database but later we check if db has row already? if it does, don't do http request to server at all

            

        #etc... You may need to double check the looping through of Hashes
        # All the way in, please insert into Products table
        # Product.create({year: year, make: make, model: model, submodel: submodel})
        # notice the other attributes aren't filled in... It's ok.  We can query those later but AS LONG AS WE HAVE THE PERMUTATIONS IN THE database
        # WE CAN literally make another method called "fetch_product_types_and_prices" to further update the record with description, product_name, price, category, position (rear or front) etc...
            
          end
        end
      end
    end

  end

  def fetch_product_types_and_prices
  end

private

  def initialize_hash_keys(resulting_hash, array_of_keys)
    array_of_keys.each do |key|
      resulting_hash[key] = {}
    end
  end

end
