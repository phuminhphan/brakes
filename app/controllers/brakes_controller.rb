require 'net/http'
require 'uri'
require 'nokogiri'
require 'json/ext' # to use the C based extension instead of json/pure

class BrakesController < ApplicationController

  def index
    @categories = Category.all
  end

  # GET gather_brake_data() year, makes, models, submodels using AJAX calls
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
          initialize_hash_keys(complete_data[year][make][model], submodels)

        end

      end

    end

    #Inserting into the Products table
    complete_data.each do |year, year_hash|
      year_hash.each do |make, make_hash|
        make_hash.each do |model, model_hash|
          model_hash.each do |submodel|
            category = Category.find_or_create_by({year: year, make: make, model: model, submodel: submodel[0]})
            puts ("Inserting: #{category.attributes.inspect}")
          end
        end
      end
    end

    redirect_to root_path
  end

  def brake_products
    @category = Category.find(params[:id])
    @category.model = @category.model.gsub(' ', '_')
    @category.submodel = @category.submodel.gsub(' ', '_')

    product_listing_uri = URI.parse("https://www.r1concepts.com/listing/search/#{@category.year}/#{@category.make}/#{@category.model}/#{@category.submodel}") #Get the makes

    puts "PRODUCT URI:", product_listing_uri

    http_client = Net::HTTP.new(product_listing_uri.host, product_listing_uri.port)
    http_client.use_ssl = true


    make_get_request = Net::HTTP::Get.new(product_listing_uri) # Now for some reason, getting models is a HTTP GET LOL
    response = http_client.request(make_get_request)
    page = Nokogiri::HTML(response.body)

    # subcat:Brake-Shoes
    # prefix:2902
    # rotor_set:0
    # cat:Other-Items
    # brand_id:4
    # rotor_color:
    # counter:1
    # brand:R1-Series
    # year:2016 ---
    # make:Hyunda ---
    # model:Elantra GT ---
    # submodel:Base Hatchbach ---
    # position:AWD
    # padtype:

    get_price_URL = URI.parse("https://www.r1concepts.com/listing/getPrice/")

    http_client = Net::HTTP.new(get_price_URL.host, get_price_URL.port)
    http_client.use_ssl = true

    request = Net::HTTP::Post.new(get_price_URL.path) # For some reason, getting the makes require a HTTP POST
    request['X-Requested-With'] = 'XMLHttpRequest' #Specifies that this is AJAX

    page.css("[id^=single_pro_]").each_with_index do |product_div_container, product_index|
      product_index+=1
      product_title = product_div_container.css("#optcaption#{product_index}").text

      product_description = product_div_container.css("#optdesc#{product_index}").text

      product_div_container.css("ul#opt#{product_index} li > a.subcat_option").each_with_index do |product_variation_li, variation_index|
        rel = product_variation_li['rel']
        accesskey = product_variation_li['accesskey']
        puts ("REL: #{rel}    ACCESSKEY: #{accesskey}")
        cat = product_variation_li.css("#category#{rel}#{accesskey}").first['value']
        subcat = product_variation_li.css("#subcat#{rel}#{accesskey}").first['value']
        prefix = product_variation_li.css("#prefix#{rel}#{accesskey}").first['value']
        rotor_set = product_variation_li.css("#rotor_set#{rel}#{accesskey}").first['value']
        rotor_color = product_variation_li.css("#rotor_color#{rel}#{accesskey}").first['value']
        brand = product_variation_li.css("#brand#{rel}#{accesskey}").first['value']

        brand_id = product_variation_li.css("#brand_id#{rel}#{accesskey}").first['value']
        form_data = {
          subcat: subcat,
          prefix: prefix,
          cat: cat,
          brand_id: brand_id,
          brand: brand,
          rotor_color: rotor_color,
          counter: 1,
          year: @category.year,
          make: @category.make,
          model: @category.model,
          submodel: @category.submodel,
          position: position
        }
        # if product_div_container.css("select#position_select_#{product_index}").length > 0
        #   product_div_container.css("select#position_select_#{product_index} option").each_with_index do |position_select_option, position_index|
        #     position = position_select_option['value']
        #     request.set_form_data(form_data)
        #
        #     response = http_client.request(request)
        #     puts ("@ Response BODY: #{response.body}")
        #   end
        #
        # end

      end
    end

    redirect_to root_path
  end

private

  def initialize_hash_keys(resulting_hash, array_of_keys)
    array_of_keys.each do |key|
      resulting_hash[key] = {}
    end
  end

end
