RailsWebauthn.configure do |config|
  config.rp_name = 'MyApp'
  config.encoding = :base64url

  case Rails.env
  when 'development'
    config.allowed_origins = ['http://localhost:3000']
    config.rp_id = 'localhost'
  when 'staging'
    config.allowed_origins = ['https://staging.myapp.com']
    config.rp_id = 'staging.myapp.com'
  when 'production'
    config.allowed_origins = ['https://myapp.com']
    config.rp_id = 'myapp.com'
  end
end
