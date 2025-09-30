module RailsWebauthn
  class WebauthnCredentialsController < ApplicationController
    respond_to :json

    # ------------------------
    # Hooks & Config
    # ------------------------
    before_action :authenticate_user!, except: %i[check_registered begin_authentication verify_authentication]

    # Apps must implement these methods in their controller
    def find_user_by_email(email)
      raise "Please implement `find_user_by_email` in your app controller"
    end

    def loggedin_user
      raise "Please define `loggedin_user` method in your ApplicationController to use RailsWebauthn"
    end

    # Called after successful authentication
    def after_webauthn_authentication(user)
      set_session_after_webauthn_authentication(user)
      render json: {
        success: true,
        redirect_url: webauthn_redirect_url(user),
        user: {
          id: user.id,
          email: user.email,
          name: user.name
        }
      }
    end

    def webauthn_redirect_url(user)
      raise "Please implement `webauthn_redirect_url(user)` in your app controller"
    end

    def set_session_after_webauthn_authentication(user)
      raise "Please implement `set_session_after_webauthn_authentication(user)` in your app controller"
    end

    # ------------------------
    # Registration Actions
    # ------------------------
    def check_registered
      email = params[:email]
      return render json: { error: 'Email parameter is required' }, status: :bad_request if email.blank?

      user = find_user_by_email(email)
      has_webauthn_credentials = user&.webauthn_credentials&.exists? || false

      render json: {
        registered: user.present?,
        has_passkeys: has_webauthn_credentials,
        allowCredentials: user&.webauthn_credentials&.pluck(:external_id) || [],
        message: has_webauthn_credentials ? 'User has Passkeys' : 'User registered but no Passkeys'
      }
    end

    def begin_registration
      user = loggedin_user
      return render json: { error: 'Authentication required' }, status: :unauthorized unless user

      options = WebAuthn::Credential.options_for_create(
        user: {
          id: user.webauthn_id || generate_webauthn_id(user),
          name: user.email,
          display_name: user.name || user.email
        },
        exclude: user.webauthn_credentials.pluck(:external_id),
        authenticator_selection: {
          authenticator_attachment: 'platform',
          user_verification: 'preferred'
        },
        rp: {
          name: "#{request.host} - #{detect_browser_and_platform}",
          id: request.host
        }
      )

      webauthn_session[:challenge] = options.challenge
      webauthn_session[:user_id] = user.id

      render json: { options: options, message: 'Registration options generated' }
    end

    def verify_registration
      user = loggedin_user || User.find_by(id: webauthn_session[:user_id])
      return render json: { error: 'User not found' }, status: :not_found unless user
      return render json: { error: 'No active registration challenge' }, status: :bad_request unless webauthn_session[:challenge]

      begin
        credential = WebAuthn::Credential.from_create(params[:credential])
        credential.verify(webauthn_session[:challenge])

        user.webauthn_credentials.create!(
          external_id: credential.id,
          public_key: credential.public_key,
          sign_count: credential.sign_count,
          nickname: params[:nickname] || "Passkey #{user.webauthn_credentials.count + 1}"
        )

        user.update!(webauthn_id: generate_webauthn_id(user)) if user.webauthn_id.blank?

        webauthn_session.clear

        render json: { success: true, message: 'Passkey registered successfully', credential_id: credential.id }
      rescue WebAuthn::Error => e
        render json: { error: "Registration failed: #{e.message}" }, status: :unprocessable_entity
      end
    end

    # ------------------------
    # Authentication Actions
    # ------------------------
    def begin_authentication
      email = params[:email]
      return render json: { error: 'Email parameter is required' }, status: :bad_request if email.blank?

      user = find_user_by_email(email)
      return render json: { error: 'No passkeys found for this user' }, status: :not_found unless user&.webauthn_credentials&.exists?

      options = WebAuthn::Credential.options_for_get(
        allow: user.webauthn_credentials.pluck(:external_id),
        user_verification: 'required',
        timeout: 60_000
      )

      webauthn_session[:challenge] = options.challenge
      webauthn_session[:user_email] = email

      render json: { options: options, message: 'Authentication options generated' }
    end

    def verify_authentication
      email = webauthn_session[:user_email]
      user = find_user_by_email(email)
      return render json: { error: 'User not found' }, status: :not_found unless user
      return render json: { error: 'No active authentication challenge' }, status: :bad_request unless webauthn_session[:challenge]

      begin
        credential = WebAuthn::Credential.from_get(params[:credential])
        stored_cred = user.webauthn_credentials.find_by(external_id: credential.id)
        return render json: { error: 'Credential not found' }, status: :not_found unless stored_cred

        credential.verify(
          webauthn_session[:challenge],
          public_key: stored_cred.public_key,
          sign_count: stored_cred.sign_count
        )

        stored_cred.update!(sign_count: credential.sign_count)
        webauthn_session.clear

        after_webauthn_authentication(user)
      rescue WebAuthn::Error => e
        render json: { error: "Authentication failed: #{e.message}" }, status: :unprocessable_entity
      end
    end

    # ------------------------
    # Credential Management
    # ------------------------
    def index
      credentials = loggedin_user.webauthn_credentials.select(:id, :nickname, :created_at)
      render json: { credentials: credentials, count: credentials.size }
    end

    def destroy
      credential = loggedin_user.webauthn_credentials.find(params[:id])
      credential.destroy!
      render json: { success: true, message: 'Passkey removed successfully' }
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Passkey not found' }, status: :not_found
    end

    def update
      credential = loggedin_user.webauthn_credentials.find(params[:id])
      if credential.update(credential_params)
        render json: { success: true, message: 'Passkey updated successfully', credential: credential.slice(:id, :nickname, :created_at) }
      else
        render json: { error: 'Failed to update passkey', errors: credential.errors.full_messages }, status: :unprocessable_entity
      end
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Passkey not found' }, status: :not_found
    end

    # ------------------------
    # Private Helpers
    # ------------------------
    private

    def credential_params
      params.require(:credential).permit(:nickname)
    end

    def generate_webauthn_id(user)
      Base64.urlsafe_encode64(
        Digest::SHA256.digest("#{user.id}-#{user.email}-#{Rails.application.secret_key_base}")
      )
    end

    def detect_browser_and_platform
      ua = request.user_agent.to_s.downcase

      browser = case ua
                when /chrome/ then 'Chrome'
                when /firefox/ then 'Firefox'
                when /safari/ then 'Safari'
                when /edge/ then 'Edge'
                else 'Browser'
                end

      platform = case ua
                 when /macintosh|mac os x/ then 'macOS'
                 when /windows/ then 'Windows'
                 when /linux/ then 'Linux'
                 when /iphone|ipad|ipod/ then 'iOS'
                 when /android/ then 'Android'
                 else 'Unknown'
                 end

      "#{browser} on #{platform}"
    end

    def webauthn_session
      session[:rails_webauthn] ||= {}
    end

    def authenticate_user!
      loggedin_user || raise("Please provide authentication logic in ApplicationController")
    end
  end
end
