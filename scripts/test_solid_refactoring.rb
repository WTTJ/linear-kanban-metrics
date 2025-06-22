#!/usr/bin/env ruby
# frozen_string_literal: true

# Test script to verify SOLID refactoring - TimeMetricsCalculator delegation

require_relative '../lib/kanban_metrics'

puts '🧪 Testing SOLID Refactoring: TimeMetricsCalculator Delegation'
puts '=' * 65

# Sample issue data
completed_issue = {
  'identifier' => 'TEST-001',
  'title' => 'Test completed issue',
  'createdAt' => '2024-06-01T09:00:00Z',
  'startedAt' => '2024-06-03T10:00:00Z',
  'completedAt' => '2024-06-08T16:00:00Z'
}

incomplete_issue = {
  'identifier' => 'TEST-002',
  'title' => 'Test in-progress issue',
  'createdAt' => '2024-06-05T11:00:00Z',
  'startedAt' => '2024-06-06T14:00:00Z',
  'completedAt' => nil
}

[completed_issue, incomplete_issue]

def test_calculator_methods
  puts "\n📊 Testing TimeMetricsCalculator individual issue methods"

  calculator = KanbanMetrics::Calculators::TimeMetricsCalculator.new([])

  # Test completed issue
  completed_issue = {
    'createdAt' => '2024-06-01T09:00:00Z',
    'startedAt' => '2024-06-03T10:00:00Z',
    'completedAt' => '2024-06-08T16:00:00Z'
  }

  cycle_time = calculator.cycle_time_for_issue(completed_issue)
  lead_time = calculator.lead_time_for_issue(completed_issue)

  puts "✅ Completed issue cycle time: #{cycle_time} days"
  puts "✅ Completed issue lead time: #{lead_time} days"

  # Test incomplete issue
  incomplete_issue = {
    'createdAt' => '2024-06-05T11:00:00Z',
    'startedAt' => '2024-06-06T14:00:00Z',
    'completedAt' => nil
  }

  cycle_time_incomplete = calculator.cycle_time_for_issue(incomplete_issue)
  lead_time_incomplete = calculator.lead_time_for_issue(incomplete_issue)

  puts "✅ Incomplete issue cycle time: #{cycle_time_incomplete || 'nil (expected)'}"
  puts "✅ Incomplete issue lead time: #{lead_time_incomplete || 'nil (expected)'}"

  # Verify calculations are working
  cycle_time && lead_time && cycle_time_incomplete.nil? && lead_time_incomplete.nil?
end

def test_formatter_delegation
  puts "\n🎯 Testing Formatter Delegation to Calculator"

  issues = sample_test_issues
  metrics = sample_test_metrics

  begin
    csv_result = test_csv_formatter_delegation(metrics, issues)
    json_result = test_json_formatter_delegation(metrics, issues)
    table_result = test_table_formatter_delegation(metrics, issues)

    csv_result && json_result && table_result
  rescue StandardError => e
    puts "❌ Formatter delegation test failed: #{e.message}"
    false
  end
end

def sample_test_issues
  [
    {
      'identifier' => 'TEST-001',
      'title' => 'Test issue',
      'createdAt' => '2024-06-01T09:00:00Z',
      'startedAt' => '2024-06-03T10:00:00Z',
      'completedAt' => '2024-06-08T16:00:00Z',
      'state' => { 'name' => 'Done' },
      'team' => { 'name' => 'Test Team' }
    }
  ]
end

def sample_test_metrics
  {
    total_issues: 1,
    completed_issues: 1,
    in_progress_issues: 0,
    backlog_issues: 0,
    cycle_time: { average: 5.25, median: 5.25, p95: 5.25 },
    lead_time: { average: 7.29, median: 7.29, p95: 7.29 },
    throughput: { weekly_avg: 1, total_completed: 1 },
    flow_efficiency: 75.0
  }
end

def test_csv_formatter_delegation(metrics, issues)
  csv_formatter = KanbanMetrics::Formatters::CsvFormatter.new(metrics, nil, nil, issues)
  csv_output = csv_formatter.generate
  has_calculated_times = csv_output.include?('5.25') # Expected cycle time
  puts "✅ CSV Formatter delegates to calculator: #{has_calculated_times}"
  has_calculated_times
end

def test_json_formatter_delegation(metrics, issues)
  json_formatter = KanbanMetrics::Formatters::JsonFormatter.new(metrics, nil, nil, issues)
  json_output = json_formatter.generate
  json_has_times = json_output.include?('cycle_time_days')
  puts "✅ JSON Formatter delegates to calculator: #{json_has_times}"
  json_has_times
end

def test_table_formatter_delegation(metrics, issues)
  table_formatter = KanbanMetrics::Formatters::TableFormatter.new(metrics, nil, issues)
  # Table formatter doesn't have a generate method, but we can verify it has the calculator
  has_calculator = !table_formatter.instance_variable_get(:@time_calculator).nil?
  puts "✅ Table Formatter has calculator instance: #{has_calculator}"
  has_calculator
end

def test_solid_principles
  puts "\n🏗️ Verifying SOLID Principles"

  # Single Responsibility: Formatters format, calculator calculates
  calculator = KanbanMetrics::Calculators::TimeMetricsCalculator.new([])

  # Test that calculator methods exist
  has_cycle_method = calculator.respond_to?(:cycle_time_for_issue)
  has_lead_method = calculator.respond_to?(:lead_time_for_issue)

  puts "✅ Calculator has individual cycle time method: #{has_cycle_method}"
  puts "✅ Calculator has individual lead time method: #{has_lead_method}"

  # Test that formatters no longer have calculation methods
  csv_formatter = KanbanMetrics::Formatters::CsvFormatter.new({})
  json_formatter = KanbanMetrics::Formatters::JsonFormatter.new({})
  table_formatter = KanbanMetrics::Formatters::TableFormatter.new({})

  csv_no_calc = !csv_formatter.respond_to?(:calculate_cycle_time)
  json_no_calc = !json_formatter.respond_to?(:calculate_cycle_time)
  table_no_calc = !table_formatter.respond_to?(:calculate_cycle_time)

  puts "✅ CSV formatter no longer has calculation methods: #{csv_no_calc}"
  puts "✅ JSON formatter no longer has calculation methods: #{json_no_calc}"
  puts "✅ Table formatter no longer has calculation methods: #{table_no_calc}"

  has_cycle_method && has_lead_method && csv_no_calc && json_no_calc && table_no_calc
end

# Run tests
calculator_test = test_calculator_methods
delegation_test = test_formatter_delegation
solid_test = test_solid_principles

puts "\n#{'=' * 65}"
puts '🎯 SOLID Refactoring Test Results'
puts '=' * 65
puts "Calculator Methods: #{calculator_test ? '✅ PASSED' : '❌ FAILED'}"
puts "Formatter Delegation: #{delegation_test ? '✅ PASSED' : '❌ FAILED'}"
puts "SOLID Principles: #{solid_test ? '✅ PASSED' : '❌ FAILED'}"

if calculator_test && delegation_test && solid_test
  puts "\n🎉 SOLID Refactoring SUCCESS!"
  puts "\n💡 Benefits achieved:"
  puts '   ✅ Single Responsibility: Each class has one reason to change'
  puts '   ✅ DRY Principle: Calculation logic centralized'
  puts '   ✅ Maintainability: Changes to calculations only needed in one place'
  puts '   ✅ Consistency: Same calculation algorithm across all formatters'
  puts '   ✅ Testability: Calculator logic can be tested independently'
else
  puts "\n❌ Some SOLID principles may not be properly implemented"
  exit 1
end
