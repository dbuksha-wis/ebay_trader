require 'net/http'
require 'ox'
require 'rexml/document'
require 'securerandom'
require 'YAML'

require 'ebay_trading'
require 'ebay_trading/helpers/sax_handler'
require 'ebay_trading/helpers/xml_builder'

module EbayTrading

  class Request

    # eBay Trading API XML Namespace
    XMLNS = 'urn:ebay:apis:eBLBaseComponents'

    attr_reader :call_name, :auth_token
    attr_reader :ebay_site_id
    attr_reader :message_id
    attr_reader :xml_tab_width
    attr_reader :xml_request
    attr_reader :xml_response
    attr_reader :http_timeout
    attr_reader :http_response_code

    # Construct a new eBay Trading API call.
    # @param [String] call_name the name of the API call, for example 'GeteBayOfficialTime'.
    # @param [String] auth_token the eBay Auth Token for the user submitting this request.
    # @param [Hash] args optional configuration values for this request.
    # @option args [Fixnum] :ebay_site_id Override the default eBay site ID in {Configuration#ebay_site_id}
    # @option args [String] :response_xml Provide the actual XML response here
    #                       if a locally cached response is to be interpreted,
    #                       rather than submitting the request to eBay API.
    # @option args [Fixnum] :http_timeout Override the default value of {Configuration#http_timeout}.
    #                       This may be necessary for one-off calls such as UploadSiteHostedPictures
    #                       which can take 60 seconds or more.
    # @option args [Fixnum] :xml_tab_width the number of spaces to indent child elements in the generated XML.
    #                       The default is 0, meaning the XML is a single line string, but it's
    #                       nice to have the option of pretty-printing the XML for debugging.
    # @raise [RequestError] if the API call fails.
    #
    def initialize(call_name, auth_token, args = {}, &block)
      @call_name  = call_name.freeze
      @auth_token = auth_token.freeze

      @ebay_site_id = (args[:ebay_site_id] || EbayTrading.configuration.ebay_site_id).to_i
      @http_timeout = (args[:http_timeout] || EbayTrading.configuration.http_timeout).to_f
      @xml_tab_width = (args[:xml_tab_width] || 0).to_i

      @xml_response = ''

      @message_id = nil
      if args.key?(:message_id)
        @message_id = (args[:message_id] == true) ? SecureRandom.uuid : args[:message_id].to_s
      end

      @xml_request = '<?xml version="1.0" encoding="utf-8"?>' << "\n"
      @xml_request << XMLBuilder.new(tab_width: xml_tab_width).root("#{call_name}Request", xmlns: XMLNS) do
        RequesterCredentials do
          eBayAuthToken auth_token.to_s
        end
        instance_eval(&block) if block_given?
        MessageID message_id unless message_id.nil?
      end

      post

      parse(to_s)
    end

    # Post the xml_request to eBay and record the xml_response.
    def post
      raise EbayTradingError, 'Cannot post an eBay API request before application keys have been set' unless EbayTrading.configuration.has_keys_set?

      uri = EbayTrading.configuration.uri

      http = Net::HTTP.new(uri.host, uri.port)
      http.read_timeout = http_timeout

      if uri.port == 443
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end

      post = Net::HTTP::Post.new(uri.path, headers)
      post.body = xml_request

      begin
        response = http.start { |http| http.request(post) }
      rescue Net::ReadTimeout
        raise EbayTradingTimeoutError, "Failed to complete #{call_name} in #{http_timeout} seconds"
      end

      @http_response_code = response.code.freeze

      # If the call was successful it should have a response code starting with '2'
      # http://www.w3.org/Protocols/rfc2616/rfc2616-sec10.html
      raise EbayTradingError, "HTTP Response Code: #{http_response_code}" if http_response_code[0] != '2'

      @xml_response = response.body
    end

    # Get a String representation of the response XML with indentation.
    # @return [String] the response XML.
    def to_s(indent = xml_tab_width)
      xml = ''
      if defined? Ox
        ox_doc = Ox.parse(xml_response)
        xml = Ox.dump(ox_doc, indent: indent)
      else
        rexml_doc = REXML::Document.new(xml_response)
        rexml_doc.write(xml, indent)
      end
      xml
    end


    #-------------------------------------------------------------------------
    private

    #
    # Get a hash of the default headers to be submitted to eBay API via httparty.
    # Additional headers can be merged into this hash as follows:
    # ebay_headers.merge({'X-EBAY-API-CALL-NAME' => 'CallName'})
    # http://developer.ebay.com/Devzone/XML/docs/WebHelp/InvokingWebServices-Routing_the_Request_(Gateway_URLs).html
    #
    def headers
      headers = {
          'X-EBAY-API-COMPATIBILITY-LEVEL' => "#{EbayTrading.configuration.ebay_api_version}",
          'X-EBAY-API-SITEID' => "#{ebay_site_id}",
          'X-EBAY-API-CALL-NAME' => call_name,
          'Content-Type' => 'text/xml'
      }
      xml = xml_request
      headers.merge!({'Content-Length' => "#{xml.length}"}) if xml && !xml.strip.empty?

      # These values are only required for calls that set up and retrieve a user's authentication token
      # (these calls are: GetSessionID, FetchToken, GetTokenStatus, and RevokeToken).
      # In all other calls, these value are ignored..
      if %w"GetSessionID FetchToken GetTokenStatus RevokeToken".include?(call_name)
        headers.merge!({'X-EBAY-API-DEV-NAME'  => EbayTrading.configuration.dev_id})
        headers.merge!({'X-EBAY-API-APP-NAME'  => EbayTrading.configuration.app_id})
        headers.merge!({'X-EBAY-API-CERT-NAME' => EbayTrading.configuration.cert_id})
      end
      headers
    end

    def parse(xml)
      xml ||= ''
      xml = StringIO.new(xml) unless xml.respond_to?(:read)

      handler = SaxHandler.new
      Ox.sax_parse(handler, xml, convert_special: true)
      hash = handler.to_hash

      require 'JSON'
      puts JSON.pretty_generate(JSON.parse(hash.to_json))
    end
  end
end
