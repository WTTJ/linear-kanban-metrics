# frozen_string_literal: true

require 'bundler/setup'
require 'dotenv'
require 'faker'

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
end
