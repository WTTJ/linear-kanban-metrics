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
  
  api_key = ENV['DUST_API_KEY']
  workspace_id = ENV['DUST_WORKSPACE_ID']
  
  # Test both scenarios: with and without trailing space
  scenarios = [
    { name: 'Original agent ID', agent_id: ENV['DUST_AGENT_ID'] },
    { name: 'Agent ID with trailing space', agent_id: ENV['DUST_AGENT_ID'] + ' ' },
    { name: 'Agent ID with stripped whitespace', agent_id: ENV['DUST_AGENT_ID']&.strip }
  ]
  
  scenarios.each do |scenario|
    puts "\n📋 Testing: #{scenario[:name]}"
    puts "Agent ID: '#{scenario[:agent_id]}' (length: #{scenario[:agent_id]&.length})"
    
    # Create conversation
    uri = URI("https://dust.tt/api/v1/w/#{workspace_id}/assistant/conversations")
    headers = {
      'Authorization' => "Bearer #{api_key}",
      'Content-Type' => 'application/json'
    }
    
    body = {
      message: {
        content: "Test message to check mentions behavior with agent ID: '#{scenario[:agent_id]}'",
        context: {
          timezone: 'UTC',
          username: 'github-pr-reviewer',
          fullName: 'GitHub PR Reviewer',
          origin: 'api'
        },
        mentions: [{ configurationId: scenario[:agent_id] }]
      },
      blocking: true,
      streamGenerationEvents: false
    }.to_json

    puts "Mentions in request: [{ configurationId: '#{scenario[:agent_id]}' }]"
    
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    
    request = Net::HTTP::Post.new(uri)
    headers.each { |key, value| request[key] = value }
    request.body = body
    
    response = http.request(request)
    
    if response.code == '200'
      data = JSON.parse(response.body)
      conversation_id = data.dig('conversation', 'sId')
      puts "✅ Conversation created: #{conversation_id}"
      
      # Check the mentions in the response
      messages = data.dig('conversation', 'content')
      if messages && messages.any?
        user_message = messages.flatten.first
        mentions = user_message&.dig('mentions')
        puts "📝 Mentions in response: #{mentions.inspect}"
        
        if mentions.nil? || mentions.empty?
          puts "❌ PROBLEM: Mentions array is empty!"
        else
          puts "✅ Mentions preserved correctly"
        end
      end
      
      # Wait and check for agent response
      sleep(5)
      
      get_uri = URI("https://dust.tt/api/v1/w/#{workspace_id}/assistant/conversations/#{conversation_id}")
      get_request = Net::HTTP::Get.new(get_uri)
      get_request['Authorization'] = "Bearer #{api_key}"
      
      get_response = http.request(get_request)
      
      if get_response.code == '200'
        conv_data = JSON.parse(get_response.body)
        conv_messages = conv_data.dig('conversation', 'content')
        
        agent_messages = conv_messages&.flatten&.select { |msg| msg&.dig('type') == 'agent_message' }
        
        if agent_messages&.any?
          puts "✅ Agent responded successfully!"
        else
          puts "❌ Agent did not respond"
          message_types = conv_messages&.flatten&.filter_map { |m| m&.dig('type') }&.uniq || []
          puts "   Message types: #{message_types.join(', ')}"
        end
      end
    else
      puts "❌ Failed to create conversation: #{response.code}"
      puts "Response: #{response.body[0..200]}"
    end
    
    puts "-" * 50
  end
rescue StandardError => e
  puts "❌ Error: #{e.message}"
end

# Main execution
load_env_file
test_mentions_issue
