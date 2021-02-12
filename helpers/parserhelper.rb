require 'json'
require 'typhoeus'

def value_of(array, value)
  !array || array[value].nil? ? nil : array[value]
end

def uri_to_json(uri, query = nil)
  query.nil? ? JSON.parse(Typhoeus::Request.new(uri.to_s, followlocation: true, ssl_verifypeer: false).run.body) : JSON.parse(Typhoeus::Request.new(uri.to_s, params: query, followlocation: true, ssl_verifypeer: false).run.body)
rescue JSON::ParserError => e
  puts e
  false
end
