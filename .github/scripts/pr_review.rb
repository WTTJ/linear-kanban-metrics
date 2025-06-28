#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'
require 'net/http'
require 'json'
require 'octokit'
require 'logger'

# Configuration value object for PR reviewer
class ReviewerConfig
  attr_reader :repo, :pr_number, :anthropic_api_key, :github_token

  def initialize
    @repo = ENV.fetch('GITHUB_REPOSITORY', nil)
    @pr_number = ENV.fetch('PR_NUMBER', '0').to_i
    @anthropic_api_key = ENV.fetch('ANTHROPIC_API_KEY', nil)
    @github_token = ENV.fetch('GITHUB_TOKEN', nil)
  end

  def valid?
    errors.empty?
  end

  def errors
    validation_errors = []
    validation_errors << 'GITHUB_REPOSITORY environment variable is required' if repo.nil? || repo.empty?
    validation_errors << 'PR_NUMBER must be a positive integer' if pr_number <= 0
    validation_errors << 'ANTHROPIC_API_KEY environment variable is required' if anthropic_api_key.nil? || anthropic_api_key.empty?
    validation_errors << 'GITHUB_TOKEN environment variable is required' if github_token.nil? || github_token.empty?
    validation_errors
  end
end

# Main class for handling PR reviews with Claude Opus 4
# rubocop:disable Metrics/ClassLength
class PullRequestReviewer
  API_VERSION = '2023-06-01'
  CLAUDE_MODEL = 'claude-opus-4-20250514'
  MAX_TOKENS = 4096 # Increased for better review quality
  TEMPERATURE = 0.1 # Lower temperature for more consistent code reviews

  # Timeout configurations (in seconds)
  HTTP_TIMEOUT = 30 # Connection timeout
  READ_TIMEOUT = 120 # Read timeout for API response
  GITHUB_TIMEOUT = 15 # GitHub API timeout

  def initialize
    @logger = setup_logger
    @config = ReviewerConfig.new
    validate_configuration!
    @github = setup_github_client
  end

  def run
    @logger.info "Starting PR review for repository: #{@config.repo}, PR: #{@config.pr_number}"

    review_data = gather_review_data
    claude_response = request_claude_review(review_data)
    post_review_comment(claude_response)

    @logger.info 'PR review completed successfully'
  rescue StandardError => e
    @logger.error "PR review failed: #{e.message}"
    @logger.debug e.backtrace.join("\n")
    raise
  end

  private

  def setup_logger
    logger = Logger.new($stdout)
    logger.level = ENV['DEBUG'] ? Logger::DEBUG : Logger::INFO
    logger.formatter = proc do |severity, datetime, _progname, msg|
      "[#{datetime.strftime('%Y-%m-%d %H:%M:%S')}] #{severity}: #{msg}\n"
    end
    logger
  end

  def setup_github_client
    client = Octokit::Client.new(access_token: @config.github_token)
    client.connection_options[:request] = { timeout: GITHUB_TIMEOUT, open_timeout: HTTP_TIMEOUT }
    client
  end

  def validate_configuration!
    return if @config.valid?

    @logger.error "Configuration validation failed: #{@config.errors.join(', ')}"
    raise ArgumentError, "Invalid configuration: #{@config.errors.join(', ')}"
  end

  def gather_review_data
    @logger.info 'Gathering review data...'

    {
      guidelines: safe_read_file('doc/CODING_STANDARDS.md'),
      rspec_results: safe_read_file('reports/rspec.txt'),
      rubocop_results: safe_read_file('reports/rubocop.txt'),
      brakeman_results: safe_read_file('reports/brakeman.txt'),
      pr_diff: fetch_pr_diff,
      prompt_template: safe_read_file('.github/scripts/pr_review_prompt_template.md')
    }
  end

  def safe_read_file(file_path, fallback = 'Not available.')
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

  def validate_file_path!(file_path)
    # Prevent directory traversal attacks
    raise ArgumentError, 'File path cannot be nil or empty' if file_path.nil? || file_path.empty?
    raise ArgumentError, 'File path cannot contain null bytes' if file_path.include?("\0")
    raise ArgumentError, 'File path cannot contain directory traversal patterns' if file_path.include?('..')

    # Ensure file path is within allowed directories
    allowed_prefixes = ['doc/', 'reports/', '.github/scripts/']
    return if allowed_prefixes.any? { |prefix| file_path.start_with?(prefix) }

    raise ArgumentError, "File path must start with one of: #{allowed_prefixes.join(', ')}"
  end

  def fetch_pr_diff
    @logger.debug "Fetching PR diff for #{@config.repo}##{@config.pr_number}"

    @github.pull_request(
      @config.repo,
      @config.pr_number,
      accept: 'application/vnd.github.v3.diff'
    )
  rescue StandardError => e
    @logger.warn "Failed to fetch PR diff: #{e.message}"
    'PR diff not available.'
  end

  def build_claude_prompt(review_data)
    template = review_data[:prompt_template]

    # Replace template placeholders with actual data
    template
      .gsub('{{guidelines}}', review_data[:guidelines])
      .gsub('{{rspec_results}}', review_data[:rspec_results])
      .gsub('{{rubocop_results}}', review_data[:rubocop_results])
      .gsub('{{brakeman_results}}', review_data[:brakeman_results])
      .gsub('{{pr_diff}}', review_data[:pr_diff])
  end

  def request_claude_review(review_data)
    @logger.info 'Requesting review from Claude Opus 4...'

    prompt = build_claude_prompt(review_data)
    response = call_anthropic_api(prompt)

    extract_review_content(response)
  end

  def call_anthropic_api(prompt)
    uri = URI('https://api.anthropic.com/v1/messages')
    request = build_api_request(uri, prompt)

    @logger.debug 'Sending request to Anthropic API...'

    response = Net::HTTP.start(uri.hostname, uri.port,
                               use_ssl: true,
                               open_timeout: HTTP_TIMEOUT,
                               read_timeout: READ_TIMEOUT) do |http|
      http.request(request)
    end

    handle_api_response(response)
  rescue Net::OpenTimeout, Net::ReadTimeout => e
    @logger.error "Anthropic API request timed out: #{e.message}"
    raise StandardError, "API request timed out after #{READ_TIMEOUT} seconds"
  end

  def build_api_request(uri, prompt)
    request = Net::HTTP::Post.new(uri)
    request['x-api-key'] = @config.anthropic_api_key
    request['anthropic-version'] = API_VERSION
    request['content-type'] = 'application/json'

    request.body = {
      model: CLAUDE_MODEL,
      max_tokens: MAX_TOKENS,
      temperature: TEMPERATURE,
      messages: [{ role: 'user', content: prompt }]
    }.to_json

    request
  end

  def handle_api_response(response)
    unless response.code == '200'
      error_msg = "Anthropic API request failed with status #{response.code}: #{response.body}"
      @logger.error error_msg
      raise StandardError, error_msg
    end

    JSON.parse(response.body)
  rescue JSON::ParserError => e
    @logger.error "Failed to parse Anthropic API response: #{e.message}"
    raise StandardError, "Invalid JSON response from Anthropic API: #{e.message}"
  end

  def extract_review_content(api_response)
    content = api_response.dig('content', 0, 'text')

    if content.nil? || content.empty?
      @logger.warn 'Claude returned empty review content'
      return 'Claude did not return a review. Please check the API response and try again.'
    end

    @logger.info 'Successfully received review from Claude'
    content
  end

  def post_review_comment(review_content)
    @logger.info 'Posting review comment to GitHub...'

    comment_body = format_github_comment(review_content)

    @github.add_comment(@config.repo, @config.pr_number, comment_body)
    @logger.info 'Review comment posted successfully'
  rescue StandardError => e
    @logger.error "Failed to post GitHub comment: #{e.message}"
    raise StandardError, "GitHub comment posting failed: #{e.message}"
  end

  def format_github_comment(review_content)
    timestamp = Time.now.strftime('%Y-%m-%d %H:%M:%S UTC')

    <<~COMMENT
      #{review_content}

      ---
      *Review generated by Claude Opus 4 at #{timestamp}*
    COMMENT
  end
end
# rubocop:enable Metrics/ClassLength

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
