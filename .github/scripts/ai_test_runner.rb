#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'
require 'net/http'
require 'json'
require 'octokit'
require 'logger'
require 'fileutils'
require 'pathname'
require 'open3'
require 'stringio'
require_relative 'shared/ai_services'

# Configuration for the AI test runner
class AITestConfig
  attr_reader :repo, :pr_number, :commit_sha, :base_ref, :github_token,
              :api_provider, :anthropic_api_key, :dust_api_key, :dust_workspace_id, :dust_agent_id

  def initialize(env = ENV)
    @repo = env.fetch('GITHUB_REPOSITORY', nil)
    @pr_number = env.fetch('PR_NUMBER', '').to_i
    @commit_sha = env.fetch('COMMIT_SHA', nil)
    @base_ref = env.fetch('BASE_REF', 'main')
    @github_token = env.fetch('GITHUB_TOKEN', nil)
    @api_provider = env.fetch('API_PROVIDER', 'anthropic').downcase
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
    pr_number.positive?
  end
end

# Configuration for diff processing limits and behavior
module DiffProcessingConfig
  # Diff size thresholds with rationale:
  # - LARGE_DIFF_THRESHOLD: 10MB is chosen as the point where git operations become noticeably slow
  #   and memory usage becomes a concern. This is based on typical CI environments with 2-4GB RAM.
  # - MEMORY_DIFF_THRESHOLD: 1MB threshold for switching to streaming mode to prevent memory spikes
  #   during line-by-line processing. Keeps memory usage under 100MB even for large changes.
  # - MAX_STREAMING_LINES: 100 lines limit for streaming mode balances between getting enough
  #   context for AI analysis while preventing excessive memory consumption on very large files.

  LARGE_DIFF_THRESHOLD = ENV.fetch('LARGE_DIFF_THRESHOLD', 10_000_000).to_i # 10MB default
  MEMORY_DIFF_THRESHOLD = ENV.fetch('MEMORY_DIFF_THRESHOLD', 1_000_000).to_i # 1MB default
  MAX_STREAMING_LINES = ENV.fetch('MAX_STREAMING_LINES', 100).to_i # 100 lines default

  def self.large_diff_threshold
    LARGE_DIFF_THRESHOLD
  end

  def self.memory_diff_threshold
    MEMORY_DIFF_THRESHOLD
  end

  def self.max_streaming_lines
    MAX_STREAMING_LINES
  end
end

# Service to parse git diffs efficiently for different file sizes
class DiffParser
  include DiffProcessingConfig

  attr_reader :logger

  def initialize(logger)
    @logger = logger
  end

  def parse_for_files(diff_output)
    # For very large diffs, use streaming to avoid loading everything into memory
    if diff_output.length > DiffProcessingConfig.memory_diff_threshold
      parse_streaming(diff_output)
    else
      parse_in_memory(diff_output)
    end
  end

  def extract_changes_for_file(diff_output, file_path)
    # For large diffs, limit change extraction to avoid memory issues
    if diff_output.length > DiffProcessingConfig.memory_diff_threshold
      extract_changes_streaming(diff_output, file_path)
    else
      extract_changes_in_memory(diff_output, file_path)
    end
  end

  private

  def parse_streaming(diff_output)
    changed_files = []
    current_file = nil

    # Use StringIO for streaming line-by-line processing
    io = StringIO.new(diff_output)

    io.each_line do |line|
      line = line.chomp # Remove newline without loading full diff

      if line.start_with?('diff --git')
        # Extract filename from "diff --git a/path/to/file b/path/to/file"
        match = line.match(%r{diff --git a/(.*?) b/(.*)})
        current_file = match[2] if match
      elsif line.start_with?('+++') && current_file
        # Confirm the file path
        file_path = line.sub(%r{^\+\+\+ b/}, '').strip
        # For streaming, we'll do a lightweight analysis without full change extraction
        changed_files << {
          path: file_path,
          type: FileTypeClassifier.determine_type(file_path),
          changes: { added: [], removed: [], context: [] } # Placeholder for large diffs
        }
      end
    end

    logger.info "Processed large diff with streaming (#{diff_output.length} bytes)"
    changed_files.uniq { |f| f[:path] }
  ensure
    io&.close
  end

  def parse_in_memory(diff_output)
    changed_files = []
    current_file = nil

    # Use StringIO for memory-efficient line processing instead of split("\n")
    io = StringIO.new(diff_output)

    io.each_line do |line|
      line = line.chomp # Remove newline without loading full diff

      if line.start_with?('diff --git')
        # Extract filename from "diff --git a/path/to/file b/path/to/file"
        match = line.match(%r{diff --git a/(.*?) b/(.*)})
        current_file = match[2] if match
      elsif line.start_with?('+++') && current_file
        # Confirm the file path
        file_path = line.sub(%r{^\+\+\+ b/}, '').strip
        changed_files << {
          path: file_path,
          type: FileTypeClassifier.determine_type(file_path),
          changes: extract_changes_for_file(diff_output, file_path)
        }
      end
    end

    changed_files.uniq { |f| f[:path] }
  ensure
    io&.close
  end

  def extract_changes_in_memory(diff_output, file_path)
    # Use StringIO for memory-efficient processing instead of split("\n")
    io = StringIO.new(diff_output)
    file_diff_started = false
    changes = { added: [], removed: [], context: [] }

    io.each_line do |line|
      line = line.chomp # Remove newline without loading full diff

      if line.include?("b/#{file_path}")
        file_diff_started = true
        next
      end

      next unless file_diff_started
      break if line.start_with?('diff --git') && !line.include?(file_path)

      case line[0]
      when '+'
        changes[:added] << line[1..] unless line.start_with?('+++')
      when '-'
        changes[:removed] << line[1..] unless line.start_with?('---')
      when ' '
        changes[:context] << line[1..]
      end
    end

    changes
  ensure
    io&.close
  end

  def extract_changes_streaming(diff_output, file_path)
    # For very large diffs, do lightweight extraction
    io = StringIO.new(diff_output)

    file_diff_started = false
    changes = { added: [], removed: [], context: [] }
    line_count = 0
    max_lines = DiffProcessingConfig.max_streaming_lines

    io.each_line do |line|
      line = line.chomp

      if line.include?("b/#{file_path}")
        file_diff_started = true
        next
      end

      next unless file_diff_started
      break if line.start_with?('diff --git') && !line.include?(file_path)
      break if line_count >= max_lines # Prevent excessive memory usage

      case line[0]
      when '+'
        changes[:added] << line[1..] unless line.start_with?('+++')
        line_count += 1
      when '-'
        changes[:removed] << line[1..] unless line.start_with?('---')
        line_count += 1
      when ' '
        changes[:context] << line[1..] if line_count < max_lines / 2 # Limit context
        line_count += 1
      end
    end

    changes
  ensure
    io&.close
  end
end

# Service to classify file types based on file paths and patterns
class FileTypeClassifier
  def self.determine_type(file_path)
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
end

# Service to analyze git changes and extract relevant information
class GitChangeAnalyzer
  attr_reader :logger, :diff_parser

  def initialize(logger)
    @logger = logger
    @diff_parser = DiffParser.new(logger)
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
    changed_files = diff_parser.parse_for_files(diff_output)

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
    # Use git diff with optimizations for large repositories
    cmd = [
      'git', 'diff', '--no-color',
      '--no-renames',           # Disable rename detection for performance
      '--diff-filter=ACMRT',    # Only show Added, Copied, Modified, Renamed, Type-changed files
      '--stat=1000',            # Limit stat output
      "#{base}...#{head}"
    ]

    stdout, stderr, status = Open3.capture3(*cmd)

    unless status.success?
      logger.error "Git diff command failed: #{stderr}"
      return ''
    end

    # Log diff size for monitoring
    diff_size = stdout.bytesize
    if diff_size > DiffProcessingConfig.large_diff_threshold
      logger.warn "Large diff detected: #{diff_size / 1_000_000}MB - using streaming mode"
    else
      logger.debug "Diff size: #{diff_size} bytes"
    end

    stdout.strip
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
  attr_reader :config, :logger, :ai_provider

  def initialize(config, logger)
    @config = config
    @logger = logger
    @ai_provider = create_ai_provider
  end

  def select_tests(changes, test_discovery)
    logger.info '🤖 Using AI to select relevant tests...'

    if ai_provider.nil?
      logger.warn 'AI provider not available, using fallback'
      return generate_fallback_selection(test_discovery[:test_files])
    end

    prompt = build_analysis_prompt(changes, test_discovery)
    ai_response = ai_provider.make_request(prompt)

    if ai_response.nil?
      logger.warn 'AI service returned no response, using fallback'
      return generate_fallback_selection(test_discovery[:test_files])
    end

    parse_ai_response(ai_response, test_discovery[:test_files])
  end

  private

  def create_ai_provider
    http_client = HTTPClient.new(logger)
    AIProviderFactory.create(config, http_client, logger)
  rescue StandardError => e
    logger.error "Failed to create AI provider: #{e.message}"
    nil
  end

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
    prompt_file = File.join(File.dirname(__FILE__), 'ai_test_runner_prompt.md')

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

  def generate_fallback_selection(available_tests)
    {
      selected_tests: available_tests,
      reasoning: {
        'direct_tests' => [],
        'indirect_tests' => [],
        'risk_level' => 'high',
        'explanation' => 'AI analysis failed, running all tests as fallback'
      }
    }
  end

  def parse_ai_response(ai_response, available_tests)
    return generate_fallback_selection(available_tests) if ai_response.nil?

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
    generate_fallback_selection(available_tests)
  end
end

# Main orchestrator class
class AITestRunner
  attr_reader :config, :logger

  def initialize(config = nil, logger = nil)
    @config = config || AITestConfig.new
    @logger = logger || SharedLoggerFactory.create
    setup_output_directory
  end

  def run
    logger.info '🚀 Starting AI Test Runner'

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

    logger.info '✅ AI test selection completed'
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
      # 🤖 AI Test Selection Analysis

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
AITestRunner.new.run if __FILE__ == $PROGRAM_NAME
