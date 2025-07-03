#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'
require 'json'

# Load the PR review script to access the updated classes and modules
$LOAD_PATH.unshift(File.join(__dir__, '..', '..', '.github', 'scripts'))
require_relative '../../.github/scripts/pr_review'

class SmartCitationTest
  include DustCitationProcessor

  attr_reader :logger

  def initialize
    @logger = Logger.new($stdout)
    @logger.level = Logger::DEBUG
  end

  def test_smart_citation_processing
    puts "\n=== Testing Smart Citation Processing Fix ==="

    test_citations_with_available_metadata
    test_citations_with_no_metadata
    test_more_markers_than_citations
    test_real_world_example
  end

  private

  def test_citations_with_available_metadata
    puts "\n--- Test 1: Citation markers with available citations ---"
    content = 'This PR needs work :cite[aa,eu] and also :cite[bb] requires attention.'
    citations = sample_citations

    puts "Input content: #{content}"
    puts "Available citations: #{citations.length}"

    result = format_response_with_citations(content, citations)
    puts "\nProcessed result:"
    puts result
    puts "\nMarkers processed: #{result.include?(':cite[') ? 'NO ❌' : 'YES ✅'}"
  end

  def test_citations_with_no_metadata
    puts "\n--- Test 2: Citation markers with no citations available ---"
    content = 'This PR needs work :cite[aa,eu] and also :cite[bb] requires attention.'
    result = format_response_with_citations(content, [])
    puts "\nResult with no citations:"
    puts result
    puts "\nMarkers highlighted: #{result.include?('**:cite[') ? 'YES ✅' : 'NO ❌'}"
  end

  def test_more_markers_than_citations
    puts "\n--- Test 3: More markers than citations ---"
    many_markers_content = 'Issues: :cite[aa], :cite[bb], :cite[cc], :cite[dd], :cite[ee]'
    few_citations = [
      { 'reference' => { 'title' => 'Doc 1', 'href' => 'http://example.com/1' } },
      { 'reference' => { 'title' => 'Doc 2', 'href' => 'http://example.com/2' } }
    ]

    puts "Content: #{many_markers_content}"
    puts "Citations available: #{few_citations.length}"

    result = format_response_with_citations(many_markers_content, few_citations)
    puts "\nResult:"
    puts result
  end

  def test_real_world_example
    puts "\n--- Test 4: Real-world example with :cite[aa,eu] ---"
    real_content = <<~CONTENT
      ## Code Review

      This PR looks good :cite[aa,eu] but has some issues:

      1. Missing error handling :cite[bb]
      2. No unit tests :cite[cc]

      Overall assessment: Needs improvements :cite[dd,ee].
    CONTENT

    real_citations = [
      { 'reference' => { 'title' => 'Error Handling Best Practices', 'href' => 'https://example.com/errors' } },
      { 'reference' => { 'title' => 'Unit Testing Guide', 'href' => 'https://example.com/testing' } },
      { 'reference' => { 'title' => 'Code Quality Standards', 'href' => 'https://example.com/quality' } }
    ]

    puts 'Real content:'
    puts real_content
    puts "Citations: #{real_citations.length}"

    real_result = format_response_with_citations(real_content, real_citations)
    puts "\nFinal result:"
    puts real_result
    puts "\nSuccess: #{real_result.include?(':cite[') ? 'Some markers remain ❌' : 'All markers processed! ✅'}"
  end

  def sample_citations
    [
      {
        'reference' => {
          'title' => 'Ruby Style Guide',
          'href' => 'https://github.com/rubocop/ruby-style-guide'
        }
      },
      {
        'reference' => {
          'title' => 'Rails Best Practices',
          'href' => 'https://rails-bestpractices.com/'
        }
      },
      {
        'reference' => {
          'title' => 'Testing Guidelines',
          'href' => 'https://rspec.info/'
        }
      }
    ]
  end
end

# Run the test
tester = SmartCitationTest.new
tester.test_smart_citation_processing
