#!/usr/bin/env ruby
# frozen_string_literal: true

# Demo script to show CSV export with individual tickets
# Note: In the actual application, use --ticket-details flag to include individual tickets:
# ./bin/kanban_metrics --format csv --ticket-details
require_relative '../lib/kanban_metrics'

# Sample metrics data
metrics = {
  total_issues: 15,
  completed_issues: 10,
  in_progress_issues: 3,
  backlog_issues: 2,
  cycle_time: {
    average: 8.5,
    median: 6.0,
    p95: 18.2
  },
  lead_time: {
    average: 12.3,
    median: 9.1,
    p95: 25.7
  },
  throughput: {
    weekly_avg: 3.2,
    total_completed: 10
  },
  flow_efficiency: 65.5
}

# Sample team metrics
team_metrics = {
  'Backend Team' => {
    total_issues: 8,
    completed_issues: 6,
    in_progress_issues: 2,
    backlog_issues: 0,
    cycle_time: { average: 7.2, median: 5.5 },
    lead_time: { average: 10.8, median: 8.2 },
    throughput: 6
  },
  'Frontend Team' => {
    total_issues: 7,
    completed_issues: 4,
    in_progress_issues: 1,
    backlog_issues: 2,
    cycle_time: { average: 10.1, median: 7.8 },
    lead_time: { average: 14.5, median: 11.2 },
    throughput: 4
  }
}

# Sample individual issues (as they would come from Linear API)
issues = [
  {
    'id' => 'abc123-def456-789',
    'identifier' => 'PROJ-123',
    'title' => 'Implement user authentication system',
    'state' => { 'name' => 'Done', 'type' => 'completed' },
    'team' => { 'name' => 'Backend Team' },
    'assignee' => { 'name' => 'John Doe' },
    'priority' => 1,
    'estimate' => 5,
    'createdAt' => '2024-01-01T09:00:00Z',
    'updatedAt' => '2024-01-08T17:00:00Z',
    'startedAt' => '2024-01-02T10:00:00Z',
    'completedAt' => '2024-01-08T16:00:00Z',
    'archivedAt' => nil
  },
  {
    'id' => 'def456-ghi789-012',
    'identifier' => 'PROJ-124',
    'title' => 'Fix login redirect bug',
    'state' => { 'name' => 'Done', 'type' => 'completed' },
    'team' => { 'name' => 'Frontend Team' },
    'assignee' => { 'name' => 'Jane Smith' },
    'priority' => 0,
    'estimate' => 2,
    'createdAt' => '2024-01-03T14:00:00Z',
    'updatedAt' => '2024-01-05T11:30:00Z',
    'startedAt' => '2024-01-04T09:00:00Z',
    'completedAt' => '2024-01-05T11:30:00Z',
    'archivedAt' => nil
  },
  {
    'id' => 'ghi789-jkl012-345',
    'identifier' => 'PROJ-125',
    'title' => 'Add password strength indicator',
    'state' => { 'name' => 'In Progress', 'type' => 'started' },
    'team' => { 'name' => 'Frontend Team' },
    'assignee' => { 'name' => 'Bob Wilson' },
    'priority' => 2,
    'estimate' => 3,
    'createdAt' => '2024-01-05T10:00:00Z',
    'updatedAt' => '2024-01-08T14:20:00Z',
    'startedAt' => '2024-01-07T11:00:00Z',
    'completedAt' => nil,
    'archivedAt' => nil
  },
  {
    'id' => 'jkl012-mno345-678',
    'identifier' => 'PROJ-126',
    'title' => 'Database optimization for user queries',
    'state' => { 'name' => 'Backlog', 'type' => 'unstarted' },
    'team' => { 'name' => 'Backend Team' },
    'assignee' => nil,
    'priority' => 1,
    'estimate' => 8,
    'createdAt' => '2024-01-08T16:00:00Z',
    'updatedAt' => '2024-01-08T16:00:00Z',
    'startedAt' => nil,
    'completedAt' => nil,
    'archivedAt' => nil
  },
  {
    'id' => 'mno345-pqr678-901',
    'identifier' => 'PROJ-127',
    'title' => 'Update API documentation',
    'state' => { 'name' => 'Done', 'type' => 'completed' },
    'team' => { 'name' => 'Backend Team' },
    'assignee' => { 'name' => 'Alice Johnson' },
    'priority' => 2,
    'estimate' => 1,
    'createdAt' => '2024-01-06T08:00:00Z',
    'updatedAt' => '2024-01-07T15:45:00Z',
    'startedAt' => '2024-01-06T14:00:00Z',
    'completedAt' => '2024-01-07T15:45:00Z',
    'archivedAt' => nil
  }
]

puts '=== Kanban Metrics CSV Export Demo ==='
puts "Generating CSV report with #{issues.length} individual tickets...\n\n"

# Create CSV formatter with all data including individual issues
formatter = KanbanMetrics::Formatters::CsvFormatter.new(metrics, team_metrics, nil, issues)
csv_output = formatter.generate

puts csv_output

puts "\n=== Demo Complete ==="
puts 'CSV output includes:'
puts '• Overall project metrics'
puts '• Team-based metrics breakdown'
puts '• Individual ticket details with calculated cycle/lead times'
puts "• #{issues.count { |i| i['state']['type'] == 'completed' }} completed tickets with timing data"
puts "• #{issues.count { |i| i['state']['type'] == 'started' }} in-progress tickets"
puts "• #{issues.count { |i| i['state']['type'] == 'unstarted' }} backlog tickets"
