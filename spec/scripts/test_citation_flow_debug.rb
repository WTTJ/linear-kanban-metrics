#!/usr/bin/env ruby
# frozen_string_literal: true

# Test script to debug the exact citation processing flow
# using the real response structure from your log

require 'bundler/setup'
require 'logger'
require 'stringio'

# Load the PR review script
require_relative '../../.github/scripts/pr_review'

class CitationFlowDebugger
  attr_reader :logger

  def initialize
    @logger = Logger.new($stdout)
    @logger.level = Logger::DEBUG
  end

  def test_real_flow
    puts '🧪 Testing Real Citation Processing Flow'
    puts '=' * 60
    puts

    # Create a real DustProvider instance
    config = create_test_config
    http_client = create_mock_http_client
    provider = DustProvider.new(config, http_client, logger)

    # Use the exact response structure from your log
    api_response = create_real_api_response

    puts '📥 PROCESSING WITH REAL DUSTPROVIDER:'
    result = provider.send(:extract_content, api_response)

    puts '📤 FINAL RESULT:'
    puts '-' * 40
    puts result
    puts '-' * 40
    puts

    # Check if citations were processed
    if result.include?(':cite[')
      puts '❌ CITATIONS NOT PROCESSED! Found unprocessed markers:'
      unprocessed = result.scan(/:cite\[[^\]]+\]/)
      unprocessed.each { |marker| puts "  - #{marker}" }
    else
      puts '✅ CITATIONS PROCESSED SUCCESSFULLY!'
    end
  end

  private

  def create_test_config
    Struct.new(:dust_api_key, :dust_workspace_id, :dust_agent_id).new(
      'test-key',
      'test-workspace',
      'test-agent'
    )
  end

  def create_mock_http_client
    Object.new
  end

  def create_real_api_response
    {
      'conversation' => {
        'content' => [
          [
            {
              'type' => 'agent_message',
              'content' => sample_content_with_citations,
              'citations' => sample_citations
            }
          ]
        ]
      }
    }
  end

  def sample_content_with_citations
    <<~CONTENT
      # PR Review: Citation Processing Enhancement

      ## 🔍 Code Quality & Architecture

      ### ✅ Strengths

      **Module Organization & Separation of Concerns** :cite[aa,eu]
      - Excellent refactoring of citation processing into dedicated modules (`DustMessageExtractor`, `DustCitationProcessor`, `DustResponseProcessor`)
      - Clear separation follows Single Responsibility Principle - each module has one focused purpose
      - Proper use of module composition with `include` statements

      **Design Pattern Implementation** :cite[hj]
      - **Strategy Pattern**: Citation formatting handles different citation types (Hash, String, reference, document, basic)
      - **Module Pattern**: Clean module-based organization for related functionality
      - **Template Method Pattern**: `format_hash_citation` delegates to specific formatting methods

      ### ⚠️ Areas for Improvement

      **Namespace Organization** :cite[cc,gx]
      - The modules are not under the `KanbanMetrics` namespace as required by project standards
      - Should be organized as `KanbanMetrics::GitHub::CitationProcessor` or similar
      - Current global namespace violates the established module hierarchy
    CONTENT
  end

  def sample_citations
    [
      {
        'id' => 'aa',
        'reference' => {
          'title' => 'SOLID Design Principles in Ruby',
          'href' => 'https://medium.com/@allegranzia/solid-design-principles-in-ruby-8d039dbe2ef7'
        }
      },
      {
        'id' => 'eu',
        'reference' => {
          'title' => 'SOLID Design Principles in Ruby - Honeybadger.io',
          'href' => 'https://www.honeybadger.io/blog/ruby-solid-design-principles/'
        }
      },
      {
        'id' => 'hj',
        'reference' => {
          'title' => 'Mastering Complexity at Shippio: Design Patterns in Ruby',
          'href' => 'https://techblog.shippio.io/mastering-complexity-at-shippio-design-patterns-in-ruby-on-rails-837e70cd4dcf'
        }
      },
      {
        'id' => 'cc',
        'reference' => {
          'title' => 'Classic to Zeitwerk HOWTO',
          'href' => 'https://guides.rubyonrails.org/v7.2/classic_to_zeitwerk_howto.html'
        }
      },
      {
        'id' => 'gx',
        'reference' => {
          'title' => 'deepin-community/ruby-zeitwerk',
          'href' => 'https://github.com/deepin-community/ruby-zeitwerk'
        }
      }
    ]
  end
end

# Run the test
if __FILE__ == $PROGRAM_NAME
  debugger = CitationFlowDebugger.new
  debugger.test_real_flow
end
