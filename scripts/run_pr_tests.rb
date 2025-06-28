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
#   ./scripts/run_pr_tests.rb origin/main  # Compare against origin/main
#

require 'optparse'
require 'shellwords'
require 'English'

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
        branch = execute_git_command('git branch --show-current 2>/dev/null')
        branch.empty? ? 'HEAD' : branch
      end

      def branch_exists?(branch_name)
        return false if branch_name.nil? || branch_name.strip.empty?

        system("git rev-parse --verify #{Shellwords.escape(branch_name)} >/dev/null 2>&1")
      end

      def diff_files(diff_args)
        command = build_diff_command(diff_args)
        output = execute_git_command(command)

        return [] if output.empty?

        parse_diff_output(output)
      end

      def repository_exists?
        system('git rev-parse --git-dir >/dev/null 2>&1')
      end

      private

      def execute_git_command(command)
        output = `#{command}`.strip
        return output if $CHILD_STATUS.exitstatus.zero?

        ''
      end

      def build_diff_command(diff_args)
        "git diff --name-only #{diff_args} 2>/dev/null".strip
      end

      def parse_diff_output(output)
        output.split("\n").reject(&:empty?).uniq
      end
    end
  end

  # Strategy pattern for finding spec files with enhanced pattern matching
  class SpecFileLocator
    SPEC_DIR = 'spec'
    private_constant :SPEC_DIR

    # File path patterns for different project structures
    PATTERNS = {
      lib: %r{^lib/(.+)\.rb$},
      app: %r{^app/(.+)\.rb$},
      github_scripts: %r{^\.github/scripts/(.+)\.rb$}
    }.freeze
    private_constant :PATTERNS

    class << self
      def find_spec_for(file_path)
        return nil if file_path.nil? || !file_path.end_with?('.rb')

        strategy = select_strategy_for(file_path)
        strategy&.call(file_path)
      end

      private

      def select_strategy_for(file_path)
        case file_path
        when PATTERNS[:lib] then method(:handle_lib_file)
        when PATTERNS[:app] then method(:handle_app_file)
        when PATTERNS[:github_scripts] then method(:handle_github_scripts_file)
        else method(:handle_generic_file)
        end
      end

      def handle_lib_file(file_path)
        # lib/path/file.rb -> spec/lib/path/file_spec.rb
        spec_path = "#{SPEC_DIR}/#{file_path.sub(/\.rb$/, '_spec.rb')}"
        File.exist?(spec_path) ? spec_path : nil
      end

      def handle_app_file(file_path)
        # app/models/user.rb -> spec/models/user_spec.rb
        match = file_path.match(PATTERNS[:app])
        return nil unless match

        spec_path = "#{SPEC_DIR}/#{match[1]}_spec.rb"
        File.exist?(spec_path) ? spec_path : nil
      end

      def handle_github_scripts_file(file_path)
        # .github/scripts/pr_review.rb -> spec/github/scripts/pr_review_spec.rb
        match = file_path.match(PATTERNS[:github_scripts])
        return nil unless match

        spec_path = "#{SPEC_DIR}/github/scripts/#{match[1]}_spec.rb"
        File.exist?(spec_path) ? spec_path : nil
      end

      def handle_generic_file(file_path)
        basename = File.basename(file_path, '.rb')
        find_spec_by_basename(basename)
      end

      def find_spec_by_basename(basename)
        return nil if basename.nil? || basename.empty?
        return nil if basename.include?('..') || basename.include?('/')

        sanitized_basename = basename.gsub(/[^a-zA-Z0-9_-]/, '')
        return nil if sanitized_basename.empty?

        spec_pattern = File.join(SPEC_DIR, '**', "*#{sanitized_basename}*_spec.rb")
        candidates = Dir.glob(spec_pattern)

        # Ensure the result is within the spec directory
        candidates.find { |path| path.start_with?("#{SPEC_DIR}/") }
      end
    end
  end

  # Responsible for finding changed files using different strategies
  class ChangeDetector
    def initialize(config)
      @config = config
    end

    def find_changed_files
      print_status_info
      try_detection_methods || []
    end

    private

    def print_status_info
      OutputFormatter.info("🔍 Current branch: #{GitOperations.current_branch}")
      OutputFormatter.info("🔍 Comparing against: #{@config.base_branch}")
    end

    def try_detection_methods
      branch_comparison || uncommitted_changes || staged_changes || last_commit_changes
    end

    def branch_comparison
      return unless should_try_branch_comparison?

      files = GitOperations.diff_files("#{@config.base_branch}...HEAD")
      return if files.empty?

      OutputFormatter.success("📊 Method 1 - Branch comparison: Found #{files.size} files")
      files
    end

    def should_try_branch_comparison?
      current_branch = GitOperations.current_branch
      current_branch != @config.base_branch &&
        current_branch != 'HEAD' &&
        GitOperations.branch_exists?(@config.base_branch)
    end

    def uncommitted_changes
      files = GitOperations.diff_files('')
      return if files.empty?

      OutputFormatter.success("📊 Method 2 - Uncommitted changes: Found #{files.size} files")
      files
    end

    def staged_changes
      files = GitOperations.diff_files('--cached')
      return if files.empty?

      OutputFormatter.success("📊 Method 3 - Staged changes: Found #{files.size} files")
      files
    end

    def last_commit_changes
      files = GitOperations.diff_files('HEAD~1')
      return if files.empty?

      OutputFormatter.success("📊 Method 4 - Last commit: Found #{files.size} files")
      files
    end
  end

  # Handles test file processing and execution
  class TestExecutor
    def initialize(config)
      @config = config
      @spec_files = []
    end

    def process_files(changed_files)
      OutputFormatter.info('📁 Changed files:')
      changed_files.each { |file| puts "  #{file}" }
      puts

      collect_spec_files(changed_files)
    end

    def run_tests
      return OutputFormatter.warning('No spec files found for changed Ruby files') if @spec_files.empty?

      validate_environment!
      execute_rspec_command
    end

    private

    def collect_spec_files(changed_files)
      changed_files.each do |file|
        next unless ruby_file?(file)

        process_ruby_file(file)
      end
    end

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

    def validate_environment!
      return if system('which bundle >/dev/null 2>&1')

      raise CommandNotFoundError.new(
        'bundle command not found. Please install bundler.',
        context: { command: 'bundle', suggestion: 'gem install bundler' }
      )
    end

    def execute_rspec_command
      puts
      OutputFormatter.info('🧪 Running related tests...')

      spec_files = @spec_files.uniq.sort
      command = build_rspec_command(spec_files)

      debug_print("Running: #{command.join(' ')}")

      success = system(*command)
      raise TestFailureError, 'Some tests failed' unless success
    end

    def build_rspec_command(spec_files)
      %w[bundle exec rspec] + spec_files + %w[--format documentation]
    end

    def debug_print(message)
      puts message if @config.debug?
    end
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

  # Handles command line argument parsing
  class ArgumentParser
    def parse(args)
      config = Configuration.new
      show_help = false

      parser = OptionParser.new do |opts|
        opts.banner = usage_text

        opts.on('-h', '--help', 'Show this help message') do
          show_help = true
        end

        opts.on('-d', '--debug', 'Enable debug output') do
          config = Configuration.new(base_branch: config.base_branch, debug_mode: true)
        end
      end

      remaining_args = parser.parse(args)
      base_branch = remaining_args.first || 'main'
      config = Configuration.new(base_branch: base_branch, debug_mode: config.debug?)

      if show_help
        puts parser
        exit 0
      end

      config
    rescue OptionParser::InvalidOption => e
      OutputFormatter.error("Invalid option: #{e.message}")
      exit 1
    end

    private

    def usage_text
      <<~USAGE
        Usage: #{File.basename($PROGRAM_NAME)} [base_branch] [options]

        Run RSpec tests for files changed in a PR or working directory.

        Arguments:
          base_branch    Branch to compare against (default: main)

        Options:
          --help, -h     Show this help message
          --debug, -d    Enable debug output

        Examples:
          #{File.basename($PROGRAM_NAME)}                    # Compare against main
          #{File.basename($PROGRAM_NAME)} develop            # Compare against develop
          #{File.basename($PROGRAM_NAME)} origin/main        # Compare against origin/main

        The script will automatically detect changes using multiple methods:
        1. Branch comparison (for feature branches)
        2. Uncommitted changes
        3. Staged changes
        4. Last commit changes
      USAGE
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
      status_output = `git status --porcelain 2>/dev/null`
      if $CHILD_STATUS.exitstatus.zero?
        status_lines = status_output.strip.split("\n")
        if status_lines.empty?
          puts '   (no changes)'
        else
          status_lines.each { |line| puts "   #{line}" }
        end
      else
        puts '   (git status failed)'
      end
    end

    def show_suggestions
      puts
      OutputFormatter.info('💡 Try one of these:')
      puts "   - Make sure you're on a feature branch: git checkout -b feature/my-changes"
      puts "   - Commit your changes first: git add . && git commit -m 'your changes'"
      puts "   - Run with different base: #{File.basename($PROGRAM_NAME)} origin/main"
      puts "   - Check if base branch exists: git branch -a | grep #{@config.base_branch}"
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

  # Main application entry point with focused error handling responsibilities
  class ApplicationRunner
    def initialize
      @config = nil
    end

    def run(args = ARGV)
      @config = parse_command_line_arguments(args)
      workflow = TestRunnerWorkflow.new(@config)
      workflow.execute
    rescue TestRunnerError => e
      handle_known_error(e)
    rescue StandardError => e
      handle_unexpected_error(e)
    end

    private

    attr_reader :config

    def parse_command_line_arguments(args)
      ArgumentParser.new.parse(args)
    end

    def handle_known_error(error)
      OutputFormatter.error(error.message)
      log_error_context_if_debug(error)
      exit 1
    end

    def handle_unexpected_error(error)
      OutputFormatter.error("Unexpected error: #{error.message}")
      log_unexpected_error_details(error) if config&.debug?
      exit 1
    end

    def log_error_context_if_debug(error)
      return unless config&.debug? && error.context.any?

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
end

# Run the script if called directly
if __FILE__ == $PROGRAM_NAME
  runner = Scripts::ApplicationRunner.new
  runner.run
end
