# frozen_string_literal: true

require 'net/http'
require 'json'
require 'logger'

# Shared HTTP client helper
class HTTPClient
  attr_reader :logger, :http_timeout, :read_timeout

  def initialize(logger, timeouts = {})
    @logger = logger
    @http_timeout = timeouts[:http_timeout] || 30
    @read_timeout = timeouts[:read_timeout] || 120
  end

  def post(uri, headers, body)
    request = Net::HTTP::Post.new(uri)
    headers.each { |key, value| request[key] = value }
    request.body = body

    make_request(uri, request)
  end

  def get(uri, headers)
    request = Net::HTTP::Get.new(uri)
    headers.each { |key, value| request[key] = value }

    make_request(uri, request)
  end

  private

  def make_request(uri, request)
    response = Net::HTTP.start(uri.hostname, uri.port,
                               use_ssl: true,
                               open_timeout: @http_timeout,
                               read_timeout: @read_timeout) do |http|
      http.request(request)
    end

    handle_response(response)
  rescue Net::OpenTimeout, Net::ReadTimeout => e
    logger.error "HTTP request timed out: #{e.message}"
    raise StandardError, "HTTP request timed out after #{@read_timeout} seconds"
  end

  def handle_response(response)
    unless response.code == '200'
      error_msg = "HTTP request failed with status #{response.code}: #{response.body}"
      logger.error error_msg
      raise StandardError, error_msg
    end

    JSON.parse(response.body)
  rescue JSON::ParserError => e
    logger.error "Failed to parse HTTP response: #{e.message}"
    raise StandardError, "Invalid JSON response: #{e.message}"
  end
end

# Base AI provider interface
class AIProvider
  def initialize
    # Base initialization if needed
  end

  def make_request(prompt)
    raise NotImplementedError, 'Subclasses must implement #make_request'
  end

  def provider_name
    raise NotImplementedError, 'Subclasses must implement #provider_name'
  end
end

# Anthropic AI provider
class AnthropicProvider < AIProvider
  API_VERSION = '2023-06-01'
  MODEL = 'claude-opus-4-20250514'
  MAX_TOKENS = 4096
  TEMPERATURE = 0.1

  attr_reader :api_key, :http_client, :logger

  def initialize(api_key, http_client, logger)
    super()
    @api_key = api_key
    @http_client = http_client
    @logger = logger
  end

  def make_request(prompt)
    logger.info 'Requesting response from Anthropic Claude...'

    uri = URI('https://api.anthropic.com/v1/messages')
    headers = {
      'x-api-key' => api_key,
      'anthropic-version' => API_VERSION,
      'content-type' => 'application/json'
    }
    body = {
      model: MODEL,
      max_tokens: MAX_TOKENS,
      temperature: TEMPERATURE,
      messages: [{ role: 'user', content: prompt }]
    }.to_json

    logger.debug 'Sending request to Anthropic API...'
    response = http_client.post(uri, headers, body)
    extract_content(response)
  end

  def provider_name
    'Anthropic Claude'
  end

  private

  def extract_content(api_response)
    content = api_response.dig('content', 0, 'text')

    if content.nil? || content.empty?
      logger.warn 'Anthropic returned empty content'
      return nil
    end

    logger.info 'Successfully received response from Anthropic Claude'
    content
  end
end

# Module for extracting messages from Dust API responses
module DustMessageExtractor
  def extract_messages_from_response(api_response)
    messages = api_response.dig('conversation', 'content')
    if messages.nil? || messages.empty?
      logger.warn "No conversation content found. API response keys: #{api_response.keys}"
      return nil
    end

    logger.debug "Found #{messages.length} messages in conversation"
    messages
  end

  def find_agent_messages(messages)
    # Handle different message structures
    all_messages = messages.is_a?(Array) ? messages.flatten : [messages]
    agent_messages = all_messages.select { |msg| msg&.dig('type') == 'agent_message' }

    logger.debug "Found #{agent_messages.length} agent messages"

    if agent_messages.empty?
      logger.warn "No agent messages found. All message types: #{all_messages.filter_map { |m| m&.dig('type') }.uniq}"
      return nil
    end

    agent_messages
  end
end

# Module for processing Dust API responses
module DustResponseProcessor
  include DustMessageExtractor

  def extract_content(api_response)
    @logger.debug "Full Dust API response: #{api_response.inspect}"

    messages = extract_messages_from_response(api_response)
    return nil if messages.nil?

    agent_messages = find_agent_messages(messages)
    return nil if agent_messages.nil?

    extract_final_content(agent_messages)
  end

  def extract_final_content(agent_messages)
    # Get the latest agent message content
    latest_message = agent_messages.last

    # Check if the agent message has succeeded status
    status = latest_message&.dig('status')
    logger.debug "Agent message status: #{status}"

    if status != 'succeeded'
      logger.warn "Agent message not ready, status: #{status || 'unknown'}"
      return 'retry_needed'
    end

    content = latest_message&.dig('content')

    logger.debug "Latest agent message content: #{content&.slice(0, 100)}..."

    if content.nil? || content.empty?
      logger.warn 'Dust agent returned empty content'
      return nil
    end

    logger.info 'Successfully received response from Dust AI'
    content
  end
end

# Dust AI provider
class DustProvider < AIProvider
  include DustResponseProcessor
  API_BASE_URL = 'https://dust.tt'

  attr_reader :api_key, :workspace_id, :agent_id, :http_client, :logger

  def initialize(api_key, workspace_id, agent_id, http_client, logger)
    super()
    @api_key = api_key
    @workspace_id = workspace_id
    @agent_id = agent_id
    @http_client = http_client
    @logger = logger
  end

  def make_request(prompt)
    logger.info 'Requesting response from Dust AI...'

    conversation = create_conversation(prompt)
    conversation_id = conversation.dig('conversation', 'sId')

    if conversation_id.nil?
      logger.error "Failed to create Dust conversation. Response: #{conversation.inspect}"
      return nil
    end

    logger.info "✅ Created Dust conversation: #{conversation_id}"
    conversation_uri = "#{API_BASE_URL}/api/v1/w/#{workspace_id}/assistant/conversations/#{conversation_id}"
    logger.info "🔗 Conversation URI: #{conversation_uri}"

    # Give the agent more time to process before fetching response
    initial_wait = ENV['GITHUB_ACTIONS'] ? 8 : 3
    logger.info "⏳ Waiting #{initial_wait} seconds for agent to process..."
    sleep(initial_wait)

    get_response_with_retries(conversation_id)
  end

  def provider_name
    'Dust AI'
  end

  private

  def create_conversation(prompt)
    uri = URI("#{API_BASE_URL}/api/v1/w/#{workspace_id}/assistant/conversations")
    headers = {
      'Authorization' => "Bearer #{api_key}",
      'Content-Type' => 'application/json'
    }

    body = {
      message: {
        content: prompt,
        context: {
          timezone: 'UTC',
          username: 'github-smart-test-runner',
          fullName: 'GitHub Smart Test Runner',
          origin: 'api'
        },
        mentions: [{ configurationId: agent_id }]
      },
      blocking: true,
      streamGenerationEvents: false
    }.to_json

    logger.debug "Creating Dust conversation with prompt length: #{prompt.length} chars"
    logger.debug "Agent ID: '#{agent_id}' (length: #{agent_id&.length})"
    http_client.post(uri, headers, body)
  end

  def get_response(conversation_id)
    uri = URI("#{API_BASE_URL}/api/v1/w/#{workspace_id}/assistant/conversations/#{conversation_id}")
    headers = { 'Authorization' => "Bearer #{api_key}" }

    logger.info "🔍 Fetching Dust conversation response: #{conversation_id}"
    response = http_client.get(uri, headers)
    extract_content(response)
  end

  def get_response_with_retries(conversation_id, max_retries = 5)
    retries = 0

    while retries < max_retries
      response = attempt_fetch_response(conversation_id, retries, max_retries)

      if response_is_valid?(response)
        logger.info "✅ Response validated successfully for conversation: #{conversation_id}"
        return response
      end

      logger.info "⏳ Response not valid, will retry. Response: '#{response.to_s[0..100]}...'"
      handle_retry_delay(retries, max_retries, conversation_id)
      retries += 1
    end

    logger.error "❌ Dust agent did not respond after #{max_retries} attempts (conversation: #{conversation_id})"
    conversation_uri = "#{API_BASE_URL}/api/v1/w/#{workspace_id}/assistant/conversations/#{conversation_id}"
    logger.error "🔗 Check conversation status at: #{conversation_uri}"
    nil
  end

  def attempt_fetch_response(conversation_id, retries, max_retries)
    logger.info "🔄 Attempting to fetch response (attempt #{retries + 1}/#{max_retries}) for conversation: #{conversation_id}"
    get_response(conversation_id)
  rescue StandardError => e
    logger.warn "⚠️ Error fetching response (attempt #{retries + 1}) for conversation #{conversation_id}: #{e.message}"
    raise e if retries >= max_retries - 1

    sleep(3)
    'retry_needed'
  end

  def response_is_valid?(response)
    return false if response.nil?
    return false if response == 'retry_needed'
    return false if response.to_s.strip.empty?

    logger.debug "Response validated as valid: length=#{response.to_s.length}"
    true
  end

  def handle_retry_delay(retries, max_retries, conversation_id)
    return unless retries < max_retries - 1

    wait_time = (retries + 1) * 5 # 5s, 10s, 15s, 20s
    logger.info "⏳ Agent hasn't responded yet, waiting #{wait_time} seconds before retry (conversation: #{conversation_id})..."
    sleep(wait_time)
  end
end

# AI provider factory
class AIProviderFactory
  def self.create(config, http_client, logger)
    case config.api_provider
    when 'anthropic'
      raise StandardError, 'Config object must respond to anthropic_api_key' unless config.respond_to?(:anthropic_api_key)

      AnthropicProvider.new(config.anthropic_api_key, http_client, logger)
    when 'dust'
      unless config.respond_to?(:dust_api_key) && config.respond_to?(:dust_workspace_id) && config.respond_to?(:dust_agent_id)
        raise StandardError, 'Config object must respond to dust_api_key, dust_workspace_id, and dust_agent_id'
      end

      DustProvider.new(config.dust_api_key, config.dust_workspace_id, config.dust_agent_id, http_client, logger)
    else
      raise StandardError, "Unsupported API provider: #{config.api_provider}"
    end
  end
end

# Shared logger factory
class SharedLoggerFactory
  def self.create(output = $stdout)
    logger = Logger.new(output)
    # Enable debug logging for troubleshooting
    logger.level = ENV['DEBUG'] ? Logger::DEBUG : Logger::INFO
    logger.formatter = proc do |severity, datetime, _progname, msg|
      "[#{datetime.strftime('%Y-%m-%d %H:%M:%S')}] #{severity}: #{msg}\n"
    end
    logger
  end
end
