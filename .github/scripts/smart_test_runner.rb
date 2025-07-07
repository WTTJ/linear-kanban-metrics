#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'
require 'net/http'
require 'json'
require 'octokit'
require 'logger'
require 'fileutils'
require 'pathname'

# Configuration for the smart test runner
class SmartTestConfig
  attr_reader :repo, :pr_number, :commit_sha, :base_ref, :github_token,
              :api_provider, :anthropic_api_key, :dust_api_key, :dust_workspace_id, :dust_agent_id

  def initialize(env = ENV)
    @repo = env.fetch('GITHUB_REPOSITORY', nil)
    @pr_number = env.fetch('PR_NUMBER', '').to_i
    @commit_sha = env.fetch('COMMIT_SHA', nil)
    @base_ref = env.fetch('BASE_REF', 'main')
    @github_token = env.fetch('GITHUB_TOKEN', nil)
    @api_provider = env.fetch('API_PROVIDER', 'dust').downcase
    @anthropic_api_key = env.fetch('ANTHROPIC_API_KEY', nil)
    @dust_api_key = env.fetch('DUST_API_KEY', nil)
    @dust_workspace_id = env.fetch('DUST_WORKSPACE_ID', nil)
    @dust_agent_id = env.fetch('DUST_AGENT_ID', nil)&.strip
  end

  def valid?
    !github_token.nil? && !github_token.empty? &&
      (!anthropic? || (!anthropic_api_key.nil? && !anthropic_api_key.empty?)) &&
      (!dust? || (!dust_api_key.nil? && !dust_api_key.empty? && !dust_workspace_id.nil? && !dust_workspace_id.empty?))
  end

  def anthropic?
    api_provider == 'anthropic'
  end

  def dust?
    api_provider == 'dust'
  end

  def pr_mode?
    pr_number > 0
  end
end

# Service to analyze git changes and extract relevant information
class GitChangeAnalyzer
  attr_reader :logger

  def initialize(logger)
    @logger = logger
  end

  def analyze_changes(config)
    logger.info "🔍 Analyzing changes between #{config.base_ref} and #{config.commit_sha}"

    # Get the diff
    diff_output = if config.pr_mode?
                    get_pr_diff(config)
                  else
                    get_commit_diff(config)
                  end

    # Parse the diff to extract changed files and their changes
    changed_files = parse_diff_for_files(diff_output)

    {
      diff: diff_output,
      changed_files: changed_files,
      analysis: analyze_file_changes(changed_files)
    }
  rescue StandardError => e
    logger.error "Failed to analyze changes: #{e.message}"
    { diff: '', changed_files: [], analysis: {} }
  end

  private

  def get_pr_diff(config)
    github_client = Octokit::Client.new(access_token: config.github_token)
    github_client.pull_request(
      config.repo,
      config.pr_number,
      accept: 'application/vnd.github.v3.diff'
    )
  rescue StandardError => e
    logger.warn "Failed to fetch PR diff via GitHub API: #{e.message}, falling back to git"
    get_git_diff(config.base_ref, config.commit_sha)
  end

  def get_commit_diff(config)
    get_git_diff(config.base_ref, config.commit_sha)
  end

  def get_git_diff(base, head)
    `git diff --no-color #{base}...#{head}`.strip
  end

  def parse_diff_for_files(diff_output)
    changed_files = []
    current_file = nil

    diff_output.split("\n").each do |line|
      if line.start_with?('diff --git')
        # Extract filename from "diff --git a/path/to/file b/path/to/file"
        match = line.match(%r{diff --git a/(.*?) b/(.*)})
        current_file = match[2] if match
      elsif line.start_with?('+++') && current_file
        # Confirm the file path
        file_path = line.sub(%r{^\+\+\+ b/}, '').strip
        changed_files << {
          path: file_path,
          type: determine_file_type(file_path),
          changes: extract_changes_for_file(diff_output, file_path)
        }
      end
    end

    changed_files.uniq { |f| f[:path] }
  end

  def determine_file_type(file_path)
    case file_path
    when %r{^lib/.*\.rb$}
      :source
    when %r{^spec/.*_spec\.rb$}
      :test
    when %r{^\.github/}
      :github_config
    when /Gemfile|.*\.gemspec$/
      :dependency
    when /README|\.md$/
      :documentation
    else
      :other
    end
  end

  def extract_changes_for_file(diff_output, file_path)
    lines = diff_output.split("\n")
    file_diff_started = false
    changes = { added: [], removed: [], context: [] }

    lines.each do |line|
      if line.include?("b/#{file_path}")
        file_diff_started = true
        next
      end

      next unless file_diff_started
      break if line.start_with?('diff --git') && !line.include?(file_path)

      case line[0]
      when '+'
        changes[:added] << line[1..-1] unless line.start_with?('+++')
      when '-'
        changes[:removed] << line[1..-1] unless line.start_with?('---')
      when ' '
        changes[:context] << line[1..-1]
      end
    end

    changes
  end

  def analyze_file_changes(changed_files)
    {
      source_files: changed_files.select { |f| f[:type] == :source },
      test_files: changed_files.select { |f| f[:type] == :test },
      config_files: changed_files.select { |f| %i[github_config dependency].include?(f[:type]) },
      total_files: changed_files.size,
      has_source_changes: changed_files.any? { |f| f[:type] == :source },
      has_test_changes: changed_files.any? { |f| f[:type] == :test }
    }
  end
end

# Service to discover existing tests and their relationships
class TestDiscoveryService
  attr_reader :logger

  def initialize(logger)
    @logger = logger
  end

  def discover_tests
    logger.info '🔍 Discovering test files and their relationships...'

    test_files = Dir.glob('spec/**/*_spec.rb')
    source_files = Dir.glob('lib/**/*.rb')

    test_mapping = build_test_mapping(test_files, source_files)

    {
      test_files: test_files,
      source_files: source_files,
      test_mapping: test_mapping,
      reverse_mapping: build_reverse_mapping(test_mapping)
    }
  end

  private

  def build_test_mapping(test_files, source_files)
    mapping = {}

    test_files.each do |test_file|
      # Extract the likely source file path from test file path
      source_path = test_file
                    .gsub('spec/', 'lib/')
                    .gsub('_spec.rb', '.rb')

      if File.exist?(source_path)
        mapping[test_file] = [source_path]
      else
        # Try to find related files by analyzing test content
        related_files = find_related_files_by_content(test_file, source_files)
        mapping[test_file] = related_files
      end
    end

    mapping
  end

  def find_related_files_by_content(test_file, source_files)
    return [] unless File.exist?(test_file)

    test_content = File.read(test_file)
    related_files = []

    # Extract class/module names from the test
    test_content.scan(/describe\s+([A-Za-z:]+)/) do |match|
      class_name = match[0]
      # Convert class name to file path
      file_path = class_name_to_file_path(class_name)

      source_files.each do |source_file|
        related_files << source_file if source_file.end_with?(file_path) || source_file.include?(file_path)
      end
    end

    # Also look for require statements
    test_content.scan(/require.*['"]([^'"]+)['"]/) do |match|
      required_file = match[0]
      source_files.each do |source_file|
        related_files << source_file if source_file.include?(required_file) || source_file.end_with?("#{required_file}.rb")
      end
    end

    related_files.uniq
  end

  def class_name_to_file_path(class_name)
    # Convert CamelCase::ClassName to snake_case/class_name.rb
    class_name
      .gsub('::', '/')
      .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
      .gsub(/([a-z\d])([A-Z])/, '\1_\2')
      .downcase + '.rb'
  end

  def build_reverse_mapping(test_mapping)
    reverse = {}

    test_mapping.each do |test_file, source_files|
      source_files.each do |source_file|
        reverse[source_file] ||= []
        reverse[source_file] << test_file
      end
    end

    reverse
  end
end

# AI service for intelligent test selection
class AITestSelector
  attr_reader :config, :logger

  def initialize(config, logger)
    @config = config
    @logger = logger
  end

  def select_tests(changes, test_discovery)
    logger.info '🤖 Using AI to select relevant tests...'

    prompt = build_analysis_prompt(changes, test_discovery)
    ai_response = call_ai_service(prompt)

    parse_ai_response(ai_response, test_discovery[:test_files])
  end

  private

  def build_analysis_prompt(changes, test_discovery)
    changed_files_summary = changes[:changed_files].map do |file|
      "- #{file[:path]} (#{file[:type]}): #{file[:changes][:added].size} additions, #{file[:changes][:removed].size} deletions"
    end.join("\n")

    test_files_list = test_discovery[:test_files].map { |f| "- #{f}" }.join("\n")

    # Load prompt template from external file
    prompt_template = load_prompt_template

    # Replace placeholders with actual data
    prompt_template
      .gsub('{{changed_files_summary}}', changed_files_summary)
      .gsub('{{diff_content}}', changes[:diff])
      .gsub('{{test_files_list}}', test_files_list)
      .gsub('{{test_mapping}}', format_test_mapping(test_discovery[:test_mapping]))
  end

  def load_prompt_template
    prompt_file = File.join(File.dirname(__FILE__), 'smart_test_selection_prompt.md')

    if File.exist?(prompt_file)
      File.read(prompt_file)
    else
      logger.warn "Prompt template file not found: #{prompt_file}, using fallback"
      fallback_prompt_template
    end
  rescue StandardError => e
    logger.warn "Error loading prompt template: #{e.message}, using fallback"
    fallback_prompt_template
  end

  def fallback_prompt_template
    <<~PROMPT
      You are an expert Ruby developer analyzing code changes to determine which tests should be run.

      ## CODE CHANGES ANALYSIS
      The following files have been changed:
      {{changed_files_summary}}

      ## CHANGE DETAILS
      ```diff
      {{diff_content}}
      ```

      ## AVAILABLE TEST FILES
      {{test_files_list}}

      ## TEST-TO-SOURCE MAPPING
      {{test_mapping}}

      ## OUTPUT FORMAT
      Respond with a JSON object in this exact format:
      ```json
      {
        "selected_tests": ["spec/lib/example_spec.rb"],
        "reasoning": {
          "direct_tests": ["list of direct tests"],
          "indirect_tests": ["list of indirect tests"],
          "risk_level": "low|medium|high",
          "explanation": "Selection reasoning"
        }
      }
      ```
    PROMPT
  end

  def format_test_mapping(test_mapping)
    test_mapping.map do |test_file, source_files|
      "#{test_file} → #{source_files.join(', ')}"
    end.join("\n")
  end

  def call_ai_service(prompt)
    if config.anthropic?
      call_anthropic_api(prompt)
    elsif config.dust?
      call_dust_api(prompt)
    else
      raise "Unsupported AI provider: #{config.api_provider}"
    end
  end

  def call_anthropic_api(prompt)
    uri = URI('https://api.anthropic.com/v1/messages')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    request['x-api-key'] = config.anthropic_api_key
    request['anthropic-version'] = '2023-06-01'

    request.body = {
      model: 'claude-3-sonnet-20240229',
      max_tokens: 4000,
      messages: [
        {
          role: 'user',
          content: prompt
        }
      ]
    }.to_json

    response = http.request(request)

    if response.code == '200'
      JSON.parse(response.body)['content'][0]['text']
    else
      logger.error "Anthropic API error: #{response.code} - #{response.body}"
      generate_fallback_response
    end
  rescue StandardError => e
    logger.error "Error calling Anthropic API: #{e.message}"
    generate_fallback_response
  end

  def call_dust_api(_prompt)
    # Implementation for Dust API (if you're using it)
    # This would be similar to the existing PR review implementation
    logger.warn 'Dust API not implemented for test selection, using fallback'
    generate_fallback_response
  end

  def generate_fallback_response
    # Fallback to running all tests if AI fails
    {
      'selected_tests' => Dir.glob('spec/**/*_spec.rb'),
      'reasoning' => {
        'direct_tests' => [],
        'indirect_tests' => [],
        'risk_level' => 'high',
        'explanation' => 'AI analysis failed, running all tests as fallback'
      }
    }.to_json
  end

  def parse_ai_response(ai_response, available_tests)
    # Extract JSON from AI response
    json_match = ai_response.match(/```json\s*(.*?)\s*```/m)
    json_content = json_match ? json_match[1] : ai_response

    parsed = JSON.parse(json_content)

    # Validate that selected tests exist
    valid_tests = parsed['selected_tests'].select do |test_file|
      if available_tests.include?(test_file)
        true
      else
        logger.warn "AI selected non-existent test: #{test_file}"
        false
      end
    end

    {
      selected_tests: valid_tests,
      reasoning: parsed['reasoning'] || {}
    }
  rescue JSON::ParserError => e
    logger.error "Failed to parse AI response as JSON: #{e.message}"
    logger.debug "AI response was: #{ai_response}"

    # Fallback to all tests
    {
      selected_tests: available_tests,
      reasoning: {
        'risk_level' => 'high',
        'explanation' => 'Could not parse AI response, running all tests'
      }
    }
  end
end

# Main orchestrator class
class SmartTestRunner
  attr_reader :config, :logger

  def initialize(config = nil, logger = nil)
    @config = config || SmartTestConfig.new
    @logger = logger || Logger.new($stdout, level: Logger::INFO)
    setup_output_directory
  end

  def run
    logger.info '🚀 Starting Smart Test Runner'

    unless config.valid?
      logger.error '❌ Invalid configuration'
      exit(1)
    end

    # Analyze changes
    change_analyzer = GitChangeAnalyzer.new(logger)
    changes = change_analyzer.analyze_changes(config)

    if changes[:changed_files].empty?
      logger.info '✨ No relevant changes detected, skipping test selection'
      write_results([], {})
      return
    end

    # Discover tests
    test_discovery = TestDiscoveryService.new(logger).discover_tests

    # Select tests using AI
    ai_selector = AITestSelector.new(config, logger)
    selection_result = ai_selector.select_tests(changes, test_discovery)

    # Write results
    write_results(selection_result[:selected_tests], {
                    changes: changes,
                    selection_reasoning: selection_result[:reasoning],
                    test_discovery: test_discovery
                  })

    logger.info '✅ Smart test selection completed'
    logger.info "📊 Selected #{selection_result[:selected_tests].size} test files"
  end

  private

  def setup_output_directory
    FileUtils.mkdir_p('tmp')
  end

  def write_results(selected_tests, analysis_data)
    # Write selected tests for the workflow to use
    File.write('tmp/selected_tests.txt', selected_tests.join("\n"))

    # Write detailed analysis
    File.write('tmp/test_analysis.json', JSON.pretty_generate({
                                                                selected_tests: selected_tests,
                                                                total_available_tests: analysis_data.dig(:test_discovery,
                                                                                                         :test_files)&.size || 0,
                                                                selection_reasoning: analysis_data[:selection_reasoning],
                                                                changed_files: analysis_data.dig(:changes, :changed_files) || [],
                                                                timestamp: Time.now.iso8601
                                                              }))

    # Write human-readable analysis
    write_analysis_markdown(selected_tests, analysis_data)
  end

  def write_analysis_markdown(selected_tests, analysis_data)
    content = <<~MARKDOWN
      # 🤖 Smart Test Selection Analysis

      **Generated at:** #{Time.now.strftime('%Y-%m-%d %H:%M:%S UTC')}

      ## 📊 Summary
      - **Selected Tests:** #{selected_tests.size}
      - **Total Available Tests:** #{analysis_data.dig(:test_discovery, :test_files)&.size || 0}
      - **Changed Files:** #{analysis_data.dig(:changes, :changed_files)&.size || 0}
      - **Risk Level:** #{analysis_data.dig(:selection_reasoning, 'risk_level') || 'unknown'}

      ## 🔍 Selected Tests
      #{selected_tests.empty? ? '_No tests selected_' : selected_tests.map { |t| "- `#{t}`" }.join("\n")}

      ## 📝 Selection Reasoning
      #{analysis_data.dig(:selection_reasoning, 'explanation') || 'No reasoning provided'}

      ## 📂 Changed Files
      #{format_changed_files(analysis_data.dig(:changes, :changed_files) || [])}

      ## 🎯 Direct vs Indirect Tests
      - **Direct Tests:** #{Array(analysis_data.dig(:selection_reasoning, 'direct_tests')).join(', ')}
      - **Indirect Tests:** #{Array(analysis_data.dig(:selection_reasoning, 'indirect_tests')).join(', ')}
    MARKDOWN

    File.write('tmp/ai_analysis.md', content)
  end

  def format_changed_files(changed_files)
    return '_No files changed_' if changed_files.empty?

    changed_files.map do |file|
      "- `#{file[:path]}` (#{file[:type]}) - #{file[:changes][:added].size}+ / #{file[:changes][:removed].size}-"
    end.join("\n")
  end
end

# Script execution
SmartTestRunner.new.run if __FILE__ == $PROGRAM_NAME
