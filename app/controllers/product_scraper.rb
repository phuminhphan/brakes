require 'rubygems'
require 'nokogiri'
require 'open-uri'

BASE_URL = "https://www.r1concepts.com/listing/search/"
YEAR = "2016"
MAKE = "Kia"
MODEL = "Sedona"
SUBMODEL = "submodel"
LIST_URL = "#{BASE_URL}/#{YEAR}/#{MAKE}/#{MODEL}/#{SUBMODEL}"

page = Nokogiri::HTML(open(LIST_URL))
product_array = []
product_object = {
    name: '',
    price: '',
    description: ''
}

# #parses each product on the page
# mid = page.css('.listing-bot-single-product').map do |product|
#     #parses middle column 
#     product.css('.listing-bot-mid-holder').map do |a|
#         puts "in a loop"
#         # puts a.css('.listing-name-hd-holder dnone')
#     end
        
#     #parses right column 
#     product.css('.listing-bot-right-holder')
# end

#parses each product on the page
mid = page.css('.listing-bot-mid-holder').map do |product|
    #parses middle column 
    puts "START OF PRODUCT @@@"
    puts product
        
    #parses right column 
    # product.css('.listing-bot-right-holder')
end
