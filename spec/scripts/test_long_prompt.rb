#!/usr/bin/env ruby
# frozen_string_literal: true

# Test script to reproduce the exact GitHub Actions scenario
require 'bundler/setup'
require 'net/http'
require 'json'

# Load environment variables from config/.env.test
def load_env_file
  env_file = File.join(__dir__, '..', '..', 'config', '.env.test')
  unless File.exist?(env_file)
    puts '❌ config/.env.test file not found!'
    exit 1
  end

  File.readlines(env_file).each do |line|
    line.strip!
    next if line.empty? || line.start_with?('#')

    key, value = line.split('=', 2)
    ENV[key] = value if key && value && !ENV.key?(key)
  end
end

def test_long_prompt
  puts '🧪 Testing Dust API with long PR review prompt (GitHub Actions simulation)...'

  long_prompt = create_test_prompt
  puts "📊 Prompt length: #{long_prompt.length} characters"

  conversation_id = create_conversation(long_prompt)
  return false unless conversation_id

  puts "✅ Conversation created: #{conversation_id}"
  await_agent_response(conversation_id)
rescue StandardError => e
  puts "❌ Error: #{e.message}"
  false
end

def create_test_prompt
  <<~PROMPT
    # PR Review Prompt Template

    You are a senior Ruby developer reviewing a pull request for a kanban metrics analysis tool.

    ## CODING STANDARDS
    # AI Code Review Standards Configuration
    # This file defines the coding standards and design patterns that should be enforced during AI code reviews

    ## Project Architecture Standards

    ### Module Organization
    - All code must be organized under the `KanbanMetrics` namespace
    - Use Zeitwerk autoloading - never use `require_relative`
    - Follow the established module hierarchy:
      - `KanbanMetrics::Linear::*` - API client layer
      - `KanbanMetrics::Calculators::*` - Business logic and metrics
      - `KanbanMetrics::Timeseries::*` - Time series analysis
      - `KanbanMetrics::Formatters::*` - Output formatting strategies
      - `KanbanMetrics::Reports::*` - High-level report generation

    ### Design Patterns (Required)
    1. **Value Objects**: Use for configuration and data transfer
    2. **Strategy Pattern**: Use for formatters and calculators
    3. **Template Method**: Use for base calculator classes
    4. **Builder Pattern**: Use for complex query construction
    5. **Adapter Pattern**: Use for external API integrations

    Please review the following changes and provide a brief summary.

    ## Changes to Review:

    ```diff
    + # This is a sample diff for testing
    + class TestClass
    +   def initialize
    +     @test = 'value'
    +   end
    + end
    ```

    Please provide your review in markdown format.
  PROMPT
end

def create_conversation(prompt)
  uri = URI("https://dust.tt/api/v1/w/#{ENV.fetch('DUST_WORKSPACE_ID', nil)}/assistant/conversations")
  request_data = build_conversation_request(prompt)

  puts '🔄 Creating conversation...'
  response = make_http_request(uri, :post, request_data[:headers], request_data[:body])

  handle_conversation_response(response)
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
        fullName: 'GitHub PR Reviewer'
      },
      mentions: [{ configurationId: ENV.fetch('DUST_AGENT_ID', nil) }]
    },
    blocking: true,
    streamGenerationEvents: false
  }.to_json

  { headers: headers, body: body }
end

def handle_conversation_response(response)
  if response.code == '200'
    data = JSON.parse(response.body)
    data.dig('conversation', 'sId')
  else
    puts "❌ Failed to create conversation: #{response.code} #{response.body[0..200]}"
    nil
  end
end

# rubocop:disable Naming/PredicateMethod
def await_agent_response(conversation_id)
  (1..5).each do |attempt|
    puts "🔍 Checking for response (attempt #{attempt}/5)..."
    sleep(5)

    response = get_conversation(conversation_id)
    return true if process_conversation_response(response)
  end

  puts '❌ Agent did not respond after 5 attempts (25 seconds)'
  false
end

def get_conversation(conversation_id)
  uri = URI("https://dust.tt/api/v1/w/#{ENV.fetch('DUST_WORKSPACE_ID', nil)}/assistant/conversations/#{conversation_id}")
  headers = { 'Authorization' => "Bearer #{ENV.fetch('DUST_API_KEY', nil)}" }

  make_http_request(uri, :get, headers)
end

def process_conversation_response(response)
  return false unless response.code == '200'

  conv_data = JSON.parse(response.body)
  messages = conv_data.dig('conversation', 'content')

  return false unless messages && messages.length > 1

  handle_agent_messages(messages)
end

def handle_agent_messages(messages)
  # rubocop:enable Naming/PredicateMethod
  agent_messages = messages.flatten.select { |msg| msg&.dig('type') == 'agent_message' }

  if agent_messages.any?
    puts "✅ Agent responded! (#{agent_messages.length} messages)"
    content = agent_messages.last&.dig('content')
    puts "📝 Response preview: #{content&.slice(0, 200)}..."
    true
  else
    display_no_agent_response(messages)
    false
  end
end

def display_no_agent_response(messages)
  puts "⏳ No agent response yet... (found #{messages.length} messages total)"
  message_types = messages.flatten.filter_map { |m| m&.dig('type') }.uniq
  puts "   Message types: #{message_types.join(', ')}"
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

# Main execution
load_env_file
success = test_long_prompt

if success
  puts "\n🎉 Long prompt test passed!"
else
  puts "\n💥 Long prompt test failed - this might explain the GitHub Actions issue"
end
