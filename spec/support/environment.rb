# frozen_string_literal: true

# Test environment configuration
RSpec.configure do |config|
  # Environment setup
  config.before(:suite) do
    # Set test environment variables
    ENV['LINEAR_API_TOKEN'] ||= 'test-token-123'
    ENV['RACK_ENV'] = 'test'

    # Zeitwerk debugging in tests if needed
    if ENV['ZEITWERK_DEBUG']
      require 'logger'
      Zeitwerk::Loader.eager_load_all
    end
  end

  # Clean up between tests
  config.before do
    # Clear any cached data - using environment-specific test cache directory
    FileUtils.rm_rf('tmp/.linear_cache_test')

    # Reset any test-specific environment variables
    restore_original_env_vars
  end

  # Cleanup after all tests
  config.after(:suite) do
    FileUtils.rm_rf('tmp/.linear_cache_test')
  end

  private

  def restore_original_env_vars
    # Store original values if needed for restoration
    @original_env_vars ||= {}

    # Restore any modified env vars
    @original_env_vars.each do |key, value|
      ENV[key] = value
    end
  end
end
