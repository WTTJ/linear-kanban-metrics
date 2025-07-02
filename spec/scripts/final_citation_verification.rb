#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'

# Load the PR review script
$LOAD_PATH.unshift(File.join(__dir__, '..', '..', '.github', 'scripts'))
require_relative '../../.github/scripts/pr_review'

# Test specifically for unwrapped :cite markers
test_content = "Review: :cite[aa,bb] and :cite[cc]"
processor = Class.new { include DustCitationProcessor }.new

puts "Original: #{test_content}"
result = processor.format_response_with_citations(test_content, [])
puts "Processed with no citations: #{result}"

# Look for unwrapped citation markers (the problematic ones)
unwrapped_markers = result.scan(/(?<!\*\*):cite\[[^\]]+\](?!\*\*)/)

puts "\n🎯 VERIFICATION:"
puts "Raw unwrapped :cite[...] markers found: #{unwrapped_markers.any? ? unwrapped_markers : 'NONE ✅'}"
puts "All markers properly wrapped: #{unwrapped_markers.empty? ? 'YES ✅' : 'NO ❌'}"

if unwrapped_markers.empty?
  puts "\n🎉 SUCCESS: The fix is working! No more unprocessed citation markers will appear in GitHub comments."
else
  puts "\n❌ ISSUE: There are still unwrapped citation markers that would appear raw in GitHub."
end
