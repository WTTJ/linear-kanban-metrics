# frozen_string_literal: true

require 'webmock/rspec'

# WebMock Configuration
WebMock.disable_net_connect!(allow_localhost: true)

# RSpec configuration for WebMock integration
RSpec.configure do |config|
  # Reset WebMock after each example
  config.after do
    WebMock.reset!
  end

  # Allow real connections for specific test types if needed
  config.around(:each, :allow_real_connections) do |example|
    WebMock.allow_net_connect!
    example.run
    WebMock.disable_net_connect!(allow_localhost: true)
  end
end
