# frozen_string_literal: true

require 'rspec'
require 'bundler/setup'
require 'dotenv'
require 'faker'

# Configure SimpleCov if coverage is enabled
if ENV['COVERAGE']
  require 'simplecov'

  SimpleCov.start do
    add_filter '/spec/'
    add_filter '/vendor/'
    add_filter '/tmp/'
    add_group 'Calculators', 'lib/kanban_metrics/calculators'
    add_group 'Formatters', 'lib/kanban_metrics/formatters'
    add_group 'Linear API', 'lib/kanban_metrics/linear'
    add_group 'Reports', 'lib/kanban_metrics/reports'
    add_group 'Timeseries', 'lib/kanban_metrics/timeseries'

    minimum_coverage 90
    minimum_coverage_by_file 80
  end
end

# Load environment variables for testing
Dotenv.load('config/.env.test')

# Load the main library
require_relative '../lib/kanban_metrics'

# Load all support files
Dir[File.join(__dir__, 'support', '**', '*.rb')].each { |f| require f }

RSpec.configure do |config|
  # rspec-expectations config
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
    expectations.syntax = :expect # Disable should syntax
  end

  # rspec-mocks config
  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
    mocks.syntax = :expect # Disable should syntax
  end

  # Shared context metadata behavior
  config.shared_context_metadata_behavior = :apply_to_host_groups

  # Arbitrary tags
  config.filter_run_when_matching :focus

  # Profile slow examples
  config.profile_examples = 10 if ENV['PROFILE']

  # Warnings
  config.warnings = true if ENV['WARNINGS']

  # Default to aggregate failures for better test output
  config.define_derived_metadata do |meta|
    meta[:aggregate_failures] = true unless meta.key?(:aggregate_failures)
  end

  # Suppress stdout during individual test execution to keep output clean
  # This approach doesn't interfere with test loading and discovery
  config.around(:each) do |example|
    if ENV['DEBUG'] || ENV['RSPEC_DEBUG']
      # Run normally in debug mode
      example.run
    else
      # Capture stdout during test execution only
      original_stdout = $stdout
      $stdout = StringIO.new
      begin
        example.run
      ensure
        $stdout = original_stdout
      end
    end
  end
end
