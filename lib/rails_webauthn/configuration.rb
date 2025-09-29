module RailsWebauthn
  class Configuration
    attr_accessor :rp_name, :rp_id, :allowed_origins, :encoding, :user_model

    DEFAULTS = {
      "development" => { rp_id: "localhost", allowed_origins: ["http://localhost:3000"] },
      "staging"     => { rp_id: "staging.example.com", allowed_origins: ["https://staging.example.com"] },
      "production"  => { rp_id: "example.com", allowed_origins: ["https://example.com"] }
    }.freeze

    def initialize
      env_defaults = DEFAULTS[Rails.env] || DEFAULTS["production"]

      @rp_name = "RailsWebauthn"
      @encoding = :base64url
      @user_model = "User"
      @rp_id = env_defaults[:rp_id]
      @allowed_origins = env_defaults[:allowed_origins]
    end
  end
end
