#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'

# Load the PR review script
$LOAD_PATH.unshift(File.join(__dir__, '..', '..', '.github', 'scripts'))
require_relative '../../.github/scripts/pr_review'

# Simple test to confirm the fix
test_content = "Review: :cite[aa,bb] and :cite[cc]"
processor = Class.new { include DustCitationProcessor }.new

puts "Original: #{test_content}"
puts "Processed with no citations: #{processor.format_response_with_citations(test_content, [])}"

# Check if raw :cite[ markers remain (they shouldn't)
result = processor.format_response_with_citations(test_content, [])
raw_markers = result.scan(/:cite\[[^\]]+\]/).reject { |m| m.start_with?('**') }

puts "Raw unprocessed markers remaining: #{raw_markers.any? ? raw_markers : 'NONE ✅'}"
puts "All markers are now wrapped: #{result.include?('**:cite[') ? 'YES ✅' : 'NO ❌'}"
