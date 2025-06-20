#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/kanban_metrics'

# Test script to verify team key and UUID functionality
puts '🧪 Testing team identifier functionality...'

# Test data
test_cases = [
  { identifier: 'ROI', type: 'key', expected_filter: 'team: { key: { eq: "ROI" } }' },
  { identifier: '5cb3ee70-693d-406b-a6a5-23a002ef10d6', type: 'UUID',
    expected_filter: 'team: { id: { eq: "5cb3ee70-693d-406b-a6a5-23a002ef10d6" } }' },
  { identifier: 'FRONT', type: 'key', expected_filter: 'team: { key: { eq: "FRONT" } }' },
  { identifier: 'c9dae417-1351-4c92-9a59-ea972c65f5ed', type: 'UUID',
    expected_filter: 'team: { id: { eq: "c9dae417-1351-4c92-9a59-ea972c65f5ed" } }' }
]

query_builder = KanbanMetrics::Linear::QueryBuilder.new

puts "\n📋 Testing QueryBuilder logic:"
test_cases.each do |test_case|
  options = KanbanMetrics::QueryOptions.new(team_id: test_case[:identifier], page_size: 5)
  query = query_builder.build_issues_query(options)

  if query.include?(test_case[:expected_filter])
    puts "  ✅ #{test_case[:identifier]} (#{test_case[:type]}) - Correct filter generated"
  else
    puts "  ❌ #{test_case[:identifier]} (#{test_case[:type]}) - WRONG filter generated"
    puts "     Expected: #{test_case[:expected_filter]}"
    puts "     Query: #{query}"
  end
end

puts "\n🌐 Testing CLI functionality:"
if ENV['LINEAR_API_TOKEN']
  puts '  Testing ROI team key via CLI...'
  result = system('./bin/kanban_metrics --team-id ROI --no-cache > /dev/null 2>&1')
  puts result ? '  ✅ ROI key works via CLI' : '  ❌ ROI key fails via CLI'

  puts '  Testing ROI team UUID via CLI...'
  result = system('./bin/kanban_metrics --team-id 5cb3ee70-693d-406b-a6a5-23a002ef10d6 --no-cache > /dev/null 2>&1')
  puts result ? '  ✅ ROI UUID works via CLI' : '  ❌ ROI UUID fails via CLI'
else
  puts '  ⚠️  Skipping CLI test - LINEAR_API_TOKEN not set'
end

puts "\n🎉 Testing complete!"
