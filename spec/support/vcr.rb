# frozen_string_literal: true

require 'vcr'

# VCR Configuration for HTTP recording and mocking
VCR.configure do |config|
  config.cassette_library_dir = 'spec/vcr_cassettes'
  config.hook_into :webmock
  config.configure_rspec_metadata!
  config.allow_http_connections_when_no_cassette = false

  # Filter sensitive data from cassettes
  config.filter_sensitive_data('<LINEAR_API_TOKEN>') { ENV.fetch('LINEAR_API_TOKEN', nil) }
  config.filter_sensitive_data('<LINEAR_API_URL>') { 'https://api.linear.app/graphql' }

  # Default cassette options
  config.default_cassette_options = {
    serialize_with: :yaml,
    preserve_exact_body_bytes: false,
    decode_compressed_response: true,
    record: :once
  }

  # Configure for different test environments
  if ENV['VCR_OFF'] == 'true'
    config.turn_off!
  elsif ENV['VCR_RECORD_NEW_EPISODES'] == 'true'
    config.default_cassette_options[:record] = :new_episodes
  end
end
