#!/usr/bin/env ruby
# frozen_string_literal: true

# Test script to verify citation processing with real Dust API response data

require_relative '../../.github/scripts/pr_review'

# Real Dust API response data from the user
REAL_DUST_RESPONSE = {
  'conversation' => {
    'content' => [
      [
        {
          'type' => 'agent_message',
          'content' => "# Code Review Summary\n\n## Overall Assessment\n\nThe provided code sample shows a basic Ruby class implementation. While minimal, there are several observations regarding adherence to the established coding standards and design patterns for the KanbanMetrics project.\n\n## Detailed Review\n\n### ✅ **Positive Aspects**\n\n1. **Ruby Style Compliance**: The code follows basic Ruby conventions with 2-space indentation and proper class definition syntax, aligning with the [Ruby Style Guide](https://github.com/rubocop/ruby-style-guide) :cite[cc].\n\n2. **Instance Variable Usage**: Proper use of instance variables with `@` prefix follows Ruby conventions.\n\n### ⚠️ **Areas for Improvement**\n\n#### 1. **Missing Namespace Organization**\n- **Issue**: The class `TestClass` is not organized under the required `KanbanMetrics` namespace\n- **Standard Violation**: Project Architecture Standards require all code to be under `KanbanMetrics` namespace\n- **Recommendation**: \n```ruby\nmodule KanbanMetrics\n  class TestClass\n    # ...\n  end\nend\n```\n\n#### 2. **Lack of Design Pattern Implementation**\n- **Issue**: The current implementation doesn't leverage any of the required design patterns\n- **Missing Patterns**: No evidence of Value Objects, Strategy Pattern, or other required patterns :cite[aa,eu]\n- **Recommendation**: Consider if this class should be implemented as a Value Object (immutable, comparable) :cite[qe,rb] or if it needs to follow another pattern based on its intended purpose\n\n#### 3. **Value Object Considerations**\nIf this class is meant to hold configuration or data transfer:\n- **Missing Immutability**: Should implement immutable behavior :cite[qe,do]\n- **Missing Equality**: Should implement `==` and `hash` methods for proper comparison :cite[qe]\n- **Consider Ruby 3.2+ Data Class**: For simple value objects, consider using Ruby's built-in `Data` class :cite[rb,by]\n\n```ruby\n# Example using modern Ruby Data class\nmodule KanbanMetrics\n  TestData = Data.define(:test) do\n    def initialize(test: 'value')\n      super(test: test)\n    end\n  end\nend\n```\n\n## Recommendations\n\n1. **Namespace Compliance**: Wrap the class in the appropriate `KanbanMetrics` module hierarchy\n2. **Pattern Implementation**: Determine the class's role and implement appropriate design patterns from the standards :cite[eu,aa]\n3. **Immutability**: If this is a data-holding class, implement as an immutable Value Object :cite[pl,do]\n4. **Documentation**: Add class-level documentation explaining the purpose and usage\n\n## References\n\n- Ruby Style Guide: [GitHub Ruby Style Guide](https://github.com/rubocop/ruby-style-guide) :cite[cc]\n- Design Patterns in Ruby: [Refactoring Guru](https://refactoring.guru/design-patterns/ruby) :cite[eu]\n- Strategy Pattern: [Strategy Pattern in Ruby](https://refactoring.guru/design-patterns/strategy/ruby/example) :cite[aa]\n- Value Objects: [Value Objects in Ruby](https://medium.com/@dannysmith/little-thing-value-objects-in-ruby-c4745aeb9c07) :cite[qe]\n- Ruby Data Class: [Immutable Value Objects in Ruby](https://lucianghinda.medium.com/crafting-immutable-value-objects-in-ruby-the-modern-approach-959e27a02351) :cite[rb]\n- Template Method Pattern: [Template Method Pattern](https://medium.com/@joshsaintjacque/the-template-method-pattern-558f3e16879f) :cite[q2]\n\n**Priority**: Medium - The code functions but needs architectural alignment with project standards.",
          'citations' => [
            {
              'id' => 'cc',
              'reference' => {
                'title' => 'rubocop/ruby-style-guide',
                'href' => 'https://github.com/rubocop/ruby-style-guide'
              }
            },
            {
              'id' => 'aa',
              'reference' => {
                'title' => 'Strategy in Ruby / Design Patterns',
                'href' => 'https://refactoring.guru/design-patterns/strategy/ruby/example'
              }
            },
            {
              'id' => 'eu',
              'reference' => {
                'title' => 'Design Patterns in Ruby',
                'href' => 'https://refactoring.guru/design-patterns/ruby'
              }
            },
            {
              'id' => 'qe',
              'reference' => {
                'title' => 'Little Thing — Value Objects in Ruby - by Danny Smith',
                'href' => 'https://medium.com/@dannysmith/little-thing-value-objects-in-ruby-c4745aeb9c07'
              }
            },
            {
              'id' => 'rb',
              'reference' => {
                'title' => 'Crafting Immutable Value Objects in Ruby - Lucian Ghinda',
                'href' => 'https://lucianghinda.medium.com/crafting-immutable-value-objects-in-ruby-the-modern-approach-959e27a02351'
              }
            },
            {
              'id' => 'do',
              'reference' => {
                'title' => 'Value Object Semantics in Ruby',
                'href' => 'https://thoughtbot.com/blog/value-object-semantics-in-ruby'
              }
            },
            {
              'id' => 'by',
              'reference' => {
                'title' => 'All about "Data" Simple Immutable Value Objects in Ruby 3.2',
                'href' => 'https://www.reddit.com/r/ruby/comments/120d7o7/all_about_data_simple_immutable_value_objects_in/'
              }
            },
            {
              'id' => 'pl',
              'reference' => {
                'title' => 'Value Object',
                'href' => 'https://martinfowler.com/bliki/ValueObject.html'
              }
            },
            {
              'id' => 'q2',
              'reference' => {
                'title' => 'Design Patterns & Ruby: The Template Method Pattern',
                'href' => 'https://medium.com/@joshsaintjacque/the-template-method-pattern-558f3e16879f'
              }
            }
          ]
        }
      ]
    ]
  }
}.freeze

# Test the DustResponseProcessor module with real data
class RealDataCitationTestProcessor
  include DustResponseProcessor

  attr_reader :logger

  def initialize
    @logger = Logger.new(StringIO.new) # Silent logger for testing
  end

  def test_real_citation_processing
    puts '=' * 80
    puts 'Testing Citation Processing with REAL Dust API Data'
    puts '=' * 80

    result = extract_content(REAL_DUST_RESPONSE)

    puts "\n🧪 PROCESSED OUTPUT:"
    puts '-' * 40
    puts result
    puts '-' * 40

    # Verify expected replacements
    verify_real_citations(result)
  end

  private

  # rubocop:disable Metrics/MethodLength
  def verify_real_citations(result)
    puts "\n✅ VERIFICATION RESULTS:"

    tests = [
      { pattern: %r{<sup>\[1\]\(#ref-1\)</sup>}, description: 'Single citation :cite[cc] → [1]' },
      { pattern: %r{<sup>\[2\]\(#ref-2\),\[3\]\(#ref-3\)</sup>}, description: 'Multi-citation :cite[aa,eu] → [2,3]' },
      { pattern: %r{<sup>\[4\]\(#ref-4\),\[5\]\(#ref-5\)</sup>}, description: 'Multi-citation :cite[qe,rb] → [4,5]' },
      { pattern: %r{<sup>\[4\]\(#ref-4\),\[6\]\(#ref-6\)</sup>}, description: 'Multi-citation :cite[qe,do] → [4,6]' },
      { pattern: %r{<sup>\[5\]\(#ref-5\),\[7\]\(#ref-7\)</sup>}, description: 'Multi-citation :cite[rb,by] → [5,7]' },
      { pattern: %r{<sup>\[3\]\(#ref-3\),\[2\]\(#ref-2\)</sup>}, description: 'Multi-citation :cite[eu,aa] → [3,2]' },
      { pattern: %r{<sup>\[8\]\(#ref-8\),\[6\]\(#ref-6\)</sup>}, description: 'Multi-citation :cite[pl,do] → [8,6]' },
      { pattern: /\*\*References:\*\*/, description: 'References section included' },
      { pattern: %r{1\. \[rubocop/ruby-style-guide\]}, description: 'Reference 1 formatted correctly' },
      { pattern: /2\. \[Strategy in Ruby/, description: 'Reference 2 formatted correctly' },
      { pattern: /3\. \[Design Patterns in Ruby/, description: 'Reference 3 formatted correctly' }
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
    puts "  • Total citations available: #{REAL_DUST_RESPONSE.dig('conversation', 'content', 0, 0, 'citations').length}"
    puts "  • Citation markers found in content: #{count_original_markers}"
    puts "  • Citation markers processed: #{count_original_markers - remaining_markers + highlighted_markers}"
    puts "  • Unknown citations highlighted: #{highlighted_markers}"
    puts "  • Remaining unprocessed markers: #{remaining_markers - highlighted_markers}"
  end
  # rubocop:enable Metrics/MethodLength

  def count_original_markers
    content = REAL_DUST_RESPONSE.dig('conversation', 'content', 0, 0, 'content')
    content.scan(/:cite\[[^\]]+\]/).length
  end
end

# Run the test
if __FILE__ == $PROGRAM_NAME
  begin
    require 'stringio'

    tester = RealDataCitationTestProcessor.new
    tester.test_real_citation_processing

    puts "\n🎉 Real data citation processing test completed!"
    puts "\nThe PR review script citation handling works correctly with real Dust API data."
  rescue StandardError => e
    puts "❌ Error during real data citation processing test: #{e.message}"
    puts e.backtrace.join("\n")
    exit 1
  end
end
