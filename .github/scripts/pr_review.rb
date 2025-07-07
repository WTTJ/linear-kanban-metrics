#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'
require 'net/http'
require 'json'
require 'octokit'
require 'logger'
require_relative 'shared/ai_services'

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
  attr_reader :validators

  def initialize(validators = default_validators)
    @validators = validators
  end

  def validate(config)
    validators.flat_map { |validator| validator.validate(config) }
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
  attr_reader :repo, :pr_number, :github_token, :api_provider, :anthropic_api_key, :dust_api_key, :dust_workspace_id, :dust_agent_id,
              :validation_service

  def initialize(env = ENV, validation_service = ConfigValidationService.new)
    @repo = env.fetch('GITHUB_REPOSITORY', nil)
    @pr_number = env.fetch('PR_NUMBER', '0').to_i
    @github_token = env.fetch('GITHUB_TOKEN', nil)
    @api_provider = env.fetch('API_PROVIDER', 'anthropic').downcase
    @anthropic_api_key = env.fetch('ANTHROPIC_API_KEY', nil)
    @dust_api_key = env.fetch('DUST_API_KEY', nil)
    @dust_workspace_id = env.fetch('DUST_WORKSPACE_ID', nil)
    @dust_agent_id = env.fetch('DUST_AGENT_ID', nil)&.strip # Strip whitespace
    @validation_service = validation_service
  end

  def valid?
    errors.empty?
  end

  def errors
    validation_service.validate(self)
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

  attr_reader :logger

  def initialize(logger)
    @logger = logger
  end

  def read_file(file_path, fallback = 'Not available.')
    validate_file_path!(file_path)
    return File.read(file_path) if File.exist?(file_path)

    logger.warn "File not found: #{file_path}, using fallback"
    fallback
  rescue ArgumentError
    # Re-raise validation errors (security issues)
    raise
  rescue StandardError => e
    logger.warn "Error reading file #{file_path}: #{e.message}, using fallback"
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
  attr_reader :file_reader, :github_client, :logger

  def initialize(file_reader, github_client, logger)
    @file_reader = file_reader
    @github_client = github_client
    @logger = logger
  end

  def gather_data(config)
    logger.info 'Gathering review data...'

    {
      guidelines: file_reader.read_file('doc/CODING_STANDARDS.md'),
      rspec_results: file_reader.read_file('reports/rspec.txt'),
      rubocop_results: file_reader.read_file('reports/rubocop.txt'),
      brakeman_results: file_reader.read_file('reports/brakeman.txt'),
      pr_diff: fetch_pr_diff(config),
      prompt_template: file_reader.read_file('.github/scripts/pr_review_prompt_template.md')
    }
  end

  private

  def fetch_pr_diff(config)
    logger.debug "Fetching PR diff for #{config.repo}##{config.pr_number}"

    github_client.pull_request(
      config.repo,
      config.pr_number,
      accept: 'application/vnd.github.v3.diff'
    )
  rescue StandardError => e
    logger.warn "Failed to fetch PR diff: #{e.message}"
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





# Module for extracting messages from Dust API responses
module DustMessageExtractor
  def extract_messages_from_response(api_response)
    messages = api_response.dig('conversation', 'content')
    if messages.nil? || messages.empty?
      logger.warn "No conversation content found. API response keys: #{api_response.keys}"
      return 'Dust did not return a conversation. Please check the API response and try again.'
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
      return 'Dust agent did not respond. Please check the agent configuration and try again.'
    end

    agent_messages
  end
end

# Module for processing Dust citations
module DustCitationProcessor
  def format_response_with_citations(content, citations)
    # Strategy: Map citation markers sequentially to available citations
    # Since Dust citation IDs in content rarely match API citation metadata,
    # we'll use positional mapping based on order of appearance

    if citations.any?
      formatted_content = replace_citation_markers_sequential(content, citations)
      formatted_content = add_reference_list(formatted_content, citations)
    else
      # No citations available, mark all citation markers as unresolved
      formatted_content = mark_unresolved_citations(content)
    end

    formatted_content
  end

  def replace_citation_markers_sequential(content, citations)
    # Extract all unique citation markers in order of appearance
    citation_markers = extract_unique_citation_markers(content)
    return content if citation_markers.empty?

    # Create sequential mapping: each unique marker gets next available citation
    marker_to_reference = build_sequential_mapping(citation_markers, citations)
    logger.debug "Citation marker to reference mapping: #{marker_to_reference.inspect}"

    replace_markers_with_sequential_references(content, marker_to_reference)
  end

  def extract_unique_citation_markers(content)
    # Find all citation markers and track unique ones in order of first appearance
    # Handle both single markers like :cite[pf] and comma-separated like :cite[cc,1f]
    unique_markers = []
    content.scan(/:cite\[([^\]]+)\]/) do |match|
      marker_content = match.first.strip

      # Check if this is a comma-separated list
      if marker_content.include?(',')
        # Split comma-separated markers and add each unique one
        marker_content.split(',').map(&:strip).each do |individual_marker|
          unique_markers << individual_marker unless unique_markers.include?(individual_marker)
        end
      else
        # Single marker
        unique_markers << marker_content unless unique_markers.include?(marker_content)
      end
    end
    unique_markers
  end

  def build_sequential_mapping(citation_markers, citations)
    # Map each unique citation marker to sequential reference numbers
    # This handles the case where Dust citation IDs don't match content markers
    marker_to_reference = {}
    citation_markers.each_with_index do |marker, index|
      marker_to_reference[marker] = index + 1 if index < citations.length
    end
    marker_to_reference
  end

  def replace_markers_with_sequential_references(content, marker_to_reference)
    content.gsub(/:cite\[([^\]]+)\]/) do |match|
      marker_content = Regexp.last_match(1).strip

      # Handle comma-separated citation IDs
      if marker_content.include?(',')
        # Split and map each individual citation ID
        individual_markers = marker_content.split(',').map(&:strip)
        references = individual_markers.filter_map { |marker| marker_to_reference[marker] }

        if references.any?
          if references.length == 1
            "<sup>[#{references.first}](#ref-#{references.first})</sup>"
          else
            ref_links = references.map { |ref| "[#{ref}](#ref-#{ref})" }
            "<sup>#{ref_links.join(',')}</sup>"
          end
        else
          "**#{match}**"
        end
      else
        # Single citation ID
        reference_number = marker_to_reference[marker_content]

        if reference_number
          "<sup>[#{reference_number}](#ref-#{reference_number})</sup>"
        else
          "**#{match}**"
        end
      end
    end
  end

  def mark_unresolved_citations(content)
    # When no citations are available, mark all citation markers as unresolved
    content.gsub(/:cite\[([^\]]+)\]/, '**:cite[\1]**')
  end

  def add_reference_list(content, citations)
    return content if citations.empty?

    references = citations.map.with_index do |citation, index|
      ref_number = index + 1
      "<a id=\"ref-#{ref_number}\"></a>#{ref_number}. #{format_citation(citation)}\n\n"
    end.join

    "#{content}\n\n---\n\n**References:**\n\n#{references}"
  end

  def format_citation(citation)
    case citation
    when Hash
      format_hash_citation(citation)
    when String
      citation
    else
      citation.to_s
    end
  end

  private

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
    parts << if url
               "[#{title}](#{url})"
             else
               title
             end

    if snippet && snippet.length > 10
      # Add a snippet preview if available
      clean_snippet = snippet.strip.gsub(/\s+/, ' ')[0..100]
      parts << "\"#{clean_snippet}#{'...' if snippet.length > 100}\""
    end

    parts.join(' - ')
  end
end

# Module for processing Dust API responses
module DustResponseProcessor
  include DustMessageExtractor
  include DustCitationProcessor

  def extract_content(api_response)
    @logger.debug "Full Dust API response: #{api_response.inspect}"

    messages = extract_messages_from_response(api_response)
    return messages if messages.is_a?(String) # Error message

    agent_messages = find_agent_messages(messages)
    return agent_messages if agent_messages.is_a?(String) # Error message

    extract_final_content_with_citations(agent_messages)
  end

  def extract_final_content_with_citations(agent_messages)
    # Get the latest agent message content and citations
    latest_message = agent_messages.last

    # Check if the agent message has succeeded status
    status = latest_message&.dig('status')
    logger.debug "Agent message status: #{status}"

    if status != 'succeeded'
      logger.warn "Agent message not ready, status: #{status || 'unknown'}"
      return 'retry_needed'
    end

    content = latest_message&.dig('content')
    
    # Try to extract citations from both possible structures
    citations = extract_citations_from_actions(latest_message)
    
    # Fallback to legacy citations structure if no actions citations found
    if citations.empty?
      legacy_citations = latest_message&.dig('citations') || []
      citations = legacy_citations if legacy_citations.any?
    end

    logger.debug "Latest agent message content: #{content&.slice(0, 100)}..."
    logger.debug "Found #{citations.length} citations" if citations.any?

    if content.nil? || content.empty?
      logger.warn 'Dust agent returned empty content'
      return 'Dust agent returned an empty response. Please check the agent configuration and try again.'
    end

    logger.info 'Successfully received review from Dust AI'

    # Return content with citations metadata if available
    if citations.any?
      format_response_with_citations(content, citations)
    else
      content
    end
  end

  private

  def extract_citations_from_actions(agent_message)
    actions = agent_message&.dig('actions') || []
    citations = []

    actions.each do |action|
      next unless action&.dig('type') == 'tool_action'
      
      output = action&.dig('output') || []
      output.each do |item|
        next unless item&.dig('type') == 'resource'
        
        resource = item&.dig('resource')
        next unless resource&.dig('reference')
        
        # Convert Dust resource format to our expected citation format
        citations << {
          'id' => resource['reference'],
          'reference' => {
            'title' => resource['title'],
            'href' => resource['uri']
          }
        }
      end
    end

    logger.debug "Extracted #{citations.length} citations from actions"
    citations
  end
end

# GitHub comment service
class GitHubCommentService
  attr_reader :github_client, :logger

  def initialize(github_client, logger)
    @github_client = github_client
    @logger = logger
  end

  def post_comment(config, content, provider_name)
    logger.info 'Posting review comment to GitHub...'

    comment_body = format_comment(content, provider_name)
    github_client.add_comment(config.repo, config.pr_number, comment_body)
    logger.info 'Review comment posted successfully'
  rescue StandardError => e
    logger.error "Failed to post GitHub comment: #{e.message}"
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

# Main orchestrator class (follows Single Responsibility Principle)
class PullRequestReviewer
  attr_reader :config, :logger, :github_client, :http_client, :file_reader,
              :data_gatherer, :prompt_builder, :ai_provider, :comment_service

  def initialize(config = nil, dependencies = {})
    @config = config || ReviewerConfig.new
    @logger = dependencies[:logger] || SharedLoggerFactory.create
    @github_client = dependencies[:github_client] || create_github_client(@config)
    @http_client = dependencies[:http_client] || HTTPClient.new(@logger)
    @file_reader = dependencies[:file_reader] || SecureFileReader.new(@logger)
    @data_gatherer = dependencies[:data_gatherer] || ReviewDataGatherer.new(@file_reader, @github_client, @logger)
    @prompt_builder = dependencies[:prompt_builder] || PromptBuilder.new
    @ai_provider = dependencies[:ai_provider] || AIProviderFactory.create(@config, @http_client, @logger)
    @comment_service = dependencies[:comment_service] || GitHubCommentService.new(@github_client, @logger)

    validate_configuration!
  end

  def run
    logger.info "Starting PR review for repository: #{config.repo}, PR: #{config.pr_number}"
    logger.info "Using API provider: #{config.api_provider}"

    review_data = data_gatherer.gather_data(config)
    prompt = prompt_builder.build_prompt(review_data)
    ai_response = ai_provider.make_request(prompt)
    comment_service.post_comment(config, ai_response, ai_provider.provider_name)

    logger.info 'PR review completed successfully'
  rescue StandardError => e
    logger.error "PR review failed: #{e.message}"
    logger.debug e.backtrace.join("\n")
    raise
  end

  private

  def validate_configuration!
    return if config.valid?

    logger.error "Configuration validation failed: #{config.errors.join(', ')}"
    raise ArgumentError, "Invalid configuration: #{config.errors.join(', ')}"
  end

  def create_github_client(config, timeouts = {})
    client = Octokit::Client.new(access_token: config.github_token)
    github_timeout = timeouts[:github_timeout] || 15
    http_timeout = timeouts[:http_timeout] || 30
    client.connection_options[:request] = { timeout: github_timeout, open_timeout: http_timeout }
    client
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
