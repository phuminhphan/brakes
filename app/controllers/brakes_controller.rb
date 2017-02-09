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
          #submodels["All"] = "submodel"      ???
          initialize_hash_keys(complete_data[year][make][model], submodels)

          # NOW MAKE THIS CALL: #https://www.r1concepts.com/listing/search/2016/Cadillac/SRX/4.6L_4627CC_V8_GAS_DOHC_Naturally_Aspirated
          # This call should get the products and go on from there.  Please take a look at db/migrate/create_products migration to see the attribute to fill in
        end

      end

    end

    #puts "@@@@@@@@@@@@@@@@complete_data now", JSON.pretty_generate(complete_data)

    #Inserting into the Products table
    complete_data.each do |year, year_hash|
      year_hash.each do |make, make_hash|
        make_hash.each do |model, model_hash|
          model_hash.each do |submodel|
            product = Product.find_or_create_by({year: year, make: make, model: model, submodel: submodel[0], product_name: "n/a"})
            puts ("Inserting: #{product.attributes.inspect}")
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

    redirect_to root_path
  end

  def brake_products
    @product = Product.find(params[:id])
    @product.model = @product.model.gsub(' ', '_')
    @product.submodel = @product.submodel.gsub(' ', '_')

    product_listing_uri = URI.parse("https://www.r1concepts.com/listing/search/#{@product.year}/#{@product.make}/#{@product.model}/#{@product.submodel}") #Get the makes

    puts "PRODUCT URI:", product_listing_uri

    http_client = Net::HTTP.new(product_listing_uri.host, product_listing_uri.port)
    http_client.use_ssl = true

    complete_data = {}

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
    page.css("[id^=single_pro_]").each_with_index do |product_div_container, product_index|
      product_index+=1
      product_title = product_div_container.css("#optcaption#{product_index}").text
      puts ("Product Title #{product_index}: #{product_title}")

      product_description = product_div_container.css("#optdesc#{product_index}").text

      puts ("Product Description #{product_index}: #{product_description}")

      product_div_container.css("ul#opt#{product_index} li > a.subcat_option").each_with_index do |product_variation_li, variation_index|
        rel = product_variation_li['rel']
        accesskey = product_variation_li['accesskey']
        puts ("REL: #{rel}    ACCESSKEY: #{accesskey}")
        cat = product_variation_li.css("#category#{rel}#{accesskey}").first['value']
        puts "CAT:", cat, "------------"
        subcat = product_variation_li.css("#subcat#{rel}#{accesskey}").first['value']
        puts "SUBCAT:", subcat, "------------"
        prefix = product_variation_li.css("#prefix#{rel}#{accesskey}").first['value']
        puts "PREFIX:", prefix, "------------"
        rotorSet = product_variation_li.css("#rotor_set#{rel}#{accesskey}").first['value']
        puts "rotorSet:", rotorSet, "------------"
        rotorColor = product_variation_li.css("#rotor_color#{rel}#{accesskey}").first['value']
        puts "rotorColor:", rotorColor, "------------"
        brand = product_variation_li.css("#brand#{rel}#{accesskey}").first['value']
        puts "brand:", brand, "------------"
        brandId = product_variation_li.css("#brand_id#{rel}#{accesskey}").first['value']
        puts "brandId:", brandId, "------------"
        # counter = product_variation_li.css("#counter#{rel}#{accesskey}").first['value']
        # puts "counter:", counter, "------------"
        # position = product_variation_li.css("#position#{rel}#{accesskey}").first['value']
        # puts "position:", position, "------------"
        
    # Call to get price
    # https://www.r1concepts.com/listing/getPrice/
    # subcat=OEM-Rotors-Kits&prefix=FEB&rotor_set=2&cat=Brake-Kits&brand_id=2&rotor_color=1&counter=1&brand=eLINE-Series&year=2016&make=Hyundai&model=Elantra_GT&submodel=Base_Hatchback_4-Door&position=Front&padtype=
        get_price_URL = product_listing_uri = URI.parse("https://www.r1concepts.com/listing/getPrice/")

        puts "GET PRICE URI:", get_price_URL

        http_client = Net::HTTP.new(get_price_URL.host, get_price_URL.port)
        http_client.use_ssl = true

        request = Net::HTTP::Post.new(get_price_URL.path) # For some reason, getting the makes require a HTTP POST
        request['X-Requested-With'] = 'XMLHttpRequest' #Specifies that this is AJAX

        request.set_form_data({'subcat' => subcat, 'prefix' => prefix, 'cat' => cat, 'brand_id' => brandId, 'brand' => brand, 'rotor_color' => rotorColor, 'counter' => 1, 'year' => @product.year, 'make' => @product.make, 'model' => @product.model, 'submodel' => @product.submodel, 'position'=> 'Front'})
  
        response = http_client.request(request)
        puts "+++++++++++++++++++++++++++++++++++++++++++++++++++"
        puts "response:",response.body #currently prints out net:http node hoding response form AJAX call
    # ########################################################################

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
