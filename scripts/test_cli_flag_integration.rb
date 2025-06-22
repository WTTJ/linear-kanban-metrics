#!/usr/bin/env ruby
# frozen_string_literal: true

# Test script to verify the --ticket-details CLI flag works end-to-end

require_relative '../lib/kanban_metrics'

puts '🧪 Testing --ticket-details CLI flag functionality'
puts '=' * 60

# Create sample issue data for testing
def sample_issue_data
  [
    {
      'id' => 'issue-1', 'identifier' => 'TEST-001', 'title' => 'Implement user authentication',
      'description' => 'Add login/logout functionality', 'priority' => 1, 'estimate' => 5,
      'createdAt' => '2024-06-01T09:00:00Z', 'updatedAt' => '2024-06-02T10:00:00Z',
      'startedAt' => '2024-06-03T10:00:00Z', 'completedAt' => '2024-06-08T16:00:00Z',
      'archivedAt' => nil,
      'state' => { 'id' => 'state-1', 'name' => 'Done', 'type' => 'completed' },
      'team' => { 'id' => 'team-1', 'name' => 'Backend Team' },
      'assignee' => { 'id' => 'user-1', 'name' => 'John Doe' }
    },
    {
      'id' => 'issue-2', 'identifier' => 'TEST-002', 'title' => 'Fix responsive design issues',
      'description' => 'Make the app work on mobile', 'priority' => 2, 'estimate' => 3,
      'createdAt' => '2024-06-02T11:00:00Z', 'updatedAt' => '2024-06-03T09:00:00Z',
      'startedAt' => '2024-06-04T14:00:00Z', 'completedAt' => '2024-06-07T12:00:00Z',
      'archivedAt' => nil,
      'state' => { 'id' => 'state-1', 'name' => 'Done', 'type' => 'completed' },
      'team' => { 'id' => 'team-2', 'name' => 'Frontend Team' },
      'assignee' => { 'id' => 'user-2', 'name' => 'Jane Smith' }
    }
  ]
end

# Create a mock Linear API response for testing
def create_mock_api_response
  { 'data' => { 'issues' => { 'nodes' => sample_issue_data } } }
end

# Mock the Linear API client to return our test data
class MockLinearClient
  def initialize
    @api_response = create_mock_api_response
  end

  def fetch_issues(_query_options)
    @api_response
  end
end

# Test the OptionsParser with --ticket-details flag
def test_options_parser
  puts "\n📋 Testing OptionsParser with --ticket-details flag"

  # Test with flag
  options_with_flag = KanbanMetrics::OptionsParser.parse(['--ticket-details', '--format', 'json'])
  puts "✅ With --ticket-details: ticket_details = #{options_with_flag[:ticket_details]}"

  # Test without flag
  options_without_flag = KanbanMetrics::OptionsParser.parse(['--format', 'json'])
  puts "✅ Without --ticket-details: ticket_details = #{options_without_flag[:ticket_details]}"

  options_with_flag[:ticket_details] && !options_without_flag[:ticket_details]
end

# Test application runner integration
def test_application_runner_integration
  puts "\n🚀 Testing ApplicationRunner integration"

  # Mock the Linear client
  allow(KanbanMetrics::Linear::Client).to receive(:new).and_return(MockLinearClient.new)

  begin
    # Test with --ticket-details flag
    puts "\n--- Testing with --ticket-details flag ---"
    options_with_flag = KanbanMetrics::OptionsParser.parse(['--ticket-details', '--format', 'json', '--token', 'fake-token'])
    runner_with_flag = KanbanMetrics::ApplicationRunner.new(options_with_flag)

    # Capture output
    output_with_flag = capture_stdout { runner_with_flag.show_metrics }
    json_with_flag = JSON.parse(output_with_flag)
    has_individual_tickets = json_with_flag.key?('individual_tickets')
    puts "✅ With flag - individual_tickets present: #{has_individual_tickets}"

    # Test without --ticket-details flag
    puts "\n--- Testing without --ticket-details flag ---"
    options_without_flag = KanbanMetrics::OptionsParser.parse(['--format', 'json', '--token', 'fake-token'])
    runner_without_flag = KanbanMetrics::ApplicationRunner.new(options_without_flag)

    # Capture output
    output_without_flag = capture_stdout { runner_without_flag.show_metrics }
    json_without_flag = JSON.parse(output_without_flag)
    no_individual_tickets = !json_without_flag.key?('individual_tickets')
    puts "✅ Without flag - individual_tickets absent: #{no_individual_tickets}"

    has_individual_tickets && no_individual_tickets
  rescue StandardError => e
    puts "❌ Integration test failed: #{e.message}"
    false
  end
end

def capture_stdout
  original_stdout = $stdout
  $stdout = fake = StringIO.new
  begin
    yield
  ensure
    $stdout = original_stdout
  end
  fake.string
end

# Add RSpec mocking capability
require 'rspec/mocks'
RSpec::Mocks.setup

# Run tests
options_test_passed = test_options_parser
integration_test_passed = test_application_runner_integration

puts "\n#{'=' * 60}"
puts '🎯 Test Results Summary'
puts '=' * 60
puts "Options Parser: #{options_test_passed ? '✅ PASSED' : '❌ FAILED'}"
puts "Integration: #{integration_test_passed ? '✅ PASSED' : '❌ FAILED'}"

if options_test_passed && integration_test_passed
  puts "\n🎉 All CLI flag tests PASSED! --ticket-details is working correctly."
else
  puts "\n❌ Some tests FAILED. Please check the implementation."
  exit 1
end
