#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'
require 'json'

# Load the PR review script
$LOAD_PATH.unshift(File.join(__dir__, '..', '..', '.github', 'scripts'))
require_relative '../../.github/scripts/pr_review'

class CitationProcessingVerification
  include DustCitationProcessor

  attr_reader :logger
  

  def initialize
    @logger = Logger.new($stdout)
    @logger.level = Logger::DEBUG
  end

  def test_real_world_scenario
    puts "\n=== Testing Real-World Citation Processing Scenario ==="
    puts "This simulates the exact issue from the GitHub comment"

    # Content that matches what was posted to GitHub
    github_content = <<~CONTENT
      **Module Organization & Separation of Concerns** :cite[cc,1f]
      - Excellent refactoring of citation processing into dedicated modules
      - Clear separation follows Single Responsibility Principle

      **Design Pattern Implementation** :cite[ri]
      - **Strategy Pattern**: Citation formatting handles different citation types
      - **Module Pattern**: Clean module-based organization

      **Namespace Organization** :cite[q2,eu]
      - The modules are not under the KanbanMetrics namespace
      - Should be organized as KanbanMetrics::GitHub::CitationProcessor

      **Comprehensive Test Coverage** :cite[qe,re]
      - 667 examples with 0 failures
      - Covers edge cases and integration scenarios
    CONTENT

    puts "Original content from GitHub:"
    puts github_content
    puts "\n" + ("=" * 60)

    # Test scenario 1: No citations metadata (current real-world situation)
    puts "\n--- Scenario 1: No citations metadata (current situation) ---"
    result_no_citations = format_response_with_citations(github_content, [])
    puts "Result with no citations:"
    puts result_no_citations
    puts "\nCitation markers processed: #{!result_no_citations.include?(':cite[') ? 'YES ✅' : 'NO ❌'}"

    # Test scenario 2: With citations metadata (ideal situation)
    puts "\n--- Scenario 2: With citations metadata (ideal situation) ---"
    sample_citations = [
      { 'reference' => { 'title' => 'SOLID Principles Guide', 'href' => 'https://example.com/solid' } },
      { 'reference' => { 'title' => 'Design Patterns', 'href' => 'https://example.com/patterns' } },
      { 'reference' => { 'title' => 'Ruby Style Guide', 'href' => 'https://example.com/ruby' } },
      { 'reference' => { 'title' => 'Testing Best Practices', 'href' => 'https://example.com/testing' } },
      { 'reference' => { 'title' => 'Module Organization', 'href' => 'https://example.com/modules' } }
    ]

    result_with_citations = format_response_with_citations(github_content, sample_citations)
    puts "Result with citations:"
    puts result_with_citations
    puts "\nCitation markers processed: #{!result_with_citations.include?(':cite[') ? 'YES ✅' : 'NO ❌'}"

    # Test the extract_final_content_with_citations method behavior
    puts "\n--- Scenario 3: Simulating extract_final_content_with_citations ---"
    
    # Simulate agent message structure
    agent_messages = [
      {
        'status' => 'succeeded',
        'content' => github_content,
        'citations' => []
      }
    ]
    
    # Test the method that was causing the issue
    processor = DustResponseProcessorTester.new
    final_result = processor.test_extract_final_content_with_citations(agent_messages)
    puts "Final result from extract_final_content_with_citations:"
    puts final_result
    puts "\nCitation markers processed: #{!final_result.include?(':cite[') ? 'YES ✅' : 'NO ❌'}"
    
    puts "\n" + ("=" * 60)
    puts "🎯 CONCLUSION:"
    puts "The fix should ensure that even when no citations metadata is available,"
    puts "all :cite[...] markers are converted to **:cite[...]** format for visibility."
  end
end

class DustResponseProcessorTester
  include DustResponseProcessor

  attr_reader :logger

  def initialize
    @logger = Logger.new($stdout)
    @logger.level = Logger::DEBUG
  end

  def test_extract_final_content_with_citations(agent_messages)
    extract_final_content_with_citations(agent_messages)
  end
end

# Run the verification
tester = CitationProcessingVerification.new
tester.test_real_world_scenario
