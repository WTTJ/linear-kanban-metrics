#!/usr/bin/env ruby
# frozen_string_literal: true

# Test script to verify the HTML output format of citations in markdown
require 'logger'
require 'stringio'
require_relative '../../.github/scripts/pr_review'

# Create a test instance with sample citations
class CitationFormatTester
  include DustCitationProcessor

  attr_reader :logger

  def initialize
    @logger = Logger.new(StringIO.new) # Silent logger
  end

  def test_citation_html_output
    puts '=' * 80
    puts 'Testing Citation HTML Output Format'
    puts '=' * 80

    content = sample_content
    citations = sample_citations
    result = format_response_with_citations(content, citations)

    display_processed_output(result)
    verify_html_formats(result)
    show_html_preview(result)
  end

  private

  def sample_content
    <<~CONTENT
      This is a test with a single citation :cite[ref1].

      Here are multiple citations :cite[ref1,ref2] in one marker.

      And here's another multi-citation :cite[ref3,ref1,ref2] with three references.

      Unknown citation should be highlighted: :cite[unknown].
    CONTENT
  end

  def sample_citations
    [
      {
        'id' => 'ref1',
        'reference' => {
          'title' => 'Ruby Style Guide',
          'href' => 'https://github.com/rubocop/ruby-style-guide'
        }
      },
      {
        'id' => 'ref2',
        'reference' => {
          'title' => 'Design Patterns in Ruby',
          'href' => 'https://refactoring.guru/design-patterns/ruby'
        }
      },
      {
        'id' => 'ref3',
        'reference' => {
          'title' => 'Value Objects in Ruby',
          'href' => 'https://medium.com/@dannysmith/little-thing-value-objects-in-ruby-c4745aeb9c07'
        }
      }
    ]
  end

  def display_processed_output(result)
    puts "\n📝 PROCESSED MARKDOWN OUTPUT:"
    puts '-' * 50
    puts result
    puts '-' * 50
  end

  def verification_tests
    citation_format_tests + anchor_and_link_tests
  end

  def citation_format_tests
    [
      {
        pattern: %r{<sup>\[1\]\(#ref-1\)</sup>},
        description: 'Single citation renders as clickable superscript'
      },
      {
        pattern: %r{<sup>\[1\]\(#ref-1\),\[2\]\(#ref-2\)</sup>},
        description: 'Multi-citation renders as comma-separated links'
      },
      {
        pattern: %r{<sup>\[3\]\(#ref-3\),\[1\]\(#ref-1\),\[2\]\(#ref-2\)</sup>},
        description: 'Three citations render correctly'
      },
      {
        pattern: /\*\*:cite\[unknown\]\*\*/,
        description: 'Unknown citations are highlighted'
      }
    ]
  end

  def anchor_and_link_tests
    [
      {
        pattern: %r{<a id="ref-1"></a>1\.},
        description: 'Reference anchors are created correctly'
      },
      {
        pattern: %r{\[Ruby Style Guide\]\(https://github\.com/rubocop/ruby-style-guide\)},
        description: 'Reference links are formatted correctly'
      }
    ]
  end

  def verify_html_formats(result)
    puts "\n✅ HTML FORMAT VERIFICATION:"

    verification_tests.each do |test|
      if result.match?(test[:pattern])
        puts "  ✅ #{test[:description]}"
      else
        puts "  ❌ #{test[:description]} - FAILED"
      end
    end
  end

  def show_html_preview(result)
    puts "\n🌐 HTML PREVIEW (how it would look in a browser):"
    puts '-' * 50

    # Convert basic markdown to HTML for preview
    html_preview = result
                   .gsub(/^# (.+)/, '<h1>\1</h1>')
                   .gsub(/^## (.+)/, '<h2>\1</h2>')
                   .gsub(/\*\*(.+?)\*\*/, '<strong>\1</strong>')
                   .gsub("\n\n", '<br><br>')
                   .gsub("\n", '<br>')

    puts html_preview
    puts '-' * 50

    puts "\n📋 CITATION CLICK BEHAVIOR:"
    puts '• Clicking [1] will scroll to reference #1'
    puts '• Each reference has an anchor tag for navigation'
    puts '• Multi-citations like [1,2] provide multiple clickable links'
    puts '• Unknown citations are visually highlighted with bold formatting'
  end
end

# Run the test
CitationFormatTester.new.test_citation_html_output

puts "\n🎉 Citation HTML output format test completed!"
puts 'The citations are now markdown-friendly with clickable links!'
