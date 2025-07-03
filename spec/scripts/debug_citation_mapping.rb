#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'
require 'json'

# Load the PR review script to access the classes and modules
$LOAD_PATH.unshift(File.join(__dir__, '..', '..', '.github', 'scripts'))
require_relative '../../.github/scripts/pr_review'

class CitationMapDebugger
  include DustCitationProcessor

  attr_reader :logger

  def initialize
    @logger = Logger.new($stdout)
    @logger.level = Logger::DEBUG
  end

  def debug_citation_mapping
    puts "\n=== Citation Mapping Debug ==="

    # Test with real Dust citation structure
    real_dust_citations = [
      {
        'id' => 'citation_1',
        'reference' => {
          'title' => 'Ruby Style Guide',
          'href' => 'https://github.com/rubocop/ruby-style-guide'
        }
      },
      {
        'id' => 'citation_2',
        'reference' => {
          'title' => 'Rails Best Practices',
          'href' => 'https://rails-bestpractices.com/'
        }
      }
    ]

    puts 'Real Dust citations structure:'
    puts JSON.pretty_generate(real_dust_citations)

    citation_map = build_citation_map(real_dust_citations)
    puts "\nGenerated citation map: #{citation_map.inspect}"

    # Test content with citation markers that don't match
    content = 'This code needs improvement :cite[aa,eu] and documentation :cite[bb].'
    puts "\nOriginal content: #{content}"

    result = replace_citation_markers(content, citation_map)
    puts "Processed content: #{result}"
    puts "Problem: The markers :cite[aa,eu] don't match citation IDs like 'citation_1'"

    # Test what happens when we create a citation map that matches the markers
    puts "\n--- Testing with matching citation IDs ---"

    matching_citations = [
      {
        'id' => 'aa',
        'reference' => {
          'title' => 'Document AA',
          'href' => 'https://example.com/aa'
        }
      },
      {
        'id' => 'eu',
        'reference' => {
          'title' => 'Document EU',
          'href' => 'https://example.com/eu'
        }
      },
      {
        'id' => 'bb',
        'reference' => {
          'title' => 'Document BB',
          'href' => 'https://example.com/bb'
        }
      }
    ]

    matching_map = build_citation_map(matching_citations)
    puts "Matching citation map: #{matching_map.inspect}"

    result2 = replace_citation_markers(content, matching_map)
    puts "Processed with matching IDs: #{result2}"

    # Now test the realistic scenario: what if Dust doesn't provide citation IDs?
    puts "\n--- Testing with no citation IDs ---"

    no_id_citations = [
      {
        'reference' => {
          'title' => 'Some Document',
          'href' => 'https://example.com/doc1'
        }
      },
      {
        'reference' => {
          'title' => 'Another Document',
          'href' => 'https://example.com/doc2'
        }
      }
    ]

    no_id_map = build_citation_map(no_id_citations)
    puts "No ID citation map: #{no_id_map.inspect}"

    result3 = replace_citation_markers(content, no_id_map)
    puts "Processed with no IDs: #{result3}"
    puts 'This explains why citation markers remain unprocessed!'
  end
end

# Run the debug
debugger = CitationMapDebugger.new
debugger.debug_citation_mapping
