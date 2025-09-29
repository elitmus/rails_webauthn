require 'rails/engine'

module RailsWebauthn
  class Engine < ::Rails::Engine
    isolate_namespace RailsWebauthn

    config.autoload_paths << root.join('lib')
    config.eager_load_paths << root.join('lib')

    config.generators do |g|
      g.test_framework :rspec
    end

    initializer "rails_webauthn.assets" do |app|
      app.config.assets.precompile += %w[rails_webauthn.js]
    end
  end
end
