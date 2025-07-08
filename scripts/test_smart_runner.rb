#!/usr/bin/env ruby
# frozen_string_literal: true

# Local test script for the AI Test Runner
# This script demonstrates how to use the AI test runner locally

require_relative '../.github/scripts/ai_test_runner'
require_relative '../.github/scripts/shared/ai_services'
require 'logger'

puts '🧪 AI Test Runner - Local Test'
puts '==============================='

# Mock environment for testing
test_env = {
  'GITHUB_REPOSITORY' => 'test/repo',
  'COMMIT_SHA' => `git rev-parse HEAD`.strip,
  'BASE_REF' => 'HEAD~1', # Compare with previous commit
  'GITHUB_TOKEN' => 'mock_token', # Not needed for local git operations
  'API_PROVIDER' => 'anthropic',
  'ANTHROPIC_API_KEY' => ENV['ANTHROPIC_API_KEY'] || 'mock_key'
}

puts 'Configuration:'
test_env.each { |k, v| puts "  #{k}: #{v}" }
puts

# Create a test logger that outputs to console
logger = SharedLoggerFactory.create

# Initialize services
config = AITestConfig.new(test_env)
runner = AITestRunner.new(config, logger)

puts '🔍 Testing individual components...'
puts

# Test 1: Configuration validation
puts '1. Testing configuration...'
if config.valid?
  puts '   ✅ Configuration is valid'
else
  puts '   ❌ Configuration is invalid'
  puts '   💡 Set ANTHROPIC_API_KEY environment variable for full testing'
end
puts

# Test 2: Git change analysis
puts '2. Testing git change analysis...'
begin
  analyzer = GitChangeAnalyzer.new(logger)
  changes = analyzer.analyze_changes(config)

  if changes[:changed_files].any?
    puts "   ✅ Found #{changes[:changed_files].size} changed files:"
    changes[:changed_files].each do |file|
      puts "      - #{file[:path]} (#{file[:type]})"
    end
  else
    puts "   ℹ️  No changes detected (this is normal if you haven't made recent commits)"
  end
rescue StandardError => e
  puts "   ❌ Error: #{e.message}"
end
puts

# Test 3: Test discovery
puts '3. Testing test discovery...'
begin
  discovery = TestDiscoveryService.new(logger).discover_tests
  puts "   ✅ Found #{discovery[:test_files].size} test files"
  puts "   ✅ Built mapping for #{discovery[:test_mapping].size} test-to-source relationships"

  # Show a few examples
  puts '   📝 Example mappings:'
  discovery[:test_mapping].first(3).each do |test_file, source_files|
    puts "      #{test_file} → #{source_files.join(', ')}"
  end
rescue StandardError => e
  puts "   ❌ Error: #{e.message}"
end
puts

# Test 4: AI test selection (only if API key is available)
if ENV['ANTHROPIC_API_KEY'] && config.valid?
  puts '4. Testing AI test selection...'
  begin
    analyzer = GitChangeAnalyzer.new(logger)
    changes = analyzer.analyze_changes(config)

    if changes[:changed_files].any?
      discovery = TestDiscoveryService.new(logger).discover_tests
      selector = AITestSelector.new(config, logger)

      result = selector.select_tests(changes, discovery)

      puts "   ✅ AI selected #{result[:selected_tests].size} tests"
      puts "   📊 Risk level: #{result[:reasoning]['risk_level'] || 'unknown'}"

      if result[:selected_tests].any?
        puts '   📝 Selected tests:'
        result[:selected_tests].first(5).each do |test|
          puts "      - #{test}"
        end
        puts "      ... (and #{result[:selected_tests].size - 5} more)" if result[:selected_tests].size > 5
      end
    else
      puts '   ℹ️  No changes to analyze'
    end
  rescue StandardError => e
    puts "   ❌ Error: #{e.message}"
  end
else
  puts '4. Skipping AI test selection (set ANTHROPIC_API_KEY to test)'
end
puts

# Test 5: Full integration test
puts '5. Testing full integration...'
begin
  if config.valid? && ENV['ANTHROPIC_API_KEY']
    runner.run
    puts '   ✅ Full integration test completed'

    # Show results
    if File.exist?('tmp/selected_tests.txt')
      selected_tests = File.read('tmp/selected_tests.txt').split("\n")
      puts "   📊 Results: #{selected_tests.size} tests selected"
      puts '   📁 Output files created:'
      puts '      - tmp/selected_tests.txt'
      puts '      - tmp/test_analysis.json' if File.exist?('tmp/test_analysis.json')
      puts '      - tmp/ai_analysis.md' if File.exist?('tmp/ai_analysis.md')
    end
  else
    puts '   ⏭️  Skipping integration test (requires valid API key)'
  end
rescue StandardError => e
  puts "   ❌ Error: #{e.message}"
end

puts
puts '🎉 Local testing completed!'
puts
puts 'Next steps:'
puts '- Review output files in tmp/ directory'
puts '- Test with actual code changes'
puts '- Configure GitHub Actions with your API keys'
puts '- Monitor the smart test runner in your CI pipeline'
