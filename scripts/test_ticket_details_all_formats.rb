#!/usr/bin/env ruby
# frozen_string_literal: true

# Test script to verify --ticket-details works for all output formats

require_relative '../lib/kanban_metrics'

# Sample data for testing
sample_metrics = {
  total_issues: 10,
  completed_issues: 6,
  in_progress_issues: 2,
  backlog_issues: 2,
  cycle_time: { average: 5.5, median: 4.0, p95: 12.0 },
  lead_time: { average: 8.2, median: 6.5, p95: 18.0 },
  throughput: { weekly_avg: 3.2, total_completed: 6 },
  flow_efficiency: 72.5
}

sample_team_metrics = {
  'Backend Team' => {
    total_issues: 6,
    completed_issues: 4,
    in_progress_issues: 1,
    backlog_issues: 1,
    cycle_time: { average: 4.8, median: 3.5 },
    lead_time: { average: 7.1, median: 5.8 },
    throughput: 4
  },
  'Frontend Team' => {
    total_issues: 4,
    completed_issues: 2,
    in_progress_issues: 1,
    backlog_issues: 1,
    cycle_time: { average: 6.5, median: 5.2 },
    lead_time: { average: 9.8, median: 8.1 },
    throughput: 2
  }
}

sample_issues = [
  {
    'identifier' => 'TEST-001',
    'title' => 'Implement user authentication',
    'state' => { 'name' => 'Done' },
    'createdAt' => '2024-06-01T09:00:00Z',
    'startedAt' => '2024-06-03T10:00:00Z',
    'completedAt' => '2024-06-08T16:00:00Z',
    'team' => { 'name' => 'Backend Team' },
    'priority' => 1,
    'estimate' => 5
  },
  {
    'identifier' => 'TEST-002',
    'title' => 'Fix responsive design issues',
    'state' => { 'name' => 'Done' },
    'createdAt' => '2024-06-02T11:00:00Z',
    'startedAt' => '2024-06-04T14:00:00Z',
    'completedAt' => '2024-06-07T12:00:00Z',
    'team' => { 'name' => 'Frontend Team' },
    'priority' => 2,
    'estimate' => 3
  },
  {
    'identifier' => 'TEST-003',
    'title' => 'Add error logging system',
    'state' => { 'name' => 'In Progress' },
    'createdAt' => '2024-06-05T08:00:00Z',
    'startedAt' => '2024-06-06T09:00:00Z',
    'completedAt' => nil,
    'team' => { 'name' => 'Backend Team' },
    'priority' => 2,
    'estimate' => 8
  }
]

def test_format(format, metrics, team_metrics, issues)
  puts "\n#{'=' * 60}"
  puts "Testing #{format.upcase} format with ticket details"
  puts '=' * 60

  begin
    report = KanbanMetrics::Reports::KanbanReport.new(metrics, team_metrics, nil, issues)
    report.display(format)
    puts "\n✅ #{format.upcase} format test completed successfully"
  rescue StandardError => e
    puts "\n❌ #{format.upcase} format test failed: #{e.message}"
    puts e.backtrace.first(3)
  end
end

puts '🧪 Testing --ticket-details functionality across all output formats'

# Test all three formats
test_format('table', sample_metrics, sample_team_metrics, sample_issues)
test_format('json', sample_metrics, sample_team_metrics, sample_issues)
test_format('csv', sample_metrics, sample_team_metrics, sample_issues)

puts "\n#{'=' * 60}"
puts 'Testing without ticket details (issues = nil)'
puts '=' * 60

test_format('table', sample_metrics, sample_team_metrics, nil)
test_format('json', sample_metrics, sample_team_metrics, nil)
test_format('csv', sample_metrics, sample_team_metrics, nil)

puts "\n🎉 All format tests completed!"
