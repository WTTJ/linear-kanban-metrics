#!/usr/bin/env ruby
# frozen_string_literal: true

# Debug script to understand why citations aren't being processed correctly
# This script uses the REAL response data from your log to debug the issue

require 'bundler/setup'
require 'logger'
require 'json'

# Load the PR review script
require_relative '../../.github/scripts/pr_review'

# Your actual response data from the log (truncated for the key parts)
REAL_RESPONSE_DATA = {
  'conversation' => {
    'content' => [
      [
        {
          'type' => 'agent_message',
          'content' => "# PR Review: Citation Processing Enhancement\n\n## 🔍 Code Quality & Architecture\n\n### ✅ Strengths\n\n**Module Organization & Separation of Concerns** :cite[aa,eu]\n- Excellent refactoring of citation processing into dedicated modules\n\n**Design Pattern Implementation** :cite[hj]\n- **Strategy Pattern**: Citation formatting handles different citation types\n\n### ⚠️ Areas for Improvement\n\n**Namespace Organization** :cite[cc,gx]\n- The modules are not under the `KanbanMetrics` namespace",
          'citations' => [
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
        }
      ]
    ]
  }
}.freeze

class CitationDebugger
  include DustResponseProcessor

  attr_reader :logger

  def initialize
    @logger = Logger.new($stdout)
    @logger.level = Logger::DEBUG
  end

  def debug_citation_processing
    puts '🔍 Citation Processing Debug'
    puts '=' * 50
    puts

    # Extract data like the real code does
    agent_message = REAL_RESPONSE_DATA.dig('conversation', 'content', 0, 0)
    content = agent_message['content']
    citations = agent_message['citations'] || []

    puts '📄 ORIGINAL CONTENT (first 200 chars):'
    puts "#{content[0..200]}..."
    puts

    puts '📚 CITATIONS FOUND:'
    citations.each_with_index do |citation, index|
      puts "  [#{index + 1}] ID: '#{citation['id']}' - #{citation.dig('reference', 'title')}"
    end
    puts

    # Test the citation map building
    puts '🗺️  CITATION MAP:'
    citation_map = build_citation_map(citations)
    citation_map.each do |id, number|
      puts "  '#{id}' -> #{number}"
    end
    puts

    # Test citation marker replacement
    puts '🔄 CITATION MARKER TESTING:'
    test_markers = [':cite[aa,eu]', ':cite[hj]', ':cite[cc,gx]', ':cite[unknown]']
    test_markers.each do |marker|
      result = replace_citation_markers(marker, citation_map)
      puts "  #{marker} -> #{result}"
    end
    puts

    # Full processing
    puts '✨ FULL PROCESSING RESULT:'
    puts '-' * 30
    result = format_response_with_citations(content, citations)
    puts result
    puts '-' * 30
  end

  private

  def build_citation_map(citations)
    citation_map = {}
    citations.each_with_index do |citation, index|
      citation_map[citation['id']] = index + 1 if citation.is_a?(Hash) && citation['id']
    end
    citation_map
  end

  def replace_citation_markers(content, citation_map)
    content.gsub(/:cite\[([^\]]+)\]/) do |match|
      cite_ids_string = Regexp.last_match(1)
      cite_ids = cite_ids_string.split(',').map(&:strip)

      # Process each citation ID and collect valid references
      references = cite_ids.filter_map do |cite_id|
        citation_map[cite_id] if citation_map[cite_id]
      end

      if references.any?
        # Format as markdown superscript-style reference links
        if references.length == 1
          "<sup>[#{references.first}](#ref-#{references.first})</sup>"
        else
          ref_links = references.map { |ref| "[#{ref}](#ref-#{ref})" }
          "<sup>#{ref_links.join(',')}</sup>"
        end
      else
        # If no citation IDs found, keep the original marker but make it more visible
        "**#{match}**"
      end
    end
  end

  def format_response_with_citations(content, citations)
    # Create a citation map for lookup
    citation_map = build_citation_map(citations)

    # Replace inline citation markers with numbered references
    formatted_content = replace_citation_markers(content, citation_map)

    # Add reference list at the end if we have citations
    if citations.any?
      formatted_content << "\n\n---\n\n**References:**\n\n"
      citations.each_with_index do |citation, index|
        ref_number = index + 1
        formatted_content << "<a id=\"ref-#{ref_number}\"></a>#{ref_number}. #{format_citation(citation)}\n\n"
      end
    end

    formatted_content
  end

  def format_citation(citation)
    case citation
    when Hash
      format_hash_citation(citation)
    when String
      citation
    else
      citation.to_s
    end
  end

  def format_hash_citation(citation)
    # Handle Dust's various citation formats
    if citation['reference']
      format_reference_citation(citation)
    elsif citation['document']
      format_document_citation(citation)
    elsif citation['title'] || citation['url']
      format_basic_citation(citation)
    else
      citation.to_s
    end
  end

  def format_reference_citation(citation)
    ref = citation['reference']
    title = ref['title'] || 'Untitled'
    url = ref['href']

    if url
      "[#{title}](#{url})"
    else
      title
    end
  end

  def format_document_citation(citation)
    doc = citation['document']
    title = doc['title'] || doc['name'] || 'Document'
    url = doc['url'] || doc['href']

    if url
      "[#{title}](#{url})"
    else
      title
    end
  end

  def format_basic_citation(citation)
    title = citation['title'] || citation['name'] || 'Reference'
    url = citation['url'] || citation['href']
    snippet = citation['snippet'] || citation['text']

    parts = []
    parts << if url
               "[#{title}](#{url})"
             else
               title
             end

    if snippet && snippet.length > 10
      # Add a snippet preview if available
      clean_snippet = snippet.strip.gsub(/\s+/, ' ')[0..100]
      parts << "\"#{clean_snippet}#{'...' if snippet.length > 100}\""
    end

    parts.join(' - ')
  end
end

# Run the debug
if __FILE__ == $PROGRAM_NAME
  debugger = CitationDebugger.new
  debugger.debug_citation_processing
end
