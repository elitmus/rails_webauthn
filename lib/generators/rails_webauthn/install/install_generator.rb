require 'rails/generators'
require 'rails/generators/migration'

module RailsWebauthn
  module Generators
    class InstallGenerator < Rails::Generators::Base
      include Rails::Generators::Migration

      source_root File.expand_path('templates', __dir__)

      # Determine next migration number in a Rails-version-compatible way
      def self.next_migration_number(dirname)
        if Rails::VERSION::MAJOR >= 8
          # Rails 8+ uses timestamped migrations by default
          Time.now.utc.strftime("%Y%m%d%H%M%S")
        else
          # Rails 7 and below
          if ActiveRecord::Base.respond_to?(:timestamped_migrations) && ActiveRecord::Base.timestamped_migrations
            Time.now.utc.strftime("%Y%m%d%H%M%S")
          else
            "%.3d" % (current_migration_number(dirname) + 1)
          end
        end
      end

      # Copy initializer
      def copy_initializer
        template 'rails_webauthn.rb', 'config/initializers/rails_webauthn.rb'
      end

      # Copy migration
      def copy_migration
        migration_template 'create_webauthn_credentials.rb', 'db/migrate/create_webauthn_credentials.rb'
      end

      # Copy JS to app/javascript/javascripts
      def copy_js
        gem_path  = Gem.loaded_specs["rails_webauthn"].full_gem_path
        source_js = File.join(gem_path, "lib/rails_webauthn/javascript/webauthn.js")
        target_js = Rails.root.join("app/javascript/javascripts/rails_webauthn.js")

        if File.exist?(source_js)
          say_status("copying", "rails_webauthn.js → #{target_js}", :green)
          FileUtils.mkdir_p(File.dirname(target_js))
          FileUtils.cp(source_js, target_js)
        else
          say_status("missing", "rails_webauthn.js not found in #{source_js}", :red)
        end
      end
    end
  end
end
