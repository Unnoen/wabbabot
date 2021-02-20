require 'httparty'
def uri_to_json(uri, query = nil)
  query.nil? ? JSON.parse(HTTParty.get(uri.to_s).body) : JSON.parse(HTTParty.get(uri.to_s, query: query).body)
rescue JSON::ParserError => e
  puts "Could not parse JSON with uri #{uri.to_s} and query #{query} - for more information see exception below."
  false
end

def value_of(array, value)
  !array || array[value].nil? ? nil : array[value]
end


