require 'byebug'                # optional, may be helpful
require 'open-uri'              # allows open('http://...') to return body
require 'cgi'                   # for escaping URIs
require 'nokogiri'              # XML parser
require 'active_model'          # for validations

class OracleOfBacon

  class InvalidError < RuntimeError ; end
  class NetworkError < RuntimeError ; end
  class InvalidKeyError < RuntimeError ; end

  attr_accessor :from, :to
  attr_reader :api_key, :response, :uri
  
  include ActiveModel::Validations
  validates_presence_of :from
  validates_presence_of :to
  validates_presence_of :api_key
  validate :from_does_not_equal_to

  def from_does_not_equal_to
    errors.add(:from, message: "From cannot be the same as To") if @from == @to
  end

  def initialize(api_key= '38b99ce9ec87', from='Kevin Bacon', to='Kevin Bacon')
    @api_key = api_key
    @from = from
    @to = to
    @errors = ActiveModel::Errors.new(self)
  end

  def find_connections
    make_uri_from_arguments
    begin
      xml = URI.parse(uri).read
    rescue Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, EOFError,
      Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError,
      Net::ProtocolError => e 
      raise OracleOfBacon::NetworkError
    end
    OracleOfBacon::Response.new(xml)
  end

  def make_uri_from_arguments
    params = { p: @api_key, a: @from, b: @to }
    query = URI.encode_www_form(params)
    @uri = URI::HTTP.build({host: 'oracleofbacon.org', query: URI.encode_www_form(params)}).to_s
  end
      
  class Response
    attr_reader :type, :data

    def initialize(xml)
      @doc = Nokogiri::XML(xml)
      parse_response
      @type = type
      @data = data
    end

    private

    def parse_response
      if ! @doc.xpath('/error').empty?
        parse_error_response
      elsif ! @doc.xpath('/spellcheck').empty?
        parse_spellcheck_response
      elsif ! @doc.xpath('/link').empty?
        parse_graph_response
      else
        @type = :unknown
        @data = 'Unknown response type'              
      end
    end

    def parse_spellcheck_response
      @type = :spellcheck
      @data = @doc.xpath('//match').collect(&:text)
    end

    def parse_graph_response
      @type = :graph
      actor = @doc.xpath('//actor').collect(&:text)
      movie = @doc.xpath('//movie').collect(&:text)
      @data = actor.zip(movie).flatten.compact
    end

    def parse_error_response
      @type = :error
      @data = 'Unauthorized access'
    end
  end
end

