module EbayTrading
  class Configuration

    # https://ebaydts.com/eBayKBDetails?KBid=429
    URI_PRODUCTION = 'https://api.ebay.com/ws/api.dll'
    URI_SANDBOX    = 'https://api.sandbox.ebay.com/ws/api.dll'

    attr_reader :dev_id
    attr_reader :app_id
    attr_reader :cert_id

    # Get the URI for eBay API requests, which will be different for sandbox and production environments.
    attr_reader :uri

    def initialize
      self.environment = :sandbox
      @dev_id = nil
      @environment = :sandbox

      @dev_id  = nil
      @app_id  = nil
      @cert_id = nil
    end

    # Set the eBay environment to either :sandbox or :production
    # @param [Symbol] :sandbox or :production
    def environment=(env)
      @environment = (env.to_s.downcase.strip == 'production') ? :production : :sandbox
      @uri = URI.parse(production? ? URI_PRODUCTION : URI_SANDBOX)
    end

    # Determine if this app is targeting eBay's production environment.
    # @return [Boolean] +true+ if production mode, otherwise +false+.
    def production?
      @environment == :production
    end

    # Determine if this app is targeting eBay's sandbox environment.
    # @return [Boolean] +true+ if sandbox mode, otherwise +false+.
    def sandbox?
      !production?
    end

    # Determine if all application keys have been set.
    # @return [Boolean] +true+ if dev_id, app_id and cert_id have been defined.
    def has_keys_set?
      !(dev_id.nil? || app_id.nil? || cert_id.nil?)
    end

    # Set the Dev ID application key.
    # @param [String] id the developer ID.
    def dev_id=(id)
      raise EbayTradingError, 'Dev ID does not appear to be valid' unless application_key_valid?(id)
      @dev_id = id
    end

    # Set the App ID application key.
    # @param [String] id the app ID.
    def app_id=(id)
      raise EbayTradingError, 'App ID does not appear to be valid' unless application_key_valid?(id)
      @app_id = id
    end

    # Set the Cert ID application key.
    # @param [String] id the certificate ID.
    def cert_id=(id)
      raise EbayTradingError, 'Cert ID does not appear to be valid' unless application_key_valid?(id)
      @cert_id = id
    end


    #---------------------------------------------------------------------------
    private

    # Validate the given DevID, AppID or CertID.
    # These are almost like GUID/UUID values with the exception that the first
    # block of 8 digits of AppID can be any letters.
    # @return [Boolean] true if the
    #
    def application_key_valid?(id)
      id =~ /[A-Z0-9]{8}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{12}/i
    end

  end
end