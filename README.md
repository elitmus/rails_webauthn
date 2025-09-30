# rails_webauthn

This Gem makes it easy to implement passkeys in Rails applications. Under the hood, it uses `webauthn` under the hood on the server-side. And it uses browser API's for implementing the client side of the passkey implementation. 

To use this gem in an application, we need to follow these steps:

Install the gem, by adding it in the Gemfile
```bash
gem 'rails_webauthn'
```

Then we need to run the install command to generate some necessary migrations and copy the JS utils files.
```bash
rails generate rails_webauthn:install
```

This will generate:
1. a migration for model `webauthn_credentials`.
2. a JS Util file `webauthn.js` under app/javascript/javascripts
3. an initializer file `rails_webauthn.rb` inside config/initializers

---

Then we will need to override some methods in the `webauthn_credentials_controller` class, to have application specific logic.

```ruby
module Api
  module V1
    module Webauthn
      class WebauthnCredentialsController < RailsWebauthn::WebauthnCredentialsController
        private
          def find_user_by_email(email)
            User.find_by(email: email)
          end

          def loggedin_user
            current_user
          end

          def webauthn_redirect_url(user)
            "users/#{user.id}/dashboard"
          end

          def set_session_after_webauthn_authentication(user)
            set_session(user)
          end
      end
    end
  end
end
```

we will need these methods required, to make app specific modification to the logic. 

---

We need to add the routes in `routes.rb` file

```ruby
namespace :webauthn do
    post   'check_registered',      to: 'webauthn_credentials#check_registered'
    post   'begin_registration',    to: 'webauthn_credentials#begin_registration'
    post   'verify_registration',   to: 'webauthn_credentials#verify_registration'
    post   'begin_authentication',  to: 'webauthn_credentials#begin_authentication'
    post   'verify_authentication', to: 'webauthn_credentials#verify_authentication'
    get    'credentials',           to: 'webauthn_credentials#index'
    patch  'credentials/:id',       to: 'webauthn_credentials#update'
    delete 'credentials/:id',       to: 'webauthn_credentials#destroy'
end
```

---

We need to add the following migration

```ruby
class AddWebauthnIdToUsers < ActiveRecord::Migration[8.0]
  def change
    unless column_exists?(:users, :webauthn_id)
      add_column :users, :webauthn_id, :string
      add_index  :users, :webauthn_id, unique: true
    end
  end
end
```

---

In the initializer, we have to make some changes

```ruby
RailsWebauthn.configure do |config|
  config.rp_name = 'eLitmus'
  config.user_model = 'User'
  config.encoding = :base64url

  case Rails.env
  when 'development'
    config.allowed_origins = ['http://localhost:5000']
    config.rp_id = 'localhost'
  when 'staging'
    config.allowed_origins = ['https://elitmus.myapp.com']
    config.rp_id = 'staging.elitmus.com'
  when 'production'
    config.allowed_origins = ['https://myapp.com']
    config.rp_id = 'elitmus.com'
  end
end
```

---

In the User model, we have to add

```ruby
include RailsWebauthn::WebauthnUser
```

--- 

Then we can run the migration

```bash
bin/rails db:migrate
```