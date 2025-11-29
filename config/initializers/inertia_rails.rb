# frozen_string_literal: true

InertiaRails.configure do |config|
  config.version = ViteRuby.digest
  # Disabled to prevent conflicts with Turbo pages that don't have Inertia history state
  config.encrypt_history = false
  config.always_include_errors_hash = true
end
