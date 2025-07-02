#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'
require 'net/http'
require 'json'
require 'octokit'
require 'logger'

# Base validator interface
class Validator
  def validate(config)
    raise NotImplementedError, 'Subclasses must implement #validate'
  end
end

# Basic configuration validator
class BasicConfigValidator < Validator
  def validate(config)
    errors = []
    errors << 'GITHUB_REPOSITORY environment variable is required' if config.repo.nil? || config.repo.empty?
    errors << 'PR_NUMBER must be a positive integer' if config.pr_number <= 0
    errors << 'GITHUB_TOKEN environment variable is required' if config.github_token.nil? || config.github_token.empty?
    errors << 'API_PROVIDER must be either "anthropic" or "dust"' unless %w[anthropic dust].include?(config.api_provider)
    errors
  end
end

# Anthropic-specific validator
class AnthropicConfigValidator < Validator
  def validate(config)
    return [] unless config.anthropic?

    errors = []
    if config.anthropic_api_key.nil? || config.anthropic_api_key.empty?
      errors << 'ANTHROPIC_API_KEY environment variable is required for Anthropic API'
    end
    errors
  end
end

# Dust-specific validator
class DustConfigValidator < Validator
  def validate(config)
    return [] unless config.dust?

    errors = []
    errors << 'DUST_API_KEY environment variable is required for Dust API' if config.dust_api_key.nil? || config.dust_api_key.empty?
    if config.dust_workspace_id.nil? || config.dust_workspace_id.empty?
      errors << 'DUST_WORKSPACE_ID environment variable is required for Dust API'
    end
    errors << 'DUST_AGENT_ID environment variable is required for Dust API' if config.dust_agent_id.nil? || config.dust_agent_id.empty?
    errors
  end
end

# Configuration validation service
class ConfigValidationService
  def initialize(validators = default_validators)
    @validators = validators
  end

  def validate(config)
    @validators.flat_map { |validator| validator.validate(config) }
  end

  private

  def default_validators
    [
      BasicConfigValidator.new,
      AnthropicConfigValidator.new,
      DustConfigValidator.new
    ]
  end
end

# Configuration value object for PR reviewer
class ReviewerConfig
  attr_reader :repo, :pr_number, :github_token, :api_provider, :anthropic_api_key, :dust_api_key, :dust_workspace_id, :dust_agent_id

  def initialize(env = ENV, validation_service = ConfigValidationService.new)
    @repo = env.fetch('GITHUB_REPOSITORY', nil)
    @pr_number = env.fetch('PR_NUMBER', '0').to_i
    @github_token = env.fetch('GITHUB_TOKEN', nil)
    @api_provider = env.fetch('API_PROVIDER', 'anthropic').downcase
    @anthropic_api_key = env.fetch('ANTHROPIC_API_KEY', nil)
    @dust_api_key = env.fetch('DUST_API_KEY', nil)
    @dust_workspace_id = env.fetch('DUST_WORKSPACE_ID', nil)
    @dust_agent_id = env.fetch('DUST_AGENT_ID', nil)
    @validation_service = validation_service
  end

  def valid?
    errors.empty?
  end

  def errors
    @validation_service.validate(self)
  end

  def anthropic?
    api_provider == 'anthropic'
  end

  def dust?
    api_provider == 'dust'
  end
end

# File reading service with security validation
class SecureFileReader
  ALLOWED_PREFIXES = ['doc/', 'reports/', '.github/scripts/'].freeze

  def initialize(logger)
    @logger = logger
  end

  def read_file(file_path, fallback = 'Not available.')
    validate_file_path!(file_path)
    return File.read(file_path) if File.exist?(file_path)

    @logger.warn "File not found: #{file_path}, using fallback"
    fallback
  rescue ArgumentError
    # Re-raise validation errors (security issues)
    raise
  rescue StandardError => e
    @logger.warn "Error reading file #{file_path}: #{e.message}, using fallback"
    fallback
  end

  private

  def validate_file_path!(file_path)
    raise ArgumentError, 'File path cannot be nil or empty' if file_path.nil? || file_path.empty?
    raise ArgumentError, 'File path cannot contain null bytes' if file_path.include?("\0")
    raise ArgumentError, 'File path cannot contain directory traversal patterns' if file_path.include?('..')

    return if ALLOWED_PREFIXES.any? { |prefix| file_path.start_with?(prefix) }

    raise ArgumentError, "File path must start with one of: #{ALLOWED_PREFIXES.join(', ')}"
  end
end

# Data gathering service
class ReviewDataGatherer
  def initialize(file_reader, github_client, logger)
    @file_reader = file_reader
    @github_client = github_client
    @logger = logger
  end

  def gather_data(config)
    @logger.info 'Gathering review data...'

    {
      guidelines: @file_reader.read_file('doc/CODING_STANDARDS.md'),
      rspec_results: @file_reader.read_file('reports/rspec.txt'),
      rubocop_results: @file_reader.read_file('reports/rubocop.txt'),
      brakeman_results: @file_reader.read_file('reports/brakeman.txt'),
      pr_diff: fetch_pr_diff(config),
      prompt_template: @file_reader.read_file('.github/scripts/pr_review_prompt_template.md')
    }
  end

  private

  def fetch_pr_diff(config)
    @logger.debug "Fetching PR diff for #{config.repo}##{config.pr_number}"

    @github_client.pull_request(
      config.repo,
      config.pr_number,
      accept: 'application/vnd.github.v3.diff'
    )
  rescue StandardError => e
    @logger.warn "Failed to fetch PR diff: #{e.message}"
    'PR diff not available.'
  end
end

# Prompt building service
class PromptBuilder
  def build_prompt(review_data)
    template = review_data[:prompt_template]

    template
      .gsub('{{guidelines}}', review_data[:guidelines])
      .gsub('{{rspec_results}}', review_data[:rspec_results])
      .gsub('{{rubocop_results}}', review_data[:rubocop_results])
      .gsub('{{brakeman_results}}', review_data[:brakeman_results])
      .gsub('{{pr_diff}}', review_data[:pr_diff])
  end
end

# Base AI provider interface
class AIProvider
  def initialize
    # Base initialization if needed
  end

  def request_review(prompt)
    raise NotImplementedError, 'Subclasses must implement #request_review'
  end

  def provider_name
    raise NotImplementedError, 'Subclasses must implement #provider_name'
  end
end

# HTTP client helper
class HTTPClient
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
    @logger.error "HTTP request timed out: #{e.message}"
    raise StandardError, "HTTP request timed out after #{@read_timeout} seconds"
  end

  def handle_response(response)
    unless response.code == '200'
      error_msg = "HTTP request failed with status #{response.code}: #{response.body}"
      @logger.error error_msg
      raise StandardError, error_msg
    end

    JSON.parse(response.body)
  rescue JSON::ParserError => e
    @logger.error "Failed to parse HTTP response: #{e.message}"
    raise StandardError, "Invalid JSON response: #{e.message}"
  end
end

# Anthropic AI provider
class AnthropicProvider < AIProvider
  API_VERSION = '2023-06-01'
  MODEL = 'claude-opus-4-20250514'
  MAX_TOKENS = 4096
  TEMPERATURE = 0.1

  def initialize(config, http_client, logger)
    super()
    @config = config
    @http_client = http_client
    @logger = logger
  end

  def request_review(prompt)
    @logger.info 'Requesting review from Anthropic Claude...'

    uri = URI('https://api.anthropic.com/v1/messages')
    headers = {
      'x-api-key' => @config.anthropic_api_key,
      'anthropic-version' => API_VERSION,
      'content-type' => 'application/json'
    }
    body = {
      model: MODEL,
      max_tokens: MAX_TOKENS,
      temperature: TEMPERATURE,
      messages: [{ role: 'user', content: prompt }]
    }.to_json

    @logger.debug 'Sending request to Anthropic API...'
    response = @http_client.post(uri, headers, body)
    extract_content(response)
  end

  def provider_name
    'Anthropic Claude'
  end

  private

  def extract_content(api_response)
    content = api_response.dig('content', 0, 'text')

    if content.nil? || content.empty?
      @logger.warn 'Anthropic returned empty review content'
      return 'Anthropic did not return a review. Please check the API response and try again.'
    end

    @logger.info 'Successfully received review from Anthropic Claude'
    content
  end
end

# Dust AI provider
class DustProvider < AIProvider
  API_BASE_URL = 'https://dust.tt'

  def initialize(config, http_client, logger)
    super()
    @config = config
    @http_client = http_client
    @logger = logger
  end

  def request_review(prompt)
    @logger.info 'Requesting review from Dust AI...'

    conversation = create_conversation(prompt)
    conversation_id = conversation.dig('conversation', 'sId')

    @logger.debug "Created Dust conversation: #{conversation_id}"
    get_response(conversation_id)
  end

  def provider_name
    'Dust AI'
  end

  private

  def create_conversation(prompt)
    uri = URI("#{API_BASE_URL}/api/v1/w/#{@config.dust_workspace_id}/assistant/conversations")
    headers = {
      'Authorization' => "Bearer #{@config.dust_api_key}",
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
        mentions: [{ configurationId: @config.dust_agent_id }]
      },
      blocking: true,
      streamGenerationEvents: false
    }.to_json

    @logger.debug "Creating Dust conversation with body: #{body}"
    @http_client.post(uri, headers, body)
  end

  def get_response(conversation_id)
    uri = URI("#{API_BASE_URL}/api/v1/w/#{@config.dust_workspace_id}/assistant/conversations/#{conversation_id}")
    headers = { 'Authorization' => "Bearer #{@config.dust_api_key}" }

    @logger.debug "Fetching Dust conversation: #{conversation_id}"
    response = @http_client.get(uri, headers)
    extract_content(response)
  end

  def extract_content(api_response)
    messages = api_response.dig('conversation', 'content')
    return 'Dust did not return a conversation. Please check the API response and try again.' if messages.nil? || messages.empty?

    agent_messages = messages.flatten.select { |msg| msg['type'] == 'agent_message' }

    if agent_messages.empty?
      @logger.warn 'Dust returned no agent messages'
      return 'Dust agent did not respond. Please check the agent configuration and try again.'
    end

    content = agent_messages.last['content']

    if content.nil? || content.empty?
      @logger.warn 'Dust agent returned empty content'
      return 'Dust agent returned an empty response. Please check the agent configuration and try again.'
    end

    @logger.info 'Successfully received review from Dust AI'
    content
  end
end

# AI provider factory
class AIProviderFactory
  def self.create(config, http_client, logger)
    case config.api_provider
    when 'anthropic'
      AnthropicProvider.new(config, http_client, logger)
    when 'dust'
      DustProvider.new(config, http_client, logger)
    else
      raise StandardError, "Unsupported API provider: #{config.api_provider}"
    end
  end
end

# GitHub comment service
class GitHubCommentService
  def initialize(github_client, logger)
    @github_client = github_client
    @logger = logger
  end

  def post_comment(config, content, provider_name)
    @logger.info 'Posting review comment to GitHub...'

    comment_body = format_comment(content, provider_name)
    @github_client.add_comment(config.repo, config.pr_number, comment_body)
    @logger.info 'Review comment posted successfully'
  rescue StandardError => e
    @logger.error "Failed to post GitHub comment: #{e.message}"
    raise StandardError, "GitHub comment posting failed: #{e.message}"
  end

  private

  def format_comment(content, provider_name)
    timestamp = Time.now.strftime('%Y-%m-%d %H:%M:%S UTC')

    <<~COMMENT
      #{content}

      ---
      *Review generated by #{provider_name} at #{timestamp}*
    COMMENT
  end
end

# Logger factory
class LoggerFactory
  def self.create(output = $stdout)
    logger = Logger.new(output)
    logger.level = ENV['DEBUG'] ? Logger::DEBUG : Logger::INFO
    logger.formatter = proc do |severity, datetime, _progname, msg|
      "[#{datetime.strftime('%Y-%m-%d %H:%M:%S')}] #{severity}: #{msg}\n"
    end
    logger
  end
end

# GitHub client factory
class GitHubClientFactory
  def self.create(config, timeouts = {})
    client = Octokit::Client.new(access_token: config.github_token)
    github_timeout = timeouts[:github_timeout] || 15
    http_timeout = timeouts[:http_timeout] || 30
    client.connection_options[:request] = { timeout: github_timeout, open_timeout: http_timeout }
    client
  end
end

# Main orchestrator class (follows Single Responsibility Principle)
class PullRequestReviewer
  def initialize(config = nil, dependencies = {})
    @config = config || ReviewerConfig.new
    @logger = dependencies[:logger] || LoggerFactory.create
    @github_client = dependencies[:github_client] || GitHubClientFactory.create(@config)
    @http_client = dependencies[:http_client] || HTTPClient.new(@logger)
    @file_reader = dependencies[:file_reader] || SecureFileReader.new(@logger)
    @data_gatherer = dependencies[:data_gatherer] || ReviewDataGatherer.new(@file_reader, @github_client, @logger)
    @prompt_builder = dependencies[:prompt_builder] || PromptBuilder.new
    @ai_provider = dependencies[:ai_provider] || AIProviderFactory.create(@config, @http_client, @logger)
    @comment_service = dependencies[:comment_service] || GitHubCommentService.new(@github_client, @logger)

    validate_configuration!
  end

  def run
    @logger.info "Starting PR review for repository: #{@config.repo}, PR: #{@config.pr_number}"
    @logger.info "Using API provider: #{@config.api_provider}"

    review_data = @data_gatherer.gather_data(@config)
    prompt = @prompt_builder.build_prompt(review_data)
    ai_response = @ai_provider.request_review(prompt)
    @comment_service.post_comment(@config, ai_response, @ai_provider.provider_name)

    @logger.info 'PR review completed successfully'
  rescue StandardError => e
    @logger.error "PR review failed: #{e.message}"
    @logger.debug e.backtrace.join("\n")
    raise
  end

  private

  def validate_configuration!
    return if @config.valid?

    @logger.error "Configuration validation failed: #{@config.errors.join(', ')}"
    raise ArgumentError, "Invalid configuration: #{@config.errors.join(', ')}"
  end
end

# Script execution
if __FILE__ == $PROGRAM_NAME
  begin
    reviewer = PullRequestReviewer.new
    reviewer.run
  rescue StandardError => e
    puts "Error: #{e.message}"
    exit 1
  end
end
