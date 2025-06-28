#!/usr/bin/env ruby
# frozen_string_literal: true

#
# Run RSpec tests for files changed in a PR or branch
#
# Usage:
#   ./scripts/run_pr_tests.rb [base_branch] [--help]
#
# Examples:
#   ./scripts/run_pr_tests.rb              # Compare against main
#   ./scripts/run_pr_tests.rb develop      # Compare against develop
#   ./sripts/run_pr_tests.rb origin/main   # Compare against origin/main
#

require 'optparse'
require 'shellwords'
require 'English'
require 'open3'

module Scripts
  # Custom exceptions for better error handling with context
  class TestRunnerError < StandardError
    attr_reader :context

    def initialize(message, context: {})
      super(message)
      @context = context
    end
  end

  class GitRepositoryError < TestRunnerError; end
  class CommandNotFoundError < TestRunnerError; end
  class TestFailureError < TestRunnerError; end
  class ArgumentParsingError < TestRunnerError; end

  # Value object for script configuration with validation
  class Configuration
    attr_reader :base_branch, :debug_mode

    DEFAULT_BASE_BRANCH = 'main'
    private_constant :DEFAULT_BASE_BRANCH

    def initialize(base_branch: DEFAULT_BASE_BRANCH, debug_mode: false)
      @base_branch = validate_branch_name!(base_branch)
      @debug_mode = debug_mode
      freeze
    end

    def debug?
      @debug_mode
    end

    private

    def validate_branch_name!(branch_name)
      return branch_name if branch_name.is_a?(String) && !branch_name.strip.empty?

      raise ArgumentParsingError.new(
        'Branch name must be a non-empty string',
        context: { provided_value: branch_name }
      )
    end
  end

  # Color constants for terminal output
  module Colors
    GREEN = "\033[0;32m"
    YELLOW = "\033[1;33m"
    RED = "\033[0;31m"
    BLUE = "\033[0;34m"
    RESET = "\033[0m"

    def self.colorize(text, color)
      "#{color}#{text}#{RESET}"
    end
  end

  # Helper module for git operations following SRP with enhanced error handling
  module GitOperations
    class << self
      def current_branch
        branch = execute_git_command(['git', 'branch', '--show-current'])
        branch.empty? ? 'HEAD' : branch
      end

      def branch_exists?(branch_name)
        return false if branch_name.nil? || branch_name.strip.empty?

        command = ['git', 'rev-parse', '--verify', branch_name]
        _, _, status = Open3.capture3(*command, stdin_data: '', err: File::NULL)
        status.success?
      end

      def diff_files(diff_args)
        command = build_diff_command(diff_args)
        output = execute_git_command(command)

        return [] if output.empty?

        parse_diff_output(output)
      end

      def repository_exists?
        command = ['git', 'rev-parse', '--git-dir']
        _, _, status = Open3.capture3(*command, stdin_data: '', err: File::NULL)
        status.success?
      end

      private

      def execute_git_command(command_array)
        stdout, stderr, status = Open3.capture3(*command_array, stdin_data: '')
        return stdout.strip if status.success?

        warn_about_git_error(command_array, stderr) if status.exitstatus != 0
        ''
      end

      def warn_about_git_error(command, stderr)
        return if stderr.strip.empty?

        warn "Git command failed: #{command.join(' ')}"
        warn "Error: #{stderr.strip}"
      end

      def build_diff_command(diff_args)
        base_command = %w[git diff --name-only]
        return base_command if diff_args.empty?

        base_command + diff_args.split
      end

      def parse_diff_output(output)
        output.split("\n").reject(&:empty?).uniq
      end
    end
  end

  # Strategy pattern for finding spec files with enhanced pattern matching
  module SpecFileMatching
    # File path patterns for different project structures
    PATTERNS = {
      lib: %r{^lib/(.+)\.rb$},
      app: %r{^app/(.+)\.rb$},
      github_scripts: %r{^\.github/scripts/(.+)\.rb$}
    }.freeze

    class << self
      def strategy_for(file_path)
        case file_path
        when PATTERNS[:lib] then LibFileStrategy
        when PATTERNS[:app] then AppFileStrategy
        when PATTERNS[:github_scripts] then GitHubScriptsStrategy
        else GenericFileStrategy
        end
      end
    end
  end

  # Strategy for handling lib files
  class LibFileStrategy
    SPEC_DIR = 'spec'
    private_constant :SPEC_DIR

    def self.find_spec_path(file_path)
      # lib/path/file.rb -> spec/lib/path/file_spec.rb
      spec_path = "#{SPEC_DIR}/#{file_path.sub(/\.rb$/, '_spec.rb')}"
      File.exist?(spec_path) ? spec_path : nil
    end
  end

  # Strategy for handling app files
  class AppFileStrategy
    SPEC_DIR = 'spec'
    private_constant :SPEC_DIR

    def self.find_spec_path(file_path)
      # app/models/user.rb -> spec/models/user_spec.rb
      match = file_path.match(SpecFileMatching::PATTERNS[:app])
      return nil unless match

      spec_path = "#{SPEC_DIR}/#{match[1]}_spec.rb"
      File.exist?(spec_path) ? spec_path : nil
    end
  end

  # Strategy for handling GitHub scripts files
  class GitHubScriptsStrategy
    SPEC_DIR = 'spec'
    private_constant :SPEC_DIR

    def self.find_spec_path(file_path)
      # .github/scripts/pr_review.rb -> spec/github/scripts/pr_review_spec.rb
      match = file_path.match(SpecFileMatching::PATTERNS[:github_scripts])
      return nil unless match

      spec_path = "#{SPEC_DIR}/github/scripts/#{match[1]}_spec.rb"
      File.exist?(spec_path) ? spec_path : nil
    end
  end

  # Strategy for handling generic files
  class GenericFileStrategy
    SPEC_DIR = 'spec'
    private_constant :SPEC_DIR

    def self.find_spec_path(file_path)
      basename = File.basename(file_path, '.rb')
      return nil if invalid_basename?(basename)

      sanitized_basename = sanitize_basename(basename)
      return nil if sanitized_basename.empty?

      find_spec_by_pattern(sanitized_basename)
    end

    class << self
      private

      def invalid_basename?(basename)
        basename.nil? || basename.empty? || basename.include?('..') || basename.include?('/')
      end

      def sanitize_basename(basename)
        basename.gsub(/[^a-zA-Z0-9_-]/, '')
      end

      def find_spec_by_pattern(sanitized_basename)
        spec_pattern = File.join(SPEC_DIR, '**', "*#{sanitized_basename}*_spec.rb")
        candidates = Dir.glob(spec_pattern)

        # Ensure the result is within the spec directory
        candidates.find { |path| path.start_with?("#{SPEC_DIR}/") }
      end
    end
  end

  # Simplified locator that delegates to strategies
  class SpecFileLocator
    class << self
      def find_spec_for(file_path)
        return nil if file_path.nil? || !file_path.end_with?('.rb')

        strategy = SpecFileMatching.strategy_for(file_path)
        strategy.find_spec_path(file_path)
      end
    end
  end

  # Base class for change detection strategies
  class ChangeDetectionStrategy
    def initialize(config)
      @config = config
    end

    def detect_changes
      raise NotImplementedError, "#{self.class} must implement #detect_changes"
    end

    protected

    attr_reader :config
  end

  # Strategy for detecting changes via branch comparison
  class BranchComparisonStrategy < ChangeDetectionStrategy
    def detect_changes
      return [] unless applicable?

      files = GitOperations.diff_files("#{config.base_branch}...HEAD")
      return [] if files.empty?

      OutputFormatter.success("📊 Branch comparison: Found #{files.size} files")
      files
    end

    private

    def applicable?
      current_branch = GitOperations.current_branch
      current_branch != config.base_branch &&
        current_branch != 'HEAD' &&
        GitOperations.branch_exists?(config.base_branch)
    end
  end

  # Strategy for detecting uncommitted changes
  class UncommittedChangesStrategy < ChangeDetectionStrategy
    def detect_changes
      files = GitOperations.diff_files('')
      return [] if files.empty?

      OutputFormatter.success("📊 Uncommitted changes: Found #{files.size} files")
      files
    end
  end

  # Strategy for detecting staged changes
  class StagedChangesStrategy < ChangeDetectionStrategy
    def detect_changes
      files = GitOperations.diff_files('--cached')
      return [] if files.empty?

      OutputFormatter.success("📊 Staged changes: Found #{files.size} files")
      files
    end
  end

  # Strategy for detecting changes in the last commit
  class LastCommitStrategy < ChangeDetectionStrategy
    def detect_changes
      files = GitOperations.diff_files('HEAD~1')
      return [] if files.empty?

      OutputFormatter.success("📊 Last commit: Found #{files.size} files")
      files
    end
  end

  # Responsible for finding changed files using different strategies
  class ChangeDetector
    DETECTION_STRATEGIES = [
      BranchComparisonStrategy,
      UncommittedChangesStrategy,
      StagedChangesStrategy,
      LastCommitStrategy
    ].freeze
    private_constant :DETECTION_STRATEGIES

    def initialize(config)
      @config = config
    end

    def find_changed_files
      print_status_info
      try_detection_strategies || []
    end

    private

    def print_status_info
      OutputFormatter.info("🔍 Current branch: #{GitOperations.current_branch}")
      OutputFormatter.info("🔍 Comparing against: #{@config.base_branch}")
    end

    def try_detection_strategies
      DETECTION_STRATEGIES.each do |strategy_class|
        strategy = strategy_class.new(@config)
        files = strategy.detect_changes
        return files unless files.empty?
      end

      nil
    end
  end

  # Service for processing files and collecting spec files
  class SpecFileCollector
    def initialize(config)
      @config = config
      @spec_files = []
    end

    def collect_from(changed_files)
      OutputFormatter.info('📁 Changed files:')
      changed_files.each { |file| puts "  #{file}" }
      puts

      changed_files.each do |file|
        next unless ruby_file?(file)

        process_ruby_file(file)
      end

      @spec_files.uniq.sort
    end

    private

    def ruby_file?(file)
      file.end_with?('.rb')
    end

    def process_ruby_file(file)
      spec_file = SpecFileLocator.find_spec_for(file)

      if spec_file&.then { |f| File.exist?(f) }
        @spec_files << spec_file
        OutputFormatter.success("✅ Found spec: #{spec_file} for #{file}")
      else
        OutputFormatter.warning("⚠️  No spec found for: #{file}")
      end
    end
  end

  # Service for validating test environment
  class TestEnvironmentValidator
    def self.validate!
      command = %w[which bundle]
      _, _, status = Open3.capture3(*command, stdin_data: '', err: File::NULL)
      return if status.success?

      error_message = 'bundle command not found. Please install bundler.'
      error_context = { command: 'bundle', suggestion: 'gem install bundler' }
      raise CommandNotFoundError.new(error_message, context: error_context)
    end
  end

  # Service for executing RSpec commands
  class RSpecRunner
    def initialize(config)
      @config = config
    end

    def call(spec_files)
      return false if spec_files.empty?

      puts
      OutputFormatter.info('🧪 Running related tests...')

      command = build_rspec_command(spec_files)
      debug_print("Running: #{command.join(' ')}")

      success = execute_rspec_command(command)
      raise TestFailureError, 'Some tests failed' unless success

      true
    end

    private

    def build_rspec_command(spec_files)
      %w[bundle exec rspec] + spec_files + %w[--format documentation]
    end

    def execute_rspec_command(command)
      # Use Open3.popen3 to stream output in real-time while maintaining safety
      Open3.popen3(*command) do |_stdin, stdout, stderr, wait_thread|
        # Stream stdout in real-time
        stdout_thread = Thread.new { stdout.each_line { |line| print line } }
        stderr_thread = Thread.new { stderr.each_line { |line| warn line } }

        stdout_thread.join
        stderr_thread.join

        wait_thread.value.success?
      end
    rescue Errno::ENOENT => e
      handle_command_not_found_error(e)
    end

    def handle_command_not_found_error(error)
      error_message = "Command not found: #{error.message}"
      error_context = { command: 'bundle exec rspec', error: error.class.name }
      raise CommandNotFoundError.new(error_message, context: error_context)
    end

    def debug_print(message)
      puts message if @config.debug?
    end
  end

  # Handles test file processing and execution coordination
  class TestExecutor
    def initialize(config)
      @config = config
      @collector = SpecFileCollector.new(config)
      @runner = RSpecRunner.new(config)
      @spec_files = []
    end

    def process_files(changed_files)
      @spec_files = @collector.collect_from(changed_files)
    end

    def run_tests
      return OutputFormatter.warning('No spec files found for changed Ruby files') if @spec_files.empty?

      TestEnvironmentValidator.validate!
      @runner.call(@spec_files)
    end

    private

    attr_reader :spec_files
  end

  # Handles formatted output to terminal
  class OutputFormatter
    class << self
      def info(message)
        puts Colors.colorize(message, Colors::BLUE)
      end

      def success(message)
        puts Colors.colorize(message, Colors::GREEN)
      end

      def warning(message)
        puts Colors.colorize(message, Colors::YELLOW)
      end

      def error(message)
        puts Colors.colorize("❌ Error: #{message}", Colors::RED)
      end
    end
  end

  # Service for building configuration from parsed arguments
  class ConfigurationBuilder
    def self.build_from_args(parsed_args, base_branch)
      debug_mode = parsed_args[:debug] || false
      Configuration.new(base_branch: base_branch, debug_mode: debug_mode)
    end
  end

  # Handles command line argument parsing
  class ArgumentParser
    USAGE_TEXT = <<~USAGE
      Usage: %<program_name>s [base_branch] [options]

      Run RSpec tests for files changed in a PR or working directory.

      Arguments:
        base_branch    Branch to compare against (default: main)

      Options:
        --help, -h     Show this help message
        --debug, -d    Enable debug output

      Examples:
        %<program_name>s                    # Compare against main
        %<program_name>s develop            # Compare against develop
        %<program_name>s origin/main        # Compare against origin/main

      The script will automatically detect changes using multiple methods:
      1. Branch comparison (for feature branches)
      2. Uncommitted changes
      3. Staged changes
      4. Last commit changes
    USAGE
    private_constant :USAGE_TEXT

    def parse(args)
      options = {}
      show_help = false

      parser = create_option_parser(options) { show_help = true }
      remaining_args = parser.parse(args)

      if show_help
        puts parser
        exit 0
      end

      base_branch = remaining_args.first || 'main'
      ConfigurationBuilder.build_from_args(options, base_branch)
    rescue OptionParser::InvalidOption => e
      OutputFormatter.error("Invalid option: #{e.message}")
      exit 1
    end

    private

    def create_option_parser(options)
      OptionParser.new do |opts|
        opts.banner = usage_text

        opts.on('-h', '--help', 'Show this help message') do
          yield if block_given?
        end

        opts.on('-d', '--debug', 'Enable debug output') do
          options[:debug] = true
        end
      end
    end

    def usage_text
      format(USAGE_TEXT, program_name: File.basename($PROGRAM_NAME))
    end
  end

  # Service for retrieving Git status information
  class GitStatusService
    def self.get_status_lines
      command = %w[git status --porcelain]
      stdout, _, status = Open3.capture3(*command, stdin_data: '')
      return ['(git status failed)'] unless status.success?

      status_lines = stdout.strip.split("\n")
      status_lines.empty? ? ['(no changes)'] : status_lines
    end
  end

  # Provides debug information when no changes are found
  class DebugInfoProvider
    def initialize(config)
      @config = config
    end

    def show_debug_info
      OutputFormatter.error('No files changed found using any method')
      puts
      OutputFormatter.info('💡 Debug info:')
      puts "   Current branch: #{GitOperations.current_branch}"
      puts '   Git status:'

      show_git_status
      show_suggestions
    end

    private

    def show_git_status
      status_lines = GitStatusService.get_status_lines
      status_lines.each { |line| puts "   #{line}" }
    end

    def show_suggestions
      puts
      OutputFormatter.info('💡 Try one of these:')
      feature_branch_message = '   - Make sure you\'re on a feature branch: ' \
                               'git checkout -b feature/my-changes'
      puts feature_branch_message
      commit_message = '   - Commit your changes first: ' \
                       'git add . && git commit -m \'your changes\''
      puts commit_message
      different_base_message = '   - Run with different base: ' \
                               "#{File.basename($PROGRAM_NAME)} origin/main"
      puts different_base_message
      branch_check_message = '   - Check if base branch exists: ' \
                             "git branch -a | grep #{@config.base_branch}"
      puts branch_check_message
    end
  end

  # Coordinates the main workflow for the test runner application
  class TestRunnerWorkflow
    def initialize(config)
      @config = config
    end

    def execute
      ensure_valid_git_environment!

      changed_files = detect_file_changes
      return handle_no_changes_scenario if changed_files.empty?

      execute_test_suite_for_changes(changed_files)
    end

    private

    attr_reader :config

    def ensure_valid_git_environment!
      return if GitOperations.repository_exists?

      raise GitRepositoryError.new(
        'Not in a git repository',
        context: { working_directory: Dir.pwd }
      )
    end

    def detect_file_changes
      ChangeDetector.new(config).find_changed_files
    end

    def handle_no_changes_scenario
      DebugInfoProvider.new(config).show_debug_info
      exit 0
    end

    def execute_test_suite_for_changes(changed_files)
      executor = TestExecutor.new(config)
      executor.process_files(changed_files)
      executor.run_tests
    end
  end

  # Handles formatted error reporting and program exit
  class ErrorHandler
    def initialize(config)
      @config = config
    end

    def handle_known_error(error)
      OutputFormatter.error(error.message)
      log_error_context_if_debug(error)
      exit 1
    end

    def handle_unexpected_error(error)
      OutputFormatter.error("Unexpected error: #{error.message}")
      log_unexpected_error_details(error) if @config&.debug?
      exit 1
    end

    private

    def log_error_context_if_debug(error)
      return unless @config&.debug? && error.context.any?

      puts "\nDebug context:"
      error.context.each { |key, value| puts "  #{key}: #{value}" }
    end

    def log_unexpected_error_details(error)
      puts "\nDebug information:"
      puts "  Error class: #{error.class}"
      puts '  Backtrace:'
      error.backtrace&.first(5)&.each { |line| puts "    #{line}" }
    end
  end

  # Main application entry point with focused responsibilities
  class ApplicationRunner
    def initialize
      @config = nil
      @error_handler = nil
    end

    def run(args = ARGV)
      @config = parse_command_line_arguments(args)
      @error_handler = ErrorHandler.new(@config)

      workflow = TestRunnerWorkflow.new(@config)
      workflow.execute
    rescue TestRunnerError => e
      @error_handler.handle_known_error(e)
    rescue StandardError => e
      @error_handler.handle_unexpected_error(e)
    end

    private

    def parse_command_line_arguments(args)
      ArgumentParser.new.parse(args)
    end
  end
end

# Run the script if called directly
if __FILE__ == $PROGRAM_NAME
  runner = Scripts::ApplicationRunner.new
  runner.run
end
