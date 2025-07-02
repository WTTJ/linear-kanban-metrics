#!/usr/bin/env ruby
# frozen_string_literal: true

# Simple Dust API test script
# Tests basic Dust API functionality using config/.env.test

require 'bundler/setup'
require 'net/http'
require 'json'

# Enhanced citation formatting module
module CitationFormatter
  def display_citations(citations)
    puts '📚 CITATIONS:'
    puts '-' * 30
    citations.each_with_index do |citation, index|
      puts "#{index + 1}. #{format_citation(citation)}"
    end
    puts '-' * 30
    puts
  end

  def format_citation(citation)
    # Handle different citation formats that Dust might return
    case citation
    when Hash
      format_hash_citation(citation)
    when String
      citation
    else
      citation.to_s
    end
  end

  def format_hash_citation(citation)
    # Handle Dust's various citation formats
    if citation['reference']
      format_reference_citation(citation)
    elsif citation['document']
      format_document_citation(citation)
    elsif citation['title'] || citation['url']
      format_basic_citation(citation)
    else
      citation.to_s
    end
  end

  def format_reference_citation(citation)
    ref = citation['reference']
    title = ref['title'] || 'Untitled'
    url = ref['href']

    if url
      "[#{title}](#{url})"
    else
      title
    end
  end

  def format_document_citation(citation)
    doc = citation['document']
    title = doc['title'] || doc['name'] || 'Document'
    url = doc['url'] || doc['href']

    if url
      "[#{title}](#{url})"
    else
      title
    end
  end

  def format_basic_citation(citation)
    title = citation['title'] || citation['name'] || 'Reference'
    url = citation['url'] || citation['href']
    snippet = citation['snippet'] || citation['text']

    parts = []
    if url
      parts << "[#{title}](#{url})"
    else
      parts << title
    end
    
    if snippet && snippet.length > 10
      # Add a snippet preview if available
      clean_snippet = snippet.strip.gsub(/\s+/, ' ')[0..100]
      parts << "\"#{clean_snippet}#{snippet.length > 100 ? '...' : ''}\""
    end

    parts.join(' - ')
  end

  def process_citation_markers(content, citations)
    # Create a citation map for lookup
    citation_map = {}
    citations.each_with_index do |citation, index|
      # Dust citations usually have an 'id' field
      if citation.is_a?(Hash) && citation['id']
        citation_map[citation['id']] = index + 1
      end
    end

    # Replace :cite[id] markers with numbered references [1], [2], etc.
    content.gsub(/:cite\[([^\]]+)\]/) do |match|
      cite_id = Regexp.last_match(1)
      if citation_map[cite_id]
        "[#{citation_map[cite_id]}]"
      else
        # If citation ID not found, keep the original marker but make it more visible
        "**#{match}**"
      end
    end
  end
end

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
  include CitationFormatter

  API_BASE_URL = 'https://dust.tt'

  def initialize(api_key, workspace_id, agent_id, logger)
    @api_key = api_key
    @workspace_id = workspace_id
    @agent_id = agent_id
    @logger = logger
  end

  def test_connection
    @logger.info '🔌 Testing Dust API connection...'

    prompt = create_test_prompt
    conversation = create_conversation(prompt)
    conversation_id = conversation.dig('conversation', 'sId')

    return handle_failed_conversation_creation unless conversation_id

    @logger.info "✅ Conversation created: #{conversation_id}"
    sleep(3) # Wait for processing

    response = get_response_with_retries(conversation_id)
    evaluate_test_response(response)
  rescue StandardError => e
    @logger.error "❌ API test failed: #{e.message}"
    false
  end

  def create_test_prompt
    "# PR Review Test\n\nYou are a senior Ruby developer reviewing code. This is a test message to verify the API integration is working.\n\n## Code Changes\n```ruby\nclass TestClass\n  def initialize\n    @test = 'value'\n  end\nend\n```\n\nPlease provide a brief review of this code and confirm the API connection is working."
  end

  # rubocop:disable Naming/PredicateMethod
  def handle_failed_conversation_creation
    @logger.error '❌ Failed to create conversation'
    false
  end

  def evaluate_test_response(response)
    # rubocop:enable Naming/PredicateMethod
    if response_valid?(response)
      display_successful_response(response)
      true
    else
      handle_response_failure(response)
      false
    end
  end

  def response_valid?(response)
    return false unless response.is_a?(Hash)

    content = response[:content] || response['content']
    content && !content.empty? && !content.include?('did not respond')
  end

  def display_successful_response(response)
    @logger.info '✅ Response received!'
    puts "\n#{'=' * 60}"
    puts '🤖 DUST AI RESPONSE:'
    puts '=' * 60
    puts

    # Extract content and citations
    content = response[:content] || response['content']
    citations = response[:citations] || response['citations'] || []

    # Process citation markers in content
    processed_content = citations.any? ? process_citation_markers(content, citations) : content

    # Display the main content
    puts processed_content
    puts

    # Display citations if present
    display_citations(citations) if citations.any?

    puts '=' * 60
    puts "📏 Response length: #{content.length} characters"
    puts "📏 Processed length: #{processed_content.length} characters"
    puts "📚 Citations found: #{citations.length}" if citations.any?
  end

  def handle_response_failure(response)
    @logger.error '❌ No response received from agent'

    case response
    when Hash
      content = response[:content] || response['content']
      @logger.error "Response content: #{content}" if content
    when String
      @logger.error "Response content: #{response}"
    else
      @logger.error "Unexpected response type: #{response.class}"
    end
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

    messages = extract_messages(response)
    return nil if messages.nil? || messages.empty?

    find_agent_response(messages)
  end

  def extract_messages(response)
    messages = response.dig('conversation', 'content')
    if messages.nil? || messages.empty?
      @logger.debug "No conversation content found. API response keys: #{response.keys}"
      return nil
    end

    @logger.debug "Found #{messages.length} messages in conversation"
    messages
  end

  def find_agent_response(messages)
    all_messages = messages.is_a?(Array) ? messages.flatten : [messages]
    agent_messages = all_messages.select { |msg| msg&.dig('type') == 'agent_message' }

    @logger.debug "Found #{agent_messages.length} agent messages"

    if agent_messages.empty?
      @logger.debug "No agent messages found. All message types: #{all_messages.filter_map { |m| m&.dig('type') }.uniq}"
      return nil
    end

    extract_message_content(agent_messages.last)
  end

  def extract_message_content(message)
    content = message&.dig('content')
    citations = message&.dig('citations') || []

    @logger.debug "Latest agent message content: #{content&.slice(0, 100)}..." if content
    @logger.debug "Found #{citations.length} citations" if citations.any?

    # Return both content and citations
    {
      content: content,
      citations: citations
    }
  end

  # Add retry logic similar to PR review script
  def get_response_with_retries(conversation_id, max_retries = 3)
    retries = 0

    while retries < max_retries
      response = attempt_get_response(conversation_id, retries, max_retries)
      return response if response_has_content?(response)

      handle_retry_wait(retries, max_retries)
      retries += 1
    end

    create_no_response_result(max_retries)
  end

  def attempt_get_response(conversation_id, retries, max_retries)
    @logger.debug "Attempting to fetch response (attempt #{retries + 1}/#{max_retries})"
    response = get_response(conversation_id)

    if response_has_content?(response)
      @logger.debug 'Received valid response with content'
      return response
    end

    response
  rescue StandardError => e
    @logger.error "Error fetching response (attempt #{retries + 1}): #{e.message}"
    sleep(2) if retries < max_retries - 1
    nil
  end

  def handle_retry_wait(retries, max_retries)
    return unless retries < max_retries - 1

    wait_time = (retries + 1) * 3 # Progressive backoff: 3s, 6s, 9s
    @logger.debug "Agent hasn't responded yet, waiting #{wait_time} seconds before retry..."
    sleep(wait_time)
  end

  def create_no_response_result(max_retries)
    @logger.error "Agent did not respond after #{max_retries} attempts"
    {
      content: 'Dust agent did not respond after multiple attempts. The agent may be busy or misconfigured.',
      citations: []
    }
  end

  def response_has_content?(response)
    return false unless response.is_a?(Hash)

    content = response[:content] || response['content']
    content && !content.empty? && !content.strip.empty?
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
  def initialize(debug: false)
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

  load_env_file

  return exit_with_missing_vars unless ensure_required_variables

  display_configuration
  client = create_client
  success = client.test_connection

  display_final_result(success)
  exit(success ? 0 : 1)
end

# rubocop:disable Naming/PredicateMethod
def ensure_required_variables
  required_vars = %w[DUST_API_KEY DUST_WORKSPACE_ID DUST_AGENT_ID]
  missing_vars = required_vars.select { |var| ENV[var].nil? || ENV[var].empty? }

  return true if missing_vars.empty?

  display_missing_vars_error(missing_vars)
  false
end
# rubocop:enable Naming/PredicateMethod

def exit_with_missing_vars
  puts '❌ Missing required environment variables.'
  exit 1
end

def display_missing_vars_error(missing_vars)
  puts '❌ Missing required environment variables in config/.env.test:'
  missing_vars.each { |var| puts "   - #{var}" }
  puts "\nPlease add these to your config/.env.test file:"
  puts 'DUST_API_KEY=your_api_key_here'
  puts 'DUST_WORKSPACE_ID=your_workspace_id_here'
  puts 'DUST_AGENT_ID=your_agent_id_here'
end

def display_configuration
  puts '✅ Configuration loaded:'
  puts "   Workspace ID: #{ENV.fetch('DUST_WORKSPACE_ID', nil)}"
  puts "   Agent ID: #{ENV.fetch('DUST_AGENT_ID', nil)}"
  puts "   API Key: #{mask_api_key(ENV.fetch('DUST_API_KEY', nil))}"

  debug_mode = ENV['DEBUG'] == 'true'
  puts "   Debug Mode: #{debug_mode ? 'ON' : 'OFF'}"
  puts
end

def mask_api_key(api_key)
  return 'Not set' if api_key.nil? || api_key.empty?

  # Only show last 4 characters for identification, mask the rest
  return '****' if api_key.length <= 4

  "****#{api_key[-4..]}"
end

def create_client
  debug_mode = ENV['DEBUG'] == 'true'
  logger = SimpleLogger.new(debug: debug_mode)

  DustAPIClient.new(
    ENV.fetch('DUST_API_KEY', nil),
    ENV.fetch('DUST_WORKSPACE_ID', nil),
    ENV.fetch('DUST_AGENT_ID', nil),
    logger
  )
end

def display_final_result(success)
  puts "\n#{'=' * 50}"
  if success
    puts '🎉 SUCCESS! Dust API is working correctly.'
    puts '✅ Your configuration is ready for production use.'
  else
    puts '❌ FAILED! Please check your Dust API configuration.'
    puts '💡 Make sure your API key, workspace ID, and agent ID are correct.'
  end
  puts '=' * 50
end

# Run the test
main if __FILE__ == $PROGRAM_NAME
