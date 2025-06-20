#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/kanban_metrics'

# Test the exact query that's failing
begin
  api_token = ENV.fetch('LINEAR_API_TOKEN', nil)
  if api_token.nil? || api_token.empty?
    puts '❌ LINEAR_API_TOKEN environment variable is required'
    exit 1
  end

  http_client = KanbanMetrics::Linear::HttpClient.new(api_token)

  # Test the failing query with ROI key
  puts '🔍 Testing query with ROI team key...'
  issues_query_with_key = <<~GRAPHQL
    query {
      issues(filter: { team: { id: { eq: "ROI" } } }, first: 5) {
        nodes {
          id
          title
          team { id name key }
        }
      }
    }
  GRAPHQL

  begin
    result = http_client.post(issues_query_with_key)
    puts "✅ Query with team key 'ROI' worked!"
    puts "Found #{result['data']['issues']['nodes'].length} issues"
  rescue KanbanMetrics::ApiError => e
    puts "❌ Query with team key failed: #{e.message}"
  end

  # Test with team UUID
  puts "\n🔍 Testing query with ROI team UUID..."
  issues_query_with_uuid = <<~GRAPHQL
    query {
      issues(filter: { team: { id: { eq: "5cb3ee70-693d-406b-a6a5-23a002ef10d6" } } }, first: 5) {
        nodes {
          id
          title
          team { id name key }
        }
      }
    }
  GRAPHQL

  begin
    result = http_client.post(issues_query_with_uuid)
    puts '✅ Query with team UUID worked!'
    puts "Found #{result['data']['issues']['nodes'].length} issues"
  rescue KanbanMetrics::ApiError => e
    puts "❌ Query with team UUID failed: #{e.message}"
  end

  # Test with team key filter
  puts "\n🔍 Testing query with team key filter..."
  issues_query_with_key_filter = <<~GRAPHQL
    query {
      issues(filter: { team: { key: { eq: "ROI" } } }, first: 5) {
        nodes {
          id
          title
          team { id name key }
        }
      }
    }
  GRAPHQL

  begin
    result = http_client.post(issues_query_with_key_filter)
    puts '✅ Query with team key filter worked!'
    puts "Found #{result['data']['issues']['nodes'].length} issues"
  rescue KanbanMetrics::ApiError => e
    puts "❌ Query with team key filter failed: #{e.message}"
  end
rescue StandardError => e
  puts "❌ Error: #{e.message}"
  puts e.backtrace if ENV['DEBUG']
end
