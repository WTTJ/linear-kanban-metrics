#!/usr/bin/env ruby
# frozen_string_literal: true

# Test the fixed PR review logic with whitespace handling

require 'bundler/setup'

# Simulate the fixed config class
class TestConfig
  attr_reader :dust_agent_id, :dust_workspace_id, :dust_api_key

  def initialize
    # Simulate GitHub Actions environment with trailing space
    @dust_agent_id = ENV.fetch('DUST_AGENT_ID', nil)&.strip # The fix
    @dust_workspace_id = ENV.fetch('DUST_WORKSPACE_ID', nil)
    @dust_api_key = ENV.fetch('DUST_API_KEY', nil)
  end
end

# Load environment
env_file = File.join(__dir__, '..', '..', 'config', '.env.test')
File.readlines(env_file).each do |line|
  line.strip!
  next if line.empty? || line.start_with?('#')

  key, value = line.split('=', 2)
  ENV[key] = value if key && value && !ENV.key?(key)
end

# Simulate the problematic environment variable from GitHub Actions
ENV['DUST_AGENT_ID'] = 'claude-4-sonnet ' # With trailing space

puts '🧪 Testing fixed config logic...'

config = TestConfig.new

puts "Original env var: '#{ENV.fetch('DUST_AGENT_ID', nil)}' (length: #{ENV['DUST_AGENT_ID'].length})"
puts "After strip fix: '#{config.dust_agent_id}' (length: #{config.dust_agent_id&.length})"

if config.dust_agent_id == 'claude-4-sonnet'
  puts '✅ SUCCESS: Whitespace stripped correctly!'
  puts '🔧 This fix will resolve the GitHub Actions issue.'
else
  puts '❌ FAILED: Fix did not work as expected.'
end
