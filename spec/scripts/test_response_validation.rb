#!/usr/bin/env ruby
# frozen_string_literal: true

# Test script to verify the response validation fix

require_relative '../../.github/scripts/pr_review'

# Test the response validation logic
class ResponseValidationTester
  def test_response_validation
    puts '=' * 80
    puts 'Testing Response Validation Logic'
    puts '=' * 80

    # Create a mock DustProvider to test the validation
    config = double('config')
    http_client = double('http_client')
    logger = Logger.new($stdout)

    provider = DustProvider.new(config, http_client, logger)

    # Test cases
    test_cases = [
      {
        response: '# Code Review: PR Review Script Citation Processing Enhancement...',
        expected: true,
        description: 'Valid review content'
      },
      {
        response: 'retry_needed',
        expected: false,
        description: 'Retry signal'
      },
      {
        response: 'Dust agent did not respond.',
        expected: false,
        description: 'Error message - agent did not respond'
      },
      {
        response: 'Dust agent returned an empty response.',
        expected: false,
        description: 'Error message - empty response'
      },
      {
        response: 'Short',
        expected: false,
        description: 'Too short response'
      },
      {
        response: 'This is a valid response that contains the word respond in context but should be considered valid because it is long enough and does not start with error patterns.',
        expected: true,
        description: 'Valid response containing "respond" word in context'
      }
    ]

    puts "\n🧪 RUNNING VALIDATION TESTS:"
    puts '-' * 50

    test_cases.each_with_index do |test_case, index|
      result = provider.send(:response_is_valid?, test_case[:response])
      status = result == test_case[:expected] ? '✅' : '❌'

      puts "#{index + 1}. #{status} #{test_case[:description]}"
      puts "   Expected: #{test_case[:expected]}, Got: #{result}"

      puts "   Response: '#{test_case[:response][0..50]}...'" if result != test_case[:expected]
      puts
    end

    puts '=' * 80
    puts 'Response validation test completed!'
  end
end

# Run the test
if __FILE__ == $PROGRAM_NAME
  begin
    require 'logger'

    # Mock double method for testing
    def double(_name)
      Object.new
    end

    tester = ResponseValidationTester.new
    tester.test_response_validation
  rescue StandardError => e
    puts "❌ Error during response validation test: #{e.message}"
    puts e.backtrace.join("\n")
    exit 1
  end
end
