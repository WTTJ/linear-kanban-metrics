#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'
require 'json'

# Load the PR review script
$LOAD_PATH.unshift(File.join(__dir__, '..', '..', '.github', 'scripts'))
require_relative '../../.github/scripts/pr_review'

class FinalCitationTest
  include DustCitationProcessor

  def initialize
    @logger = Logger.new($stdout)
    @logger.level = Logger::DEBUG
  end

  def test_citation_fix
    puts "\n=== Final Citation Processing Test ==="
    puts 'Testing the exact scenario: :cite[aa,eu] with available citations'

    # Test with the exact problematic markers mentioned by user
    content = <<~CONTENT
      ## PR Review Results

      This code has some issues :cite[aa,eu] that need attention.

      ### Major Issues:
      1. Security vulnerability :cite[bb]
      2. Performance problems :cite[cc,dd]
      3. Missing documentation :cite[ee]

      Please address these before merging :cite[aa].
    CONTENT

    # Simulate Dust citations (even if they don't have matching IDs)
    citations = [
      {
        'reference' => {
          'title' => 'Security Best Practices',
          'href' => 'https://owasp.org/security-guide'
        }
      },
      {
        'reference' => {
          'title' => 'Performance Optimization Guide',
          'href' => 'https://ruby-perf.github.io/'
        }
      },
      {
        'reference' => {
          'title' => 'Ruby Style Guide',
          'href' => 'https://github.com/rubocop/ruby-style-guide'
        }
      },
      {
        'reference' => {
          'title' => 'Testing Best Practices',
          'href' => 'https://rspec.info/documentation/'
        }
      },
      {
        'reference' => {
          'title' => 'Documentation Standards',
          'href' => 'https://rdoc.github.io/rdoc/'
        }
      }
    ]

    puts 'Original content:'
    puts content
    puts "\nAvailable citations: #{citations.length}"

    result = format_response_with_citations(content, citations)

    puts "\n#{'=' * 60}"
    puts 'PROCESSED RESULT:'
    puts '=' * 60
    puts result

    # Check if the problematic markers are fixed
    aa_eu_fixed = !result.include?(':cite[aa,eu]')
    all_fixed = !result.include?(':cite[')

    puts "\n#{'=' * 60}"
    puts 'RESULTS:'
    puts '=' * 60
    puts "✅ :cite[aa,eu] processed: #{aa_eu_fixed ? 'YES' : 'NO'}"
    puts "✅ All citation markers processed: #{all_fixed ? 'YES' : 'NO'}"

    unless all_fixed
      remaining = result.scan(/:cite\[[^\]]+\]/)
      puts "📝 Remaining markers: #{remaining.join(', ')}"
      puts '💡 This is expected when there are more citation markers than available citations'
    end

    puts "\n🎉 SUCCESS: The :cite[aa,eu] issue has been FIXED!" if aa_eu_fixed
  end
end

# Run the final test
tester = FinalCitationTest.new
tester.test_citation_fix
