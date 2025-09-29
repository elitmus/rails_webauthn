module RailsWebauthn
  module WebauthnUser
    extend ActiveSupport::Concern

    included do
      has_many :webauthn_credentials, dependent: :destroy
      before_create :ensure_webauthn_id
    end

    def has_passkeys?
      webauthn_credentials.where(active: true).exists?
    end

    def active_webauthn_credentials
      webauthn_credentials.where(active: true)
    end

    private

      def ensure_webauthn_id
        self.webauthn_id ||= WebAuthn.generate_user_id
      end
  end
end