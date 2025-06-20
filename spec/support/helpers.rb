# frozen_string_literal: true

# Test helper methods
module TestHelpers
  # Fixture loading helpers
  def fixture_path(filename)
    File.join(File.dirname(__FILE__), '..', 'fixtures', filename)
  end

  def load_fixture(filename)
    File.read(fixture_path(filename))
  end

  def parse_json_fixture(filename)
    JSON.parse(load_fixture(filename))
  end

  # Cache management helpers
  def clear_test_cache
    FileUtils.rm_rf('tmp/.linear_cache_test')
  end

  # Time helpers for testing cache expiration
  def travel_to_tomorrow
    tomorrow = Time.now + (24 * 60 * 60)
    allow(Time).to receive(:now).and_return(tomorrow)
  end

  def travel_to_midnight_plus_one_second
    midnight_plus_one = Time.parse('00:00:01')
    allow(Time).to receive(:now).and_return(midnight_plus_one)
  end

  # API response helpers
  def mock_linear_response(data)
    { 'data' => data }
  end

  def mock_linear_error(message, code = 'GRAPHQL_ERROR')
    {
      'errors' => [
        {
          'message' => message,
          'extensions' => { 'code' => code }
        }
      ]
    }
  end

  # Output capture helper for testing printed output
  def capture_stdout
    old_stdout = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = old_stdout
  end
end

# Include helpers in all specs
RSpec.configure do |config|
  config.include TestHelpers
end
