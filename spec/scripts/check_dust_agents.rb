#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to check available Dust agents
require 'bundler/setup'
require 'net/http'
require 'json'

# Load environment variables from config/.env.test
def load_env_file
  env_file = File.join(__dir__, '..', '..', 'config', '.env.test')
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

  api_key, workspace_id = fetch_environment_variables
  response = make_api_request(api_key, workspace_id)
  process_response(response)
rescue StandardError => e
  puts "❌ Error: #{e.message}"
end

def fetch_environment_variables
  [ENV.fetch('DUST_API_KEY', nil), ENV.fetch('DUST_WORKSPACE_ID', nil)]
end

def make_api_request(api_key, workspace_id)
  uri = URI("https://dust.tt/api/v1/w/#{workspace_id}/assistant/agent_configurations")
  request = Net::HTTP::Get.new(uri)
  request['Authorization'] = "Bearer #{api_key}"

  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.request(request)
end

def process_response(response)
  if response.code == '200'
    display_agents(JSON.parse(response.body))
  else
    puts "❌ Failed to fetch agents: #{response.code} #{response.body}"
  end
end

def display_agents(data)
  puts "✅ Found #{data['agentConfigurations'].length} agents:"

  data['agentConfigurations'].each do |agent|
    status = agent['status'] == 'active' ? '✅' : '❌'
    puts "  #{status} #{agent['sId']} - #{agent['name']} (#{agent['status']})"
  end
end

# Main execution
load_env_file
check_agents
