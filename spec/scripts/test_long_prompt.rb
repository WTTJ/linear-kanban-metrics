#!/usr/bin/env ruby
# frozen_string_literal: true

# Test script to reproduce the exact GitHub Actions scenario
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

def test_long_prompt
  puts '🧪 Testing Dust API with long PR review prompt (GitHub Actions simulation)...'

  long_prompt = create_test_prompt
  puts "📊 Prompt length: #{long_prompt.length} characters"

  conversation_id = create_conversation(long_prompt)
  return false unless conversation_id

  puts "✅ Conversation created: #{conversation_id}"
  await_agent_response(conversation_id)
rescue StandardError => e
  puts "❌ Error: #{e.message}"
  false
end

def create_test_prompt
  <<~PROMPT
    # PR Review Prompt Template

    You are a senior Ruby developer reviewing a pull request for a kanban metrics analysis tool.

    ## CODING STANDARDS
    # AI Code Review Standards Configuration
    # This file defines the coding standards and design patterns that should be enforced during AI code reviews

    ## Project Architecture Standards

    ### Module Organization
    - All code must be organized under the `KanbanMetrics` namespace
    - Use Zeitwerk autoloading - never use `require_relative`
    - Follow the established module hierarchy:
      - `KanbanMetrics::Linear::*` - API client layer
      - `KanbanMetrics::Calculators::*` - Business logic and metrics
      - `KanbanMetrics::Timeseries::*` - Time series analysis
      - `KanbanMetrics::Formatters::*` - Output formatting strategies
      - `KanbanMetrics::Reports::*` - High-level report generation

    ### Design Patterns (Required)
    1. **Value Objects**: Use for configuration and data transfer
    2. **Strategy Pattern**: Use for formatters and calculators
    3. **Template Method**: Use for base calculator classes
    4. **Builder Pattern**: Use for complex query construction
    5. **Adapter Pattern**: Use for external API integrations

    Please review the following changes and provide a brief summary.

    ## Changes to Review:

    ```diff
    + # This is a sample diff for testing
    + class TestClass
    +   def initialize
    +     @test = 'value'
    +   end
    + end
    ```
    Give references to the coding standards and design patterns above with links to the relevant sections.

    Please provide your review in markdown format.
  PROMPT
end

def create_conversation(prompt)
  uri = URI("https://dust.tt/api/v1/w/#{ENV.fetch('DUST_WORKSPACE_ID', nil)}/assistant/conversations")
  request_data = build_conversation_request(prompt)

  puts '🔄 Creating conversation...'
  response = make_http_request(uri, :post, request_data[:headers], request_data[:body])

  handle_conversation_response(response)
end

def build_conversation_request(prompt)
  headers = {
    'Authorization' => "Bearer #{ENV.fetch('DUST_API_KEY', nil)}",
    'Content-Type' => 'application/json'
  }

  body = {
    message: {
      content: prompt,
      context: {
        timezone: 'UTC',
        username: 'github-pr-reviewer',
        fullName: 'GitHub PR Reviewer'
      },
      mentions: [{ configurationId: ENV.fetch('DUST_AGENT_ID', nil) }]
    },
    blocking: true,
    streamGenerationEvents: false
  }.to_json

  { headers: headers, body: body }
end

def handle_conversation_response(response)
  if response.code == '200'
    data = JSON.parse(response.body)
    data.dig('conversation', 'sId')
  else
    puts "❌ Failed to create conversation: #{response.code} #{response.body[0..200]}"
    nil
  end
end

# rubocop:disable Naming/PredicateMethod
def await_agent_response(conversation_id)
  (1..5).each do |attempt|
    puts "🔍 Checking for response (attempt #{attempt}/5)..."
    sleep(5)

    response = get_conversation(conversation_id)
    return true if process_conversation_response(response)
  end

  puts '❌ Agent did not respond after 5 attempts (25 seconds)'
  false
end

def get_conversation(conversation_id)
  uri = URI("https://dust.tt/api/v1/w/#{ENV.fetch('DUST_WORKSPACE_ID', nil)}/assistant/conversations/#{conversation_id}")
  headers = { 'Authorization' => "Bearer #{ENV.fetch('DUST_API_KEY', nil)}" }

  make_http_request(uri, :get, headers)
end

def process_conversation_response(response)
  return false unless response.code == '200'

  p JSON.pretty_generate(JSON.parse(response.body))
  conv_data = JSON.parse(response.body)
  messages = conv_data.dig('conversation', 'content')

  return false unless messages && messages.length > 1

  handle_agent_messages(messages)
end

def handle_agent_messages(messages)
  # rubocop:enable Naming/PredicateMethod
  agent_messages = messages.flatten.select { |msg| msg&.dig('type') == 'agent_message' }

  if agent_messages.any?
    puts "✅ Agent responded! (#{agent_messages.length} messages)"
    latest_message = agent_messages.last

    content = latest_message&.dig('content')
    citations = latest_message&.dig('citations') || []

    display_agent_response(content, citations)
    true
  else
    display_no_agent_response(messages)
    false
  end
end

def display_agent_response(content, citations)
  display_response_header
  processed_content = process_and_display_content(content, citations)
  display_citations_if_present(citations)
  display_response_summary(content, processed_content, citations)
end

def display_response_header
  puts "\n#{'=' * 60}"
  puts '🤖 DUST AI RESPONSE:'
  puts '=' * 60
  puts
end

def process_and_display_content(content, citations)
  # Process citation markers in content
  processed_content = citations.any? ? process_citation_markers(content, citations) : content
  puts processed_content
  puts
  processed_content
end

def display_citations_if_present(citations)
  return unless citations.any?

  puts '📚 CITATIONS:'
  puts '-' * 30
  citations.each_with_index do |citation, index|
    puts "#{index + 1}. #{format_citation(citation)}"
  end
  puts '-' * 30
  puts
end

def display_response_summary(content, processed_content, citations)
  puts '=' * 60
  puts "📏 Response length: #{content.length} characters"
  puts "📏 Processed length: #{processed_content.length} characters"
  puts "📚 Citations found: #{citations.length}" if citations.any?
end

def process_citation_markers(content, citations)
  # Create a citation map for lookup
  citation_map = {}
  citations.each_with_index do |citation, index|
    # Dust citations usually have an 'id' field
    citation_map[citation['id']] = index + 1 if citation.is_a?(Hash) && citation['id']
  end

  # Replace :cite[id] or :cite[id1,id2,...] markers with numbered references
  content.gsub(/:cite\[([^\]]+)\]/) do |match|
    cite_ids_string = Regexp.last_match(1)
    cite_ids = cite_ids_string.split(',').map(&:strip)

    # Process each citation ID and collect valid references
    references = cite_ids.filter_map do |cite_id|
      citation_map[cite_id] if citation_map[cite_id]
    end

    if references.any?
      # Format as [1], [1,2], or [1,2,3] etc.
      "[#{references.join(',')}]"
    else
      # If no citation IDs found, keep the original marker but make it more visible
      "**#{match}**"
    end
  end
end

def format_citation(citation)
  case citation
  when Hash
    format_hash_citation(citation)
  when String
    citation
  else
    citation.to_s
  end
end

def format_hash_citation(citation)
  # Handle Dust's various citation formats
  if citation['reference']
    format_reference_citation(citation)
  elsif citation['document']
    format_document_citation(citation)
  elsif citation['title'] || citation['url']
    format_basic_citation(citation)
  else
    citation.to_s
  end
end

def format_reference_citation(citation)
  ref = citation['reference']
  title = ref['title'] || 'Untitled'
  url = ref['href']

  if url
    "[#{title}](#{url})"
  else
    title
  end
end

def format_document_citation(citation)
  doc = citation['document']
  title = doc['title'] || doc['name'] || 'Document'
  url = doc['url'] || doc['href']

  if url
    "[#{title}](#{url})"
  else
    title
  end
end

def format_basic_citation(citation)
  title = citation['title'] || citation['name'] || 'Reference'
  url = citation['url'] || citation['href']
  snippet = citation['snippet'] || citation['text']

  parts = []
  parts << if url
             "[#{title}](#{url})"
           else
             title
           end

  if snippet && snippet.length > 10
    # Add a snippet preview if available
    clean_snippet = snippet.strip.gsub(/\s+/, ' ')[0..100]
    parts << "\"#{clean_snippet}#{'...' if snippet.length > 100}\""
  end

  parts.join(' - ')
end

def display_no_agent_response(messages)
  puts "⏳ No agent response yet... (found #{messages.length} messages total)"
  message_types = messages.flatten.filter_map { |m| m&.dig('type') }.uniq
  puts "   Message types: #{message_types.join(', ')}"
end

def make_http_request(uri, method, headers, body = nil)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.open_timeout = 30
  http.read_timeout = 120

  request = case method
            when :post
              Net::HTTP::Post.new(uri)
            when :get
              Net::HTTP::Get.new(uri)
            end

  headers.each { |key, value| request[key] = value }
  request.body = body if body

  http.request(request)
end

# Main execution
load_env_file
success = test_long_prompt

if success
  puts "\n🎉 Long prompt test passed!"
else
  puts "\n💥 Long prompt test failed - this might explain the GitHub Actions issue"
end
