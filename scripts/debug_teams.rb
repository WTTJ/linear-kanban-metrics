#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/kanban_metrics'

# Simple script to test Linear API and get team information
begin
  # Initialize HTTP client
  api_token = ENV.fetch('LINEAR_API_TOKEN', nil)
  if api_token.nil? || api_token.empty?
    puts '❌ LINEAR_API_TOKEN environment variable is required'
    exit 1
  end

  http_client = KanbanMetrics::Linear::HttpClient.new(api_token)

  # Query to get teams
  teams_query = <<~GRAPHQL
    query {
      teams {
        nodes {
          id
          name
          key
        }
      }
    }
  GRAPHQL

  puts '🔍 Fetching available teams...'
  result = http_client.post(teams_query)

  if result['data']['teams']['nodes'].empty?
    puts '❌ No teams found'
  else
    puts '✅ Available teams:'
    result['data']['teams']['nodes'].each do |team|
      puts "  - ID: #{team['id']}, Name: #{team['name']}, Key: #{team['key']}"
    end
  end
rescue KanbanMetrics::ApiError => e
  puts "❌ API Error: #{e.message}"
rescue StandardError => e
  puts "❌ Error: #{e.message}"
  puts e.backtrace if ENV['DEBUG']
end
