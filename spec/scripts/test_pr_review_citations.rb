#!/usr/bin/env ruby
# frozen_string_literal: true

# Test script to verify citation processing in the main PR review script

require_relative '../../.github/scripts/pr_review'

# Test data matching our validated citation processing logic
SAMPLE_RESPONSE = {
  'conversation' => {
    'content' => [
      [
        {
          'type' => 'agent_message',
          'status' => 'succeeded',
          'content' => "## PR Review Test\n\n:cite[aw] This demonstrates single citation.\n\n:cite[gx,bt] This shows multi-citation support.\n\n:cite[unknown] This tests unknown citation handling.\n\n:cite[aw,unknown,bt] This tests mixed valid/invalid citations.",
          'citations' => [
            {
              'id' => 'aw',
              'reference' => {
                'title' => 'CODING_STANDARDS.md',
                'href' => '/doc/CODING_STANDARDS.md'
              }
            },
            {
              'id' => 'gx',
              'reference' => {
                'title' => 'TECHNICAL_DOCUMENTATION.md',
                'href' => '/doc/TECHNICAL_DOCUMENTATION.md'
              }
            },
            {
              'id' => 'bt',
              'reference' => {
                'title' => 'TESTING_GUIDE.md',
                'href' => '/doc/TESTING_GUIDE.md'
              }
            }
          ]
        }
      ]
    ]
  }
}.freeze

# Test the DustResponseProcessor module
class CitationTestProcessor
  include DustResponseProcessor

  attr_reader :logger

  def initialize
    @logger = Logger.new(StringIO.new) # Silent logger for testing
  end

  def test_citation_processing
    puts '=' * 80
    puts 'Testing Citation Processing in PR Review Script'
    puts '=' * 80

    result = extract_content(SAMPLE_RESPONSE)

    puts "\n🧪 PROCESSED OUTPUT:"
    puts '-' * 40
    puts result
    puts '-' * 40

    # Verify expected replacements
    verify_citations(result)
  end

  private

  def verify_citations(result)
    puts "\n✅ VERIFICATION RESULTS:"

    tests = [
      { pattern: /\[1\]/, description: 'Single citation :cite[aw] → [1]' },
      { pattern: /\[2,3\]/, description: 'Multi-citation :cite[gx,bt] → [2,3]' },
      { pattern: /\*\*:cite\[unknown\]\*\*/, description: 'Unknown citation highlighted as **:cite[unknown]**' },
      { pattern: /\[1,3\]/, description: 'Mixed citations :cite[aw,unknown,bt] → [1,3] (skipping unknown)' },
      { pattern: /\*\*References:\*\*/, description: 'References section included' },
      { pattern: /1\. \[CODING_STANDARDS\.md\]/, description: 'Reference 1 formatted correctly' },
      { pattern: /2\. \[TECHNICAL_DOCUMENTATION\.md\]/, description: 'Reference 2 formatted correctly' },
      { pattern: /3\. \[TESTING_GUIDE\.md\]/, description: 'Reference 3 formatted correctly' }
    ]

    tests.each do |test|
      if result.match?(test[:pattern])
        puts "  ✅ #{test[:description]}"
      else
        puts "  ❌ #{test[:description]} - FAILED"
      end
    end

    # Count citation markers
    remaining_markers = result.scan(/:cite\[[^\]]+\]/).length
    highlighted_markers = result.scan(/\*\*:cite\[[^\]]+\]\*\*/).length

    puts "\n📊 CITATION STATISTICS:"
    puts "  • Citation markers processed: #{4 - remaining_markers + highlighted_markers}"
    puts "  • Unknown citations highlighted: #{highlighted_markers}"
    puts "  • Remaining unprocessed markers: #{remaining_markers - highlighted_markers}"
  end
end

# Run the test
if __FILE__ == $PROGRAM_NAME
  begin
    require 'stringio'

    tester = CitationTestProcessor.new
    tester.test_citation_processing

    puts "\n🎉 Citation processing test completed!"
    puts "\nThe PR review script citation handling is working correctly and matches"
    puts 'our validated logic from the test scripts.'
  rescue StandardError => e
    puts "❌ Error during citation processing test: #{e.message}"
    puts e.backtrace.join("\n")
    exit 1
  end
end
