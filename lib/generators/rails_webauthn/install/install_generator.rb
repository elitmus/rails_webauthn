require 'rails/generators'
require 'rails/generators/migration'

module RailsWebauthn
  module Generators
    class InstallGenerator < Rails::Generators::Base
      include Rails::Generators::Migration

      source_root File.expand_path('templates', __dir__)

      # This is needed for migration generation
      def self.next_migration_number(dirname)
        if ActiveRecord::Base.timestamped_migrations
          Time.now.utc.strftime("%Y%m%d%H%M%S")
        else
          "%.3d" % (current_migration_number(dirname) + 1)
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

      def copy_js
        say_status("copying", "rails_webauthn.js to app/assets/javascripts", :green)

        gem_path = Gem.loaded_specs["rails_webauthn"].full_gem_path
        source_js = File.join(gem_path, "lib/rails_webauthn/javascript/webauthn.js")
        target_js = Rails.root.join("app/assets/javascripts/rails_webauthn.js")

        FileUtils.mkdir_p(File.dirname(target_js))
        FileUtils.cp(source_js, target_js)
      end
    end
  end
end
