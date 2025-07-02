#!/usr/bin/env ruby
# frozen_string_literal: true

# Test script to reproduce the GitHub Actions mentions issue

require 'bundler/setup'
require 'net/http'
require 'json'

# Load environment variables from config/.env.test
def load_env_file
  env_file = File.join(__dir__, '..', '..', 'config', '.env.test')
  File.readlines(env_file).each do |line|
    line.strip!
    next if line.empty? || line.start_with?('#')

    key, value = line.split('=', 2)
    ENV[key] = value if key && value && !ENV.key?(key)
  end
end

def test_mentions_issue
  puts '🔧 Testing Dust API mentions issue reproduction...'

  scenarios = create_test_scenarios
  scenarios.each { |scenario| test_scenario(scenario) }
rescue StandardError => e
  puts "❌ Error: #{e.message}"
end

def create_test_scenarios
  [
    { name: 'Original agent ID', agent_id: ENV.fetch('DUST_AGENT_ID', nil) },
    { name: 'Agent ID with trailing space', agent_id: "#{ENV.fetch('DUST_AGENT_ID', nil)} " },
    { name: 'Agent ID with stripped whitespace', agent_id: ENV['DUST_AGENT_ID']&.strip }
  ]
end

def test_scenario(scenario)
  puts "\n📋 Testing: #{scenario[:name]}"
  puts "Agent ID: '#{scenario[:agent_id]}' (length: #{scenario[:agent_id]&.length})"
  puts "Mentions in request: [{ configurationId: '#{scenario[:agent_id]}' }]"

  conversation_id = create_test_conversation(scenario[:agent_id])
  return unless conversation_id

  puts "✅ Conversation created: #{conversation_id}"
  check_mentions_and_response(conversation_id)
  puts '-' * 50
end

def create_test_conversation(agent_id)
  uri = URI("https://dust.tt/api/v1/w/#{ENV.fetch('DUST_WORKSPACE_ID', nil)}/assistant/conversations")
  request_data = build_test_conversation_request(agent_id)

  response = make_request(uri, request_data[:headers], request_data[:body])
  handle_conversation_creation(response)
end

def build_test_conversation_request(agent_id)
  headers = {
    'Authorization' => "Bearer #{ENV.fetch('DUST_API_KEY', nil)}",
    'Content-Type' => 'application/json'
  }

  body = {
    message: {
      content: "Test message to check mentions behavior with agent ID: '#{agent_id}'",
      context: {
        timezone: 'UTC',
        username: 'github-pr-reviewer',
        fullName: 'GitHub PR Reviewer',
        origin: 'api'
      },
      mentions: [{ configurationId: agent_id }]
    },
    blocking: true,
    streamGenerationEvents: false
  }.to_json

  { headers: headers, body: body }
end

def handle_conversation_creation(response)
  if response.code == '200'
    data = JSON.parse(response.body)
    conversation_id = data.dig('conversation', 'sId')
    check_mentions_in_response(data)
    conversation_id
  else
    puts "❌ Failed to create conversation: #{response.code}"
    puts "Response: #{response.body[0..200]}"
    nil
  end
end

def check_mentions_in_response(data)
  messages = data.dig('conversation', 'content')
  return unless messages&.any?

  user_message = messages.flatten.first
  mentions = user_message&.dig('mentions')
  puts "📝 Mentions in response: #{mentions.inspect}"

  if mentions.nil? || mentions.empty?
    puts '❌ PROBLEM: Mentions array is empty!'
  else
    puts '✅ Mentions preserved correctly'
  end
end

def check_mentions_and_response(conversation_id)
  sleep(5)

  get_uri = URI("https://dust.tt/api/v1/w/#{ENV.fetch('DUST_WORKSPACE_ID', nil)}/assistant/conversations/#{conversation_id}")
  headers = { 'Authorization' => "Bearer #{ENV.fetch('DUST_API_KEY', nil)}" }

  response = make_request(get_uri, headers)
  process_conversation_response(response)
end

def process_conversation_response(response)
  return unless response.code == '200'

  conv_data = JSON.parse(response.body)
  conv_messages = conv_data.dig('conversation', 'content')
  agent_messages = conv_messages&.flatten&.select { |msg| msg&.dig('type') == 'agent_message' }

  if agent_messages&.any?
    puts '✅ Agent responded successfully!'
  else
    display_no_agent_response(conv_messages)
  end
end

def display_no_agent_response(conv_messages)
  puts '❌ Agent did not respond'
  message_types = conv_messages&.flatten&.filter_map { |m| m&.dig('type') }&.uniq || []
  puts "   Message types: #{message_types.join(', ')}"
end

def make_request(uri, headers, body = nil)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true

  request = body ? Net::HTTP::Post.new(uri) : Net::HTTP::Get.new(uri)
  headers.each { |key, value| request[key] = value }
  request.body = body if body

  http.request(request)
end

# Main execution
load_env_file
test_mentions_issue
