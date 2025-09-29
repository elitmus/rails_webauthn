require "rails_webauthn/version"
require "rails_webauthn/engine"
require "rails_webauthn/configuration"
require "webauthn"

module RailsWebauthn
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
      setup_webauthn
    end

    private

    def setup_webauthn
      WebAuthn.configure do |config|
        config.rp_name = configuration.rp_name
        config.allowed_origins = configuration.allowed_origins
        config.rp_id = configuration.rp_id
        config.encoding = configuration.encoding || :base64url
      end
    end
  end
end
