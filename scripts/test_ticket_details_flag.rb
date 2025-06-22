#!/usr/bin/env ruby
# frozen_string_literal: true

# Test script to verify --ticket-details flag behavior
require_relative '../lib/kanban_metrics'

puts '=== Testing --ticket-details Flag Behavior ==='

# Sample data
metrics = {
  total_issues: 5,
  completed_issues: 3,
  in_progress_issues: 1,
  backlog_issues: 1,
  cycle_time: { average: 5.5, median: 4.0, p95: 10.0 },
  lead_time: { average: 8.2, median: 6.5, p95: 15.0 },
  throughput: { weekly_avg: 2.1, total_completed: 3 },
  flow_efficiency: 72.3
}

issues = [
  {
    'id' => 'test-1',
    'identifier' => 'TEST-1',
    'title' => 'Test issue 1',
    'state' => { 'name' => 'Done', 'type' => 'completed' },
    'team' => { 'name' => 'Test Team' },
    'assignee' => { 'name' => 'Test User' },
    'priority' => 1,
    'estimate' => 3,
    'createdAt' => '2024-01-01T09:00:00Z',
    'completedAt' => '2024-01-03T17:00:00Z',
    'startedAt' => '2024-01-02T10:00:00Z'
  }
]

puts "\n1. CSV WITHOUT --ticket-details (issues = nil):"
puts '=' * 50
formatter_without = KanbanMetrics::Formatters::CsvFormatter.new(metrics, nil, nil, nil)
csv_without = formatter_without.generate
puts csv_without

puts "\n2. CSV WITH --ticket-details (issues provided):"
puts '=' * 50
formatter_with = KanbanMetrics::Formatters::CsvFormatter.new(metrics, nil, nil, issues)
csv_with = formatter_with.generate
puts csv_with

puts "\n=== Verification ==="
puts 'Without --ticket-details:'
puts "  ✓ Contains overall metrics: #{csv_without.include?('Total Issues') ? 'YES' : 'NO'}"
puts "  ✓ Contains individual tickets: #{csv_without.include?('INDIVIDUAL TICKETS') ? 'YES' : 'NO'}"

puts "\nWith --ticket-details:"
puts "  ✓ Contains overall metrics: #{csv_with.include?('Total Issues') ? 'YES' : 'NO'}"
puts "  ✓ Contains individual tickets: #{csv_with.include?('INDIVIDUAL TICKETS') ? 'YES' : 'NO'}"
puts "  ✓ Contains ticket data: #{csv_with.include?('TEST-1') ? 'YES' : 'NO'}"

puts "\n=== Test Complete ==="
