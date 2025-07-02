#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to check available Dust agents
require 'bundler/setup'
require 'net/http'
require 'json'

# Load environment variables from config/.env.test
def load_env_file
  env_file = File.join(__dir__, 'config', '.env.test')
  unless File.exist?(env_file)
    puts '❌ config/.env.test file not found!'
    exit 1
  end

  File.readlines(env_file).each do |line|
    line.strip!
    next if line.empty? || line.start_with?('#')

    key, value = line.split('=', 2)
    ENV[key] = value if key && value && !ENV.key?(key)
  end
end

def check_agents
  puts '🔍 Checking available Dust agents...'
  
  api_key = ENV['DUST_API_KEY']
  workspace_id = ENV['DUST_WORKSPACE_ID']
  
  uri = URI("https://dust.tt/api/v1/w/#{workspace_id}/assistant/agent_configurations")
  request = Net::HTTP::Get.new(uri)
  request['Authorization'] = "Bearer #{api_key}"
  
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  
  response = http.request(request)
  
  if response.code == '200'
    data = JSON.parse(response.body)
    puts "✅ Found #{data['agentConfigurations'].length} agents:"
    
    data['agentConfigurations'].each do |agent|
      status = agent['status'] == 'active' ? '✅' : '❌'
      puts "  #{status} #{agent['sId']} - #{agent['name']} (#{agent['status']})"
    end
  else
    puts "❌ Failed to fetch agents: #{response.code} #{response.body}"
  end
rescue StandardError => e
  puts "❌ Error: #{e.message}"
end

# Main execution
load_env_file
check_agents
