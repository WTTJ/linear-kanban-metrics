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
  
  # This is similar to what the actual PR review script sends
  long_prompt = <<~PROMPT
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

  api_key = ENV['DUST_API_KEY']
  workspace_id = ENV['DUST_WORKSPACE_ID']
  agent_id = ENV['DUST_AGENT_ID']
  
  # Create conversation (same as PR script)
  uri = URI("https://dust.tt/api/v1/w/#{workspace_id}/assistant/conversations")
  headers = {
    'Authorization' => "Bearer #{api_key}",
    'Content-Type' => 'application/json'
  }
  
  body = {
    message: {
      content: long_prompt,
      context: {
        timezone: 'UTC',
        username: 'github-pr-reviewer',
        fullName: 'GitHub PR Reviewer'
      },
      mentions: [{ configurationId: agent_id }]
    },
    blocking: true,
    streamGenerationEvents: false
  }.to_json

  puts "📊 Prompt length: #{long_prompt.length} characters"
  puts "🔄 Creating conversation..."
  
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.open_timeout = 30
  http.read_timeout = 120
  
  request = Net::HTTP::Post.new(uri)
  headers.each { |key, value| request[key] = value }
  request.body = body
  
  response = http.request(request)
  
  if response.code == '200'
    data = JSON.parse(response.body)
    conversation_id = data.dig('conversation', 'sId')
    puts "✅ Conversation created: #{conversation_id}"
    
    # Wait and check for response multiple times
    (1..5).each do |attempt|
      puts "🔍 Checking for response (attempt #{attempt}/5)..."
      sleep(5)
      
      # Get conversation
      get_uri = URI("https://dust.tt/api/v1/w/#{workspace_id}/assistant/conversations/#{conversation_id}")
      get_request = Net::HTTP::Get.new(get_uri)
      get_request['Authorization'] = "Bearer #{api_key}"
      
      get_response = http.request(get_request)
      
      if get_response.code == '200'
        conv_data = JSON.parse(get_response.body)
        messages = conv_data.dig('conversation', 'content')
        
        if messages && messages.length > 1
          agent_messages = messages.flatten.select { |msg| msg&.dig('type') == 'agent_message' }
          
          if agent_messages.any?
            puts "✅ Agent responded! (#{agent_messages.length} messages)"
            content = agent_messages.last&.dig('content')
            puts "📝 Response preview: #{content&.slice(0, 200)}..."
            return true
          else
            puts "⏳ No agent response yet... (found #{messages.length} messages total)"
            message_types = messages.flatten.filter_map { |m| m&.dig('type') }.uniq
            puts "   Message types: #{message_types.join(', ')}"
          end
        else
          puts "⏳ Waiting for messages..."
        end
      else
        puts "❌ Error getting conversation: #{get_response.code}"
      end
    end
    
    puts "❌ Agent did not respond after 5 attempts (25 seconds)"
    false
  else
    puts "❌ Failed to create conversation: #{response.code} #{response.body[0..200]}"
    false
  end
rescue StandardError => e
  puts "❌ Error: #{e.message}"
  false
end

# Main execution
load_env_file
success = test_long_prompt

if success
  puts "\n🎉 Long prompt test passed!"
else
  puts "\n💥 Long prompt test failed - this might explain the GitHub Actions issue"
end
