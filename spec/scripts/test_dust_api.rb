#!/usr/bin/env ruby
# frozen_string_literal: true

# Simple Dust API test script
# Tests basic Dust API functionality using config/.env.test

require 'bundler/setup'
require 'net/http'
require 'json'

# Load environment variables from config/.env.test
def load_env_file
  env_file = File.join(__dir__, '..', '..', 'config', '.env.test')
  unless File.exist?(env_file)
    puts '❌ config/.env.test file not found!'
    puts 'Please create config/.env.test with your Dust API credentials'
    exit 1
  end

  puts '📄 Loading environment variables from config/.env.test...'
  File.readlines(env_file).each do |line|
    line.strip!
    next if line.empty? || line.start_with?('#')

    key, value = line.split('=', 2)
    ENV[key] = value if key && value && !ENV.key?(key)
  end
end

# Simple HTTP client for Dust API
class DustAPIClient
  API_BASE_URL = 'https://dust.tt'

  def initialize(api_key, workspace_id, agent_id, logger)
    @api_key = api_key
    @workspace_id = workspace_id
    @agent_id = agent_id
    @logger = logger
  end

  def test_connection
    @logger.info '🔌 Testing Dust API connection...'

    # Test with a prompt similar to PR review to match production usage
    prompt = "# PR Review Test\n\nYou are a senior Ruby developer reviewing code. This is a test message to verify the API integration is working.\n\n## Code Changes\n```ruby\nclass TestClass\n  def initialize\n    @test = 'value'\n  end\nend\n```\n\nPlease provide a brief review of this code and confirm the API connection is working."

    conversation = create_conversation(prompt)
    conversation_id = conversation.dig('conversation', 'sId')

    if conversation_id
      @logger.info "✅ Conversation created: #{conversation_id}"

      # Wait longer for processing (matching PR review script)
      sleep(3)

      # Get response with retries (like PR review script)
      response = get_response_with_retries(conversation_id)

      if response && !response.empty? && !response.include?('did not respond')
        @logger.info '✅ Response received!'
        puts "\n" + ('=' * 60)
        puts '🤖 DUST AI RESPONSE:'
        puts '=' * 60
        puts
        puts response
        puts
        puts '=' * 60
        puts "📏 Response length: #{response.length} characters"
        true
      else
        @logger.error '❌ No response received from agent'
        @logger.error "Response content: #{response}" if response
        false
      end
    else
      @logger.error '❌ Failed to create conversation'
      false
    end
  rescue StandardError => e
    @logger.error "❌ API test failed: #{e.message}"
    false
  end

  private

  def create_conversation(prompt)
    uri = URI("#{API_BASE_URL}/api/v1/w/#{@workspace_id}/assistant/conversations")
    headers = {
      'Authorization' => "Bearer #{@api_key}",
      'Content-Type' => 'application/json'
    }

    body = {
      message: {
        content: prompt,
        context: {
          timezone: 'UTC',
          username: 'api-tester',
          fullName: 'API Tester'
        },
        mentions: [{ configurationId: @agent_id }]
      },
      blocking: true,
      streamGenerationEvents: false
    }.to_json

    @logger.debug '📤 Creating conversation...'
    response = make_request(uri, :post, headers, body)
    @logger.debug "📥 Conversation response: #{response.keys}" if response.is_a?(Hash)
    response
  end

  def get_response(conversation_id)
    uri = URI("#{API_BASE_URL}/api/v1/w/#{@workspace_id}/assistant/conversations/#{conversation_id}")
    headers = { 'Authorization' => "Bearer #{@api_key}" }

    @logger.debug "📤 Fetching conversation: #{conversation_id}"
    response = make_request(uri, :get, headers)

    @logger.debug "Full Dust API response: #{response.inspect}"

    messages = response.dig('conversation', 'content')
    if messages.nil? || messages.empty?
      @logger.debug "No conversation content found. API response keys: #{response.keys}"
      return nil
    end

    @logger.debug "Found #{messages.length} messages in conversation"

    # Find agent messages
    all_messages = messages.is_a?(Array) ? messages.flatten : [messages]
    agent_messages = all_messages.select { |msg| msg&.dig('type') == 'agent_message' }

    @logger.debug "Found #{agent_messages.length} agent messages"

    if agent_messages.empty?
      @logger.debug "No agent messages found. All message types: #{all_messages.filter_map { |m| m&.dig('type') }.uniq}"
      return nil
    end

    # Return the content of the latest agent message
    latest_message = agent_messages.last
    content = latest_message&.dig('content')

    @logger.debug "Latest agent message content: #{content&.slice(0, 100)}..." if content

    content
  end

  # Add retry logic similar to PR review script
  def get_response_with_retries(conversation_id, max_retries = 3)
    retries = 0

    while retries < max_retries
      begin
        @logger.debug "Attempting to fetch response (attempt #{retries + 1}/#{max_retries})"
        response = get_response(conversation_id)

        # If we get a meaningful response (not an error message), return it
        return response unless response.nil? || response.empty?

        if retries < max_retries - 1
          wait_time = (retries + 1) * 3 # Progressive backoff: 3s, 6s, 9s
          @logger.debug "Agent hasn't responded yet, waiting #{wait_time} seconds before retry..."
          sleep(wait_time)
        end

        retries += 1
      rescue StandardError => e
        @logger.error "Error fetching response (attempt #{retries + 1}): #{e.message}"
        retries += 1
        sleep(2) if retries < max_retries
      end
    end

    @logger.error "Agent did not respond after #{max_retries} attempts"
    'Dust agent did not respond after multiple attempts. The agent may be busy or misconfigured.'
  end

  def make_request(uri, method, headers, body = nil)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 30
    http.read_timeout = 120

    request = case method
              when :post
                req = Net::HTTP::Post.new(uri)
                req.body = body if body
                req
              when :get
                Net::HTTP::Get.new(uri)
              end

    headers.each { |key, value| request[key] = value }

    response = http.request(request)

    unless response.code == '200'
      error_msg = "HTTP #{response.code}: #{response.body}"
      @logger.error error_msg
      raise StandardError, error_msg
    end

    JSON.parse(response.body)
  rescue JSON::ParserError => e
    @logger.error "Failed to parse response: #{e.message}"
    raise StandardError, "Invalid JSON response: #{e.message}"
  end
end

# Simple logger
class SimpleLogger
  def initialize(debug = false)
    @debug = debug
  end

  def info(message)
    puts "[INFO] #{message}"
  end

  def debug(message)
    puts "[DEBUG] #{message}" if @debug
  end

  def error(message)
    puts "[ERROR] #{message}"
  end
end

# Main test execution
def main
  puts '🧪 Dust API Test Script'
  puts '=' * 50

  # Load environment
  load_env_file

  # Check required variables
  required_vars = %w[DUST_API_KEY DUST_WORKSPACE_ID DUST_AGENT_ID]
  missing_vars = required_vars.select { |var| ENV[var].nil? || ENV[var].empty? }

  unless missing_vars.empty?
    puts '❌ Missing required environment variables in config/.env.test:'
    missing_vars.each { |var| puts "   - #{var}" }
    puts "\nPlease add these to your config/.env.test file:"
    puts 'DUST_API_KEY=your_api_key_here'
    puts 'DUST_WORKSPACE_ID=your_workspace_id_here'
    puts 'DUST_AGENT_ID=your_agent_id_here'
    exit 1
  end

  # Show configuration
  puts '✅ Configuration loaded:'
  puts "   Workspace ID: #{ENV.fetch('DUST_WORKSPACE_ID', nil)}"
  puts "   Agent ID: #{ENV.fetch('DUST_AGENT_ID', nil)}"
  puts "   API Key: #{ENV['DUST_API_KEY'][0..8]}..." if ENV['DUST_API_KEY']

  # Create logger
  debug_mode = ENV['DEBUG'] == 'true'
  logger = SimpleLogger.new(debug_mode)
  puts "   Debug Mode: #{debug_mode ? 'ON' : 'OFF'}"
  puts

  # Test API
  client = DustAPIClient.new(
    ENV.fetch('DUST_API_KEY', nil),
    ENV.fetch('DUST_WORKSPACE_ID', nil),
    ENV.fetch('DUST_AGENT_ID', nil),
    logger
  )

  success = client.test_connection

  puts "\n" + ('=' * 50)
  if success
    puts '🎉 SUCCESS! Dust API is working correctly.'
    puts '✅ Your configuration is ready for production use.'
  else
    puts '❌ FAILED! Please check your Dust API configuration.'
    puts '💡 Make sure your API key, workspace ID, and agent ID are correct.'
  end
  puts '=' * 50

  exit(success ? 0 : 1)
end

# Run the test
main if __FILE__ == $PROGRAM_NAME
