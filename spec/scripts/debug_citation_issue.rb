#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'
require 'json'

# Add the parent directory to load path so we can require the PR review script
$LOAD_PATH.unshift(File.join(__dir__, '..', '..', '.github', 'scripts'))

# Load the PR review script to access the classes and modules
require_relative '../../.github/scripts/pr_review'

class CitationDebugger
  include DustCitationProcessor

  def initialize
    @logger = Logger.new($stdout)
    @logger.level = Logger::DEBUG
  end

  def test_real_citation_scenarios
    puts "\n=== Testing Real Citation Scenarios ==="
    puts 'This script tests the citation processing with real examples from Dust API'

    # Test scenario 1: Content with citations in response but no citation metadata
    puts "\n--- Scenario 1: Citation markers in content, no citation metadata ---"
    content_with_markers = 'This is a review :cite[aa,eu] with multiple markers :cite[bb].'
    citations = []

    result = format_response_with_citations(content_with_markers, citations)
    puts "Input content: #{content_with_markers}"
    puts "Citations array: #{citations.inspect}"
    puts "Output: #{result}"
    puts "Issue: #{result.include?(':cite[') ? 'UNPROCESSED MARKERS REMAIN' : 'All markers processed'}"

    # Test scenario 2: Content with citations and proper metadata
    puts "\n--- Scenario 2: Citation markers with proper metadata ---"
    citations_with_metadata = [
      { 'reference' => { 'title' => 'Document 1', 'href' => 'http://example.com/1' } },
      { 'reference' => { 'title' => 'Document 2', 'href' => 'http://example.com/2' } }
    ]

    result2 = format_response_with_citations(content_with_markers, citations_with_metadata)
    puts "Input content: #{content_with_markers}"
    puts "Citations array: #{citations_with_metadata.length} items"
    puts "Output: #{result2}"
    puts "Issue: #{result2.include?(':cite[') ? 'UNPROCESSED MARKERS REMAIN' : 'All markers processed'}"

    # Test scenario 3: Simulating what might be happening in real response
    puts "\n--- Scenario 3: Simulating real Dust response processing ---"

    # Simulate a Dust API response structure
    simulated_api_response = {
      'conversation' => {
        'content' => [
          [
            {
              'sId' => 'msg123',
              'type' => 'agent_message',
              'content' => "## Code Review\n\nThis PR looks good :cite[aa,eu] but needs some improvements :cite[bb].\n\n### Issues Found\n\n1. Missing error handling :cite[cc]\n2. Documentation needs update\n\n**Overall**: Approved with minor changes needed.",
              'citations' => []
            }
          ]
        ]
      }
    }

    puts 'Simulated API response structure:'
    puts JSON.pretty_generate(simulated_api_response)

    # Process like the real code does
    messages = extract_messages_from_response(simulated_api_response)
    agent_messages = find_agent_messages(messages)
    final_result = extract_final_content_with_citations(agent_messages)

    puts "\nFinal processed result:"
    puts final_result
    puts "Issue: #{final_result.include?(':cite[') ? 'UNPROCESSED MARKERS REMAIN - THIS IS THE BUG!' : 'All markers processed'}"

    # Test scenario 4: What happens if we force citation processing
    puts "\n--- Scenario 4: Force citation processing ---"
    raw_content = agent_messages.last&.dig('content')
    raw_citations = agent_messages.last&.dig('citations') || []

    puts "Raw content: #{raw_content&.slice(0, 100)}..."
    puts "Raw citations: #{raw_citations.inspect}"

    # Force format_response_with_citations even with empty citations
    forced_result = format_response_with_citations(raw_content, raw_citations)
    puts 'Forced processing result:'
    puts forced_result
    puts "Issue: #{forced_result.include?(':cite[') ? 'UNPROCESSED MARKERS REMAIN' : 'All markers processed'}"
  end
end

# Run the test
debugger = CitationDebugger.new
debugger.test_real_citation_scenarios
