require 'net/http'
require 'uri'
require 'nokogiri'
require 'json/ext' # to use the C based extension instead of json/pure

class GetBreakData
  def self.run
    years = (2006..2006).to_a
    uri = URI.parse('https://www.r1concepts.com/home/allMake')
    http_client = Net::HTTP.new(uri.host, uri.port)
    http_client.use_ssl = true
    request = Net::HTTP::Post.new(uri.path)
    request['X-Requested-With'] = 'XMLHttpRequest'

    complete_data = {}
    initialize_hash_keys(complete_data, years)

    years.each do |year|
      request.set_form_data({'year' => year})
      response = http_client.request(request)
      page = Nokogiri::HTML(response.body)
      makes = page.css('li').collect {|make_li| make_li.text}

      initialize_hash_keys(complete_data[year], makes)
      makes.each do |make|
        make_get_uri = URI.parse("https://www.r1concepts.com/home/allModel?make=#{make}&year=#{year}")
        make_get_request = Net::HTTP::Get.new(make_get_uri)
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
          # NOW MAKE THIS CALL: #https://www.r1concepts.com/listing/search/2016/Cadillac/SRX/4.6L_4627CC_V8_GAS_DOHC_Naturally_Aspirated
        end

      end

    end


    puts ("Complete Data #{complete_data.to_json}")
    File.open("./result.json", 'w') { |file| file.write(complete_data.to_json) }
  end

  def self.initialize_hash_keys(resulting_hash, array_of_keys)
    array_of_keys.each do |key|
      resulting_hash[key] = {}
    end
  end
end

GetBreakData.run()