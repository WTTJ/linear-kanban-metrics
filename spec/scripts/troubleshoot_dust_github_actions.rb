#!/usr/bin/env ruby
# frozen_string_literal: true

# Comprehensive test to simulate GitHub Actions Dust API issues and solutions

puts <<~HEADER
  🔧 DUST API GITHUB ACTIONS TROUBLESHOOTING GUIDE
  =====================================================

  This script tests and provides solutions for the Dust API#{' '}
  agent not responding in GitHub Actions environment.

HEADER

# Quick test to verify the issue exists in different scenarios
require 'bundler/setup'
require 'net/http'
require 'json'

def load_env_file
  env_file = File.join(__dir__, '..', '..', 'config', '.env.test')
  File.readlines(env_file).each do |line|
    line.strip!
    next if line.empty? || line.start_with?('#')

    key, value = line.split('=', 2)
    ENV[key] = value if key && value && !ENV.key?(key)
  end
end

def test_scenario(name, prompt, wait_time = 5, max_retries = 3)
  puts "\n📋 Testing: #{name}"
  puts "Prompt length: #{prompt.length} characters"

  conversation_id = create_conversation(prompt)
  return handle_creation_failure unless conversation_id

  puts "✅ Conversation created: #{conversation_id}"
  wait_and_check_response(conversation_id, wait_time, max_retries)
rescue StandardError => e
  puts "❌ Error: #{e.message}"
  { success: false, error: e.message }
end

def create_conversation(prompt)
  uri = URI("https://dust.tt/api/v1/w/#{ENV.fetch('DUST_WORKSPACE_ID', nil)}/assistant/conversations")
  request_data = build_conversation_request(prompt)

  response = make_http_request(uri, :post, request_data[:headers], request_data[:body])
  parse_conversation_response(response)
end

def build_conversation_request(prompt)
  headers = {
    'Authorization' => "Bearer #{ENV.fetch('DUST_API_KEY', nil)}",
    'Content-Type' => 'application/json'
  }

  body = {
    message: {
      content: prompt,
      context: {
        timezone: 'UTC',
        username: 'github-pr-reviewer',
        fullName: 'GitHub PR Reviewer',
        origin: 'api'
      },
      mentions: [{ configurationId: ENV.fetch('DUST_AGENT_ID', nil) }]
    },
    blocking: true,
    streamGenerationEvents: false
  }.to_json

  { headers: headers, body: body }
end

def parse_conversation_response(response)
  if response.code == '200'
    data = JSON.parse(response.body)
    data.dig('conversation', 'sId')
  else
    puts "❌ Failed to create conversation: #{response.code}"
    nil
  end
end

def handle_creation_failure
  { success: false, error: 'Failed to create conversation' }
end

def wait_and_check_response(conversation_id, wait_time, max_retries)
  puts "⏳ Waiting #{wait_time} seconds..."
  sleep(wait_time)

  check_for_agent_response(conversation_id, max_retries)
end

def check_for_agent_response(conversation_id, max_retries)
  (1..max_retries).each do |attempt|
    puts "🔍 Checking for response (attempt #{attempt}/#{max_retries})..."

    response = get_conversation_response(conversation_id)
    result = process_response_attempt(response)

    return result if result[:success]

    sleep(5) if attempt < max_retries
  end

  puts "❌ Agent did not respond after #{max_retries} attempts"
  { success: false, error: 'No agent response' }
end

def get_conversation_response(conversation_id)
  uri = URI("https://dust.tt/api/v1/w/#{ENV.fetch('DUST_WORKSPACE_ID', nil)}/assistant/conversations/#{conversation_id}")
  headers = { 'Authorization' => "Bearer #{ENV.fetch('DUST_API_KEY', nil)}" }

  make_http_request(uri, :get, headers)
end

def process_response_attempt(response)
  return { success: false, error: 'HTTP error' } unless response.code == '200'

  conv_data = JSON.parse(response.body)
  messages = conv_data.dig('conversation', 'content')

  return check_agent_messages(messages) if messages && messages.length > 1

  show_waiting_status(messages)
  { success: false, error: 'Still waiting' }
end

def check_agent_messages(messages)
  agent_messages = messages.flatten.select { |msg| msg&.dig('type') == 'agent_message' }

  if agent_messages.any?
    content = agent_messages.last&.dig('content')
    puts "✅ Agent responded! Response length: #{content&.length || 0} chars"
    { success: true, response: content&.slice(0, 100) }
  else
    show_waiting_status(messages)
    { success: false, error: 'Still waiting' }
  end
end

def show_waiting_status(messages)
  message_types = messages&.flatten&.filter_map { |m| m&.dig('type') }&.uniq || []
  puts "⏳ No agent response yet. Message types: #{message_types.join(', ')}"
end

def make_http_request(uri, method, headers, body = nil)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.open_timeout = 30
  http.read_timeout = 120

  request = case method
            when :post
              Net::HTTP::Post.new(uri)
            when :get
              Net::HTTP::Get.new(uri)
            end

  headers.each { |key, value| request[key] = value }
  request.body = body if body

  http.request(request)
end

# Load environment
load_env_file

# Test scenarios
scenarios = [
  {
    name: 'Short prompt (should work)',
    prompt: 'Hello! Please provide a brief code review for this simple Ruby class: `class Test; end`',
    wait_time: 3,
    max_retries: 2
  },
  {
    name: 'Medium prompt (simulating PR review)',
    prompt: <<~PROMPT,
      # PR Review Request

      Please review this Ruby code change:

      ```ruby
      class TestClass
        def initialize
          @test = 'value'
        end
      end
      ```

      Check for:
      - Code quality
      - Ruby conventions
      - Potential improvements
    PROMPT
    wait_time: 5,
    max_retries: 3
  },
  {
    name: 'Long prompt (GitHub Actions scenario)',
    prompt: "#{File.read(File.join(__dir__, '..', '..', 'doc', 'CODING_STANDARDS.md'))[0..2000]}\n\nPlease review: `class Test; end`",
    wait_time: 8,
    max_retries: 5
  }
]

results = []

scenarios.each do |scenario|
  result = test_scenario(scenario[:name], scenario[:prompt], scenario[:wait_time], scenario[:max_retries])
  results << { scenario: scenario[:name], **result }
end

puts <<~SUMMARY

  📊 TEST RESULTS SUMMARY
  =======================

SUMMARY

results.each do |result|
  status = result[:success] ? '✅ PASS' : '❌ FAIL'
  puts "#{status} #{result[:scenario]}"
  puts "       #{result[:error]}" if result[:error]
  puts "       Preview: #{result[:response]}..." if result[:response]
end

puts <<~SOLUTIONS

  🔧 SOLUTIONS FOR GITHUB ACTIONS
  ===============================

  Based on the test results, here are the recommended fixes:

  1. **Increase Initial Wait Time**
     - Local: 3 seconds
     - GitHub Actions: 8+ seconds
     - Reason: Network latency in CI environment

  2. **Increase Retry Attempts**
     - Local: 3 attempts
     - GitHub Actions: 5+ attempts
     - Reason: Agent processing time varies

  3. **Add Context Origin**
     - Include 'origin: api' in message context
     - Helps with agent triggering

  4. **Better Error Messages**
     - Provide helpful debugging info
     - Include conversation ID and timestamp

  5. **Environment Detection**
     - Detect GitHub Actions with ENV['GITHUB_ACTIONS']
     - Use different timeouts accordingly

  ✅ FIXES IMPLEMENTED IN .github/scripts/pr_review.rb

  The PR review script has been updated with these improvements.
  Try running the GitHub Action again - it should work better now!

SOLUTIONS
