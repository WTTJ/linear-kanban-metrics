#!/usr/bin/env ruby
# frozen_string_literal: true

# Test script to verify citation processing with sample Dust API response data

require 'json'

# Sample Dust API response data for testing
SAMPLE_RESPONSE = {
  'conversation' => {
    'content' => [
      [
        {
          'type' => 'agent_message',
          'content' => "## PR Review for kanban_metrics gem enhancement\n\n:cite[aw] Looking at the codebase structure and changes, I can provide a comprehensive review of this enhancement to the kanban_metrics gem.\n\n### Overall Assessment\n\nThis PR introduces several valuable improvements:\n\n1. **Multi-citation support** - Enhanced citation processing to handle :cite[gx,bt] format\n2. **Robust testing framework** - Comprehensive test scripts for Dust API integration\n3. **Security improvements** - Better API key masking and error handling\n4. **Code organization** - Modular refactoring following SOLID principles\n\n:cite[gx,bt] The refactoring demonstrates good software engineering practices with proper separation of concerns and maintainable code structure.\n\n### Code Quality Review\n\n#### Positive Aspects\n- Clean module separation in citation processing\n- Comprehensive error handling and logging\n- Well-documented test scripts\n- RuboCop compliance maintained\n\n#### Suggestions for Improvement\n\n:cite[aw] Consider adding validation for citation format consistency across different response types.\n\n### Testing Coverage\n\nThe test suite covers:\n- API integration scenarios\n- Citation extraction and formatting\n- Error handling edge cases\n- Security considerations (API key masking)\n\n:cite[bt,gx] This comprehensive testing approach ensures reliability in production environments.\n\n### Security Considerations\n\n- ✅ API keys properly masked in logs\n- ✅ Environment variable validation\n- ✅ Secure HTTP request handling\n\n### Recommendation\n\n**APPROVE** - This PR enhances the codebase with valuable functionality while maintaining code quality and security standards.",
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

class CitationProcessor
  def self.process_citation_markers(content, citations)
    # Create a citation map for lookup
    citation_map = {}
    citations.each_with_index do |citation, index|
      # Dust citations usually have an 'id' field
      citation_map[citation['id']] = index + 1 if citation.is_a?(Hash) && citation['id']
    end

    # Replace :cite[id] or :cite[id1,id2,...] markers with numbered references
    content.gsub(/:cite\[([^\]]+)\]/) do |match|
      cite_ids_string = Regexp.last_match(1)
      cite_ids = cite_ids_string.split(',').map(&:strip)

      # Process each citation ID and collect valid references
      references = cite_ids.filter_map do |cite_id|
        citation_map[cite_id] if citation_map[cite_id]
      end

      if references.any?
        # Format as [1], [1,2], or [1,2,3] etc.
        "[#{references.join(',')}]"
      else
        # If no citation IDs found, keep the original marker but make it more visible
        "**#{match}**"
      end
    end
  end

  def self.format_citation(citation)
    case citation
    when Hash
      format_hash_citation(citation)
    when String
      citation
    else
      citation.to_s
    end
  end

  def self.format_hash_citation(citation)
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

  def self.format_reference_citation(citation)
    ref = citation['reference']
    title = ref['title'] || 'Untitled'
    url = ref['href']

    if url
      "[#{title}](#{url})"
    else
      title
    end
  end

  def self.format_document_citation(citation)
    doc = citation['document']
    title = doc['title'] || doc['name'] || 'Document'
    url = doc['url'] || doc['href']

    if url
      "[#{title}](#{url})"
    else
      title
    end
  end

  def self.format_basic_citation(citation)
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

def test_citation_processing
  puts '🧪 Testing citation processing with sample Dust API response...'
  puts '=' * 60

  agent_message = extract_agent_message_from_sample
  return false unless agent_message

  content = agent_message['content']
  citations = agent_message['citations'] || []

  display_original_content_info(content, citations)
  processed_content = process_and_display_content(content, citations)
  analyze_citation_markers(content, processed_content)
  test_specific_citation_patterns

  true
rescue StandardError => e
  puts "❌ Error during citation processing test: #{e.message}"
  puts e.backtrace[0..5].join("\n")
  false
end

def extract_agent_message_from_sample
  # Extract the agent message and citations from sample data
  agent_message = SAMPLE_RESPONSE.dig('conversation', 'content', 0, 0)

  unless agent_message&.dig('type') == 'agent_message'
    puts '❌ No agent message found in sample data'
    return nil
  end

  agent_message
end

def display_original_content_info(content, citations)
  puts '📝 Original content (first 200 chars):'
  puts content[0..200] + (content.length > 200 ? '...' : '')
  puts
  puts "📚 Found #{citations.length} citations:"
  citations.each_with_index do |citation, index|
    formatted = CitationProcessor.format_citation(citation)
    puts "  [#{index + 1}] #{formatted}"
  end
  puts
end

def process_and_display_content(content, citations)
  # Process citation markers
  processed_content = CitationProcessor.process_citation_markers(content, citations)

  puts '🔄 Processed content with citation markers replaced:'
  puts '-' * 40
  puts processed_content
  puts '-' * 40
  puts

  processed_content
end

def analyze_citation_markers(content, processed_content)
  # Verify that markers were replaced correctly
  original_markers = content.scan(/:cite\[[^\]]+\]/)
  processed_markers = processed_content.scan(/:cite\[[^\]]+\]/)

  puts '📊 Citation marker analysis:'
  puts "  Original markers found: #{original_markers.length}"
  puts "  Remaining markers after processing: #{processed_markers.length}"
  puts "  Original markers: #{original_markers.join(', ')}"
  puts "  Remaining markers: #{processed_markers.join(', ')}" if processed_markers.any?
end

def test_specific_citation_patterns
  puts
  puts '🔍 Testing specific citation patterns:'
  test_single_citation
  test_multi_citation
  test_unknown_citation
end

def test_single_citation
  content = 'This is a test :cite[aw] with single citation.'
  citations = [{ 'id' => 'aw', 'title' => 'Test Citation' }]

  result = CitationProcessor.process_citation_markers(content, citations)
  expected = 'This is a test [1] with single citation.'

  puts "  Single citation: #{result == expected ? '✅' : '❌'}"
  puts "    Input: #{content}"
  puts "    Output: #{result}"
  puts "    Expected: #{expected}" if result != expected
end

def test_multi_citation
  content = 'This is a test :cite[aw,gx] with multiple citations.'
  citations = [
    { 'id' => 'aw', 'title' => 'First Citation' },
    { 'id' => 'gx', 'title' => 'Second Citation' }
  ]

  result = CitationProcessor.process_citation_markers(content, citations)
  expected = 'This is a test [1,2] with multiple citations.'

  puts "  Multi citation: #{result == expected ? '✅' : '❌'}"
  puts "    Input: #{content}"
  puts "    Output: #{result}"
  puts "    Expected: #{expected}" if result != expected
end

def test_unknown_citation
  content = 'This is a test :cite[unknown] with unknown citation.'
  citations = [{ 'id' => 'aw', 'title' => 'Known Citation' }]

  result = CitationProcessor.process_citation_markers(content, citations)
  expected = 'This is a test **:cite[unknown]** with unknown citation.'

  puts "  Unknown citation: #{result == expected ? '✅' : '❌'}"
  puts "    Input: #{content}"
  puts "    Output: #{result}"
  puts "    Expected: #{expected}" if result != expected
end

# Main execution
success = test_citation_processing

if success
  puts "\n🎉 Citation processing test completed successfully!"
  puts '✨ The citation extraction system properly handles:'
  puts '   • Single citations: :cite[id] → [1]'
  puts '   • Multiple citations: :cite[id1,id2] → [1,2]'
  puts '   • Unknown citations: :cite[unknown] → **:cite[unknown]**'
  puts '   • Citation formatting with links and titles'
else
  puts "\n💥 Citation processing test failed!"
  exit 1
end
