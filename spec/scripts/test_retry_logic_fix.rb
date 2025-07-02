#!/usr/bin/env ruby
# frozen_string_literal: true

# Test script to demonstrate the fix for unnecessary retries in Dust provider
# This script shows that the improved response validation prevents unnecessary retries
# when valid responses are received

require 'bundler/setup'
require 'logger'

# Load the PR review script
require_relative '../../.github/scripts/pr_review'

class RetryLogicDemonstration
  def initialize
    @logger = Logger.new($stdout)
    @logger.level = Logger::INFO
  end

  def run_demonstration
    puts 'Dust Provider Retry Logic Fix Demonstration'
    puts '=' * 60
    puts

    puts "PROBLEM: Before the fix, valid short responses like 'LGTM!' or 'Approved'"
    puts '         were incorrectly marked as invalid, causing unnecessary retries.'
    puts

    puts 'SOLUTION: Improved response_is_valid? method that:'
    puts '  - Handles nil responses properly'
    puts '  - Recognizes common review terms and emojis'
    puts '  - Allows legitimate short responses'
    puts '  - Still rejects actual error messages'
    puts

    demonstrate_old_vs_new_behavior

    puts "\nRESULT: This fix eliminates unnecessary retries when the Dust agent"
    puts '        provides valid short responses, improving performance and reducing'
    puts '        API calls while maintaining error detection capabilities.'
  end

  private

  def demonstrate_old_vs_new_behavior
    # Test cases that would have failed with the old validation
    problematic_responses = [
      'LGTM! ✅',
      'Approved',
      'Good work!',
      '👍',
      'OK',
      "## Changes Look Good\n\nApproved!",
      'Changes look good! <sup>[1](#ref-1)</sup>'
    ]

    puts 'Examples of responses that would have triggered unnecessary retries:'
    puts '-' * 60

    problematic_responses.each do |response|
      old_result = old_validation_logic?(response)
      new_result = new_validation_logic(response)

      status = old_result == new_result ? 'SAME' : 'FIXED'
      puts "Response: '#{response[0..30]}#{'...' if response.length > 30}'"
      puts "  Old logic: #{old_result ? 'VALID' : 'INVALID (would retry)'}"
      puts "  New logic: #{new_result ? 'VALID' : 'INVALID'}"
      puts "  Status: #{status == 'FIXED' ? '✅ FIXED' : '⚪ SAME'}"
      puts
    end
  end

  def old_validation_logic?(response)
    # Simulate the old validation logic that was too strict
    return false if response == 'retry_needed'
    return false if response.start_with?('Dust agent did not respond.')
    return false if response.start_with?('Dust agent returned an empty response.')
    return false if response.start_with?('Dust did not return a conversation.')
    return false if response.start_with?('Failed to create Dust conversation.')

    # This was the problematic line - too strict minimum length
    return false if response.length < 50

    true
  end

  def new_validation_logic(response)
    # Use the actual new validation logic
    config = Struct.new(:dust_api_key, :dust_workspace_id, :dust_agent_id).new('test', 'test', 'test')
    http_client = Object.new
    provider = DustProvider.new(config, http_client, @logger)

    provider.send(:response_is_valid?, response)
  end
end

# Run the demonstration
if __FILE__ == $PROGRAM_NAME
  demo = RetryLogicDemonstration.new
  demo.run_demonstration
end
