#!/usr/bin/env ruby
# frozen_string_literal: true

# Simple test script to verify the --ticket-details CLI flag parsing

require_relative '../lib/kanban_metrics'

puts '🧪 Testing --ticket-details CLI flag'
puts '=' * 50

def run_flag_parsing_test
  puts "\n📋 Testing flag parsing"

  # Test with flag
  with_flag = KanbanMetrics::OptionsParser.parse(['--ticket-details', '--format', 'json'])
  puts "✅ With --ticket-details: #{with_flag[:ticket_details]}"

  # Test without flag
  without_flag = KanbanMetrics::OptionsParser.parse(['--format', 'json'])
  puts "✅ Without --ticket-details: #{without_flag[:ticket_details] || 'false'}"

  # Test help includes the flag
  begin
    KanbanMetrics::OptionsParser.parse(['--help'])
  rescue SystemExit
    # Expected when --help is used
  end

  # Return test result
  result = with_flag[:ticket_details] == true && without_flag[:ticket_details] != true
  puts "Test result: #{result ? 'PASSED' : 'FAILED'}"
  result
end

def test_application_runner_options
  puts "\n🚀 Testing ApplicationRunner option handling"

  # Create options with ticket_details
  options_with_details = {
    format: 'json',
    ticket_details: true,
    token: 'fake-token'
  }

  options_without_details = {
    format: 'json',
    ticket_details: false,
    token: 'fake-token'
  }

  begin
    KanbanMetrics::ApplicationRunner.new(options_with_details)
    KanbanMetrics::ApplicationRunner.new(options_without_details)

    puts '✅ ApplicationRunner accepts ticket_details option'
    true
  rescue StandardError => e
    puts "❌ ApplicationRunner failed: #{e.message}"
    false
  end
end

def test_help_documentation
  puts "\n📖 Testing help documentation"

  begin
    # Capture help output
    old_stdout = $stdout
    $stdout = StringIO.new

    begin
      KanbanMetrics::OptionsParser.parse(['--help'])
    rescue SystemExit
      # Expected
    ensure
      help_content = $stdout.string
      $stdout = old_stdout
    end

    has_ticket_details = help_content.include?('--ticket-details')
    puts "✅ Help includes --ticket-details: #{has_ticket_details}"

    has_ticket_details
  rescue StandardError => e
    puts "❌ Help test failed: #{e.message}"
    false
  end
end

# Run tests
parsing_passed = run_flag_parsing_test
runner_passed = test_application_runner_options
help_passed = test_help_documentation

puts "\n#{'=' * 50}"
puts '🎯 Test Results'
puts '=' * 50
puts "Flag Parsing: #{parsing_passed ? '✅ PASSED' : '❌ FAILED'}"
puts "ApplicationRunner: #{runner_passed ? '✅ PASSED' : '❌ FAILED'}"
puts "Help Documentation: #{help_passed ? '✅ PASSED' : '❌ FAILED'}"

if parsing_passed && runner_passed && help_passed
  puts "\n🎉 All CLI tests PASSED!"
  puts "\n💡 Usage examples:"
  puts '   ./bin/kanban_metrics --format csv --ticket-details'
  puts '   ./bin/kanban_metrics --format json --ticket-details'
  puts '   ./bin/kanban_metrics --format table --ticket-details'
else
  puts "\n❌ Some tests FAILED."
  exit 1
end
