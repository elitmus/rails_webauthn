# frozen_string_literal: true

require_relative "lib/rails_webauthn/version"

Gem::Specification.new do |spec|
  spec.name          = "rails_webauthn"
  spec.version       = RailsWebauthn::VERSION
  spec.authors       = ["Smruti Ranjan Badatya"]
  spec.email         = ["smrutiranjanbadatya2@gmail.com"]

  spec.summary       = "WebAuthn / Passkeys integration for Rails applications."
  spec.description   = "rails_webauthn provides a Rails engine, controllers, routes, and helpers for adding WebAuthn / Passkeys (FIDO2) authentication support to your Rails apps."
  spec.homepage      = "https://github.com/elitmus/rails_webauthn"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata = {
    "source_code_uri"=> spec.homepage,
    "changelog_uri"  => "https://github.com/elitmus/rails_webauthn/blob/main/CHANGELOG.md",
    "documentation_uri" => "https://github.com/elitmus/rails_webauthn/README.md"
  }

  # Include all tracked files, excluding development-only files
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore spec/ test/ .rubocop.yml])
    end
  end

  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # === Runtime dependencies ===
  spec.add_dependency "rails", ">= 7.0", "< 9.0"
  spec.add_dependency "webauthn", "~> 3.0" # official ruby-webauthn gem
end
