module RailsWebauthn
  class WebauthnCredential < ApplicationRecord
    belongs_to :user, class_name: RailsWebauthn.configuration.user_model

    validates :external_id, presence: true, uniqueness: true
    validates :public_key, presence: true
    validates :nickname, presence: true

    def public_key_binary
      public_key
    end
  end
end