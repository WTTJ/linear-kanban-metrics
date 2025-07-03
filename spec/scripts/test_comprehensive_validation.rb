#!/usr/bin/env ruby
# frozen_string_literal: true

# Comprehensive test for the improved response validation logic
# Tests edge cases and real-world scenarios

require 'bundler/setup'
require 'logger'

# Load the PR review script
require_relative '../../.github/scripts/pr_review'

class ComprehensiveValidationTest
  attr_reader :logger

  def initialize
    @logger = Logger.new($stdout)
    @logger.level = Logger::WARN # Reduce noise for comprehensive testing
  end

  def run_tests
    puts 'Comprehensive Response Validation Test'
    puts '=' * 50

    test_cases = [
      # Valid responses (should return true)
      ['Long valid response', 'This is a comprehensive PR review with detailed analysis of the changes.', true],
      ['LGTM with emoji', 'LGTM! ✅', true],
      ['Approved', 'Approved', true],
      ['Simple good', 'Good', true],
      ['Thumbs up emoji', '👍', true],
      ['OK response', 'OK', true],
      ['Yes response', 'Yes', true],
      ['Short markdown', '## Approved', true],
      ['Multi-line short', "LGTM!\nGood work.", true],
      ['Citation response', 'Changes look good! <sup>[1](#ref-1)</sup>', true],

      # Invalid responses (should return false)
      ['Error keyword', 'Error', false],
      ['Exception keyword', 'Exception', false],
      ['Timeout keyword', 'Timeout', false],
      ['Failed keyword', 'Failed', false],
      ['Null response', nil, false],
      ['Empty string', '', false],
      ['Whitespace only', "   \n  \t  ", false],
      ['Very short non-review', 'Hi', false],
      ['Single char', 'x', false],
      ['Two chars', 'no', false],
      ['Retry marker', 'retry_needed', false],
      ['Dust error 1', 'Dust agent did not respond.', false],
      ['Dust error 2', 'Dust agent returned an empty response.', false],
      ['Dust error 3', 'Dust did not return a conversation.', false],
      ['Dust error 4', 'Failed to create Dust conversation.', false]
    ]

    passed = 0
    failed = 0

    test_cases.each do |name, response, expected|
      result = test_response_validation(response, expected, name)
      if result.start_with?('✅')
        passed += 1
      else
        failed += 1
      end
      puts result
    end

    puts "\n#{'=' * 50}"
    puts "Test Results: #{passed} passed, #{failed} failed"
    puts "Success Rate: #{(passed.to_f / (passed + failed) * 100).round(1)}%"

    if failed == 0
      puts '🎉 All tests passed! Response validation is working correctly.'
    else
      puts '⚠️  Some tests failed. Review the validation logic.'
    end
  end

  private

  def test_response_validation(response, expected, test_name)
    # Create a minimal DustProvider instance for testing
    config = Struct.new(:dust_api_key, :dust_workspace_id, :dust_agent_id).new('test', 'test', 'test')
    http_client = Object.new
    provider = DustProvider.new(config, http_client, @logger)

    actual = provider.send(:response_is_valid?, response)
    status = actual == expected ? '✅ PASS' : '❌ FAIL'

    display_response = response.nil? ? 'nil' : "'#{response.to_s[0..30]}#{'...' if response.to_s.length > 30}'"
    "#{status} #{test_name}: #{display_response} -> #{actual} (expected #{expected})"
  rescue StandardError => e
    "❌ ERROR #{test_name}: #{e.message}"
  end
end

# Run the tests
if __FILE__ == $PROGRAM_NAME
  test = ComprehensiveValidationTest.new
  test.run_tests
end
