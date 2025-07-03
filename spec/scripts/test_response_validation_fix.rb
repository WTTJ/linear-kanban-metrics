#!/usr/bin/env ruby
# frozen_string_literal: true

# Test script to verify the improved response validation logic
# This addresses the issue where valid responses were being incorrectly marked as invalid

require 'bundler/setup'
require 'logger'

# Load the PR review script
require_relative '../../.github/scripts/pr_review'

# Test the response validation logic
class ResponseValidationTest
  def initialize
    @logger = Logger.new($stdout)
    @logger.level = Logger::DEBUG
  end

  def run_tests
    puts 'Testing response validation logic...'
    puts '=' * 50

    test_cases = [
      # Valid responses (should return true)
      ['Valid long response', 'This is a valid PR review with sufficient content to be considered legitimate', true],
      ['Valid short response with content', 'LGTM! ✅', true],
      ['Valid response with markdown', "## Changes Look Good\n\nApproved!", true],
      ['Valid response with citations', "Good changes! <sup>[1](#ref-1)</sup>\n\n## References\n<a id=\"ref-1\"></a>[1] Some source", true],

      # Invalid responses (should return false)
      ['Retry needed marker', 'retry_needed', false],
      ['Dust agent did not respond', 'Dust agent did not respond.', false],
      ['Empty response error', 'Dust agent returned an empty response.', false],
      ['No conversation error', 'Dust did not return a conversation.', false],
      ['Failed to create', 'Failed to create Dust conversation.', false],
      ['Empty string', '', false],
      ['Very short error', 'Error', false],
      ['Whitespace only', "   \n  \t  ", false]
    ]

    test_cases.each do |name, response, expected|
      result = test_response_validation(response, expected, name)
      puts result
    end

    puts "\n#{'=' * 50}"
    puts 'All tests completed!'
  end

  private

  def test_response_validation(response, expected, test_name)
    # Create a minimal DustProvider instance for testing
    config = Struct.new(:dust_api_key, :dust_workspace_id, :dust_agent_id).new('test', 'test', 'test')
    http_client = Object.new
    provider = DustProvider.new(config, http_client, @logger)

    actual = provider.send(:response_is_valid?, response)
    status = actual == expected ? '✅ PASS' : '❌ FAIL'

    "#{status} #{test_name}: '#{response[0..30]}#{'...' if response.length > 30}' -> #{actual} (expected #{expected})"
  rescue StandardError => e
    "❌ ERROR #{test_name}: #{e.message}"
  end
end

# Run the tests
if __FILE__ == $PROGRAM_NAME
  test = ResponseValidationTest.new
  test.run_tests
end
