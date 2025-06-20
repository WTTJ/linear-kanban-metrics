# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../../lib/kanban_metrics/linear/api_response_parser'

RSpec.describe KanbanMetrics::Linear::ApiResponseParser do
  subject(:parser) { described_class.new(response) }

  # Shared test data
  let(:sample_issues) do
    [
      { 'id' => 'issue-1', 'title' => 'Test Issue 1' },
      { 'id' => 'issue-2', 'title' => 'Test Issue 2' }
    ]
  end

  let(:sample_page_info) do
    {
      'hasNextPage' => true,
      'endCursor' => 'cursor-123'
    }
  end

  let(:successful_response_body) do
    {
      'data' => {
        'issues' => {
          'nodes' => sample_issues,
          'pageInfo' => sample_page_info
        }
      }
    }.to_json
  end

  # Response fixtures
  let(:successful_response) do
    double('response', code: '200', body: successful_response_body)
  end

  let(:http_error_response) do
    double('response', code: '400', message: 'Bad Request', body: 'Invalid request')
  end

  let(:json_error_response) do
    double('response', code: '200', body: 'invalid json {')
  end

  let(:graphql_error_response) do
    double('response',
           code: '200',
           body: {
             'errors' => [
               { 'message' => 'Invalid query' },
               { 'message' => 'Permission denied' }
             ]
           }.to_json)
  end

  let(:empty_data_response) do
    double('response', code: '200', body: { 'data' => {} }.to_json)
  end

  let(:minimal_response) do
    double('response',
           code: '200',
           body: {
             'data' => {
               'issues' => {
                 'nodes' => [],
                 'pageInfo' => {}
               }
             }
           }.to_json)
  end

  describe '#initialize' do
    subject(:new_parser) { described_class.new(successful_response) }

    it 'creates a parser instance with the provided response' do
      # Given: A successful response
      # When: Creating a new parser
      # Then: It should be an instance of the parser class
      expect(new_parser).to be_a(described_class)
    end
  end

  describe '#parse' do
    context 'when response is successful with complete data' do
      let(:response) { successful_response }

      it 'returns parsed data with correct structure and content' do
        # Given: A successful response with issues and page info
        # When: Parsing the response
        result = parser.parse

        # Then: Returns structured data with correct content
        aggregate_failures do
          expect(result).to be_a(Hash)
          expect(result).to have_key(:issues)
          expect(result).to have_key(:page_info)

          # And: Issues are correctly extracted
          expect(result[:issues]).to eq(sample_issues)
          expect(result[:issues].length).to eq(2)

          # And: Page info is correctly normalized
          expect(result[:page_info]).to include(
            has_next_page: true,
            end_cursor: 'cursor-123'
          )
        end
      end
    end

    context 'when response has HTTP error' do
      let(:response) { http_error_response }

      it 'returns nil and logs the HTTP error', :aggregate_failures do
        # Given: An HTTP error response
        # When: Parsing the response
        result = nil
        output = capture_stdout { result = parser.parse }

        # Then: Returns nil
        expect(result).to be_nil

        # And: Logs the HTTP error
        expect(output).to include('❌ HTTP Error: 400 - Bad Request')
      end
    end

    context 'when response has JSON parse error' do
      let(:response) { json_error_response }

      it 'returns nil for malformed JSON' do
        # Given: A response with invalid JSON
        # When: Parsing the response
        result = parser.parse

        # Then: Returns nil
        expect(result).to be_nil
      end

      it 'logs JSON error when DEBUG is enabled' do
        # Given: A response with invalid JSON and DEBUG enabled
        allow(ENV).to receive(:[]).with('DEBUG').and_return('true')

        # When: Parsing the response
        output = capture_stdout { parser.parse }

        # Then: Logs the JSON parse error
        expect(output).to include('❌ JSON Parse Error')
      end
    end

    context 'when response has GraphQL errors' do
      let(:response) { graphql_error_response }

      it 'returns nil and logs all GraphQL errors', :aggregate_failures do
        # Given: A response with GraphQL errors
        # When: Parsing the response
        result = nil
        output = capture_stdout { result = parser.parse }

        # Then: Returns nil
        expect(result).to be_nil

        # And: Logs all GraphQL errors
        expect(output).to include('❌ GraphQL errors:')
        expect(output).to include('Invalid query')
        expect(output).to include('Permission denied')
      end
    end

    context 'when response has empty issues data' do
      let(:response) { empty_data_response }

      it 'returns nil for missing issues data' do
        # Given: A response with empty data
        # When: Parsing the response
        result = parser.parse

        # Then: Returns nil
        expect(result).to be_nil
      end
    end

    context 'when response has minimal valid data' do
      let(:response) { minimal_response }

      it 'handles minimal response with default values', :aggregate_failures do
        # Given: A minimal valid response
        # When: Parsing the response
        result = parser.parse

        # Then: Returns structured data with defaults
        expect(result[:issues]).to eq([])
        expect(result[:page_info]).to include(
          has_next_page: false,
          end_cursor: nil
        )
      end
    end
  end

  describe 'private methods' do
    let(:response) { successful_response }

    describe '#response_successful?' do
      context 'when response code is 200' do
        it 'returns true' do
          # Given: A successful response
          # When: Checking if response is successful
          result = parser.send(:response_successful?)

          # Then: Returns true
          expect(result).to be true
        end
      end

      context 'when response code is not 200' do
        let(:response) { http_error_response }

        it 'returns false and logs error', :aggregate_failures do
          # Given: An HTTP error response
          # When: Checking if response is successful
          result = nil
          output = capture_stdout { result = parser.send(:response_successful?) }

          # Then: Returns false
          expect(result).to be false

          # And: Logs the HTTP error
          expect(output).to include('❌ HTTP Error: 400 - Bad Request')
        end
      end
    end

    describe '#parse_json_response' do
      context 'when JSON is valid' do
        it 'returns parsed hash' do
          # Given: A response with valid JSON
          # When: Parsing the JSON response
          result = parser.send(:parse_json_response)

          # Then: Returns parsed data
          expect(result).to be_a(Hash)
          expect(result).to have_key('data')
        end
      end

      context 'when JSON is invalid' do
        let(:response) { json_error_response }

        it 'returns nil for malformed JSON' do
          # Given: A response with invalid JSON
          # When: Parsing the JSON response
          result = parser.send(:parse_json_response)

          # Then: Returns nil
          expect(result).to be_nil
        end
      end
    end

    describe '#graphql_errors_present?' do
      context 'when data has no errors' do
        it 'returns false' do
          # Given: Data without errors
          data = { 'data' => {} }

          # When: Checking for GraphQL errors
          result = parser.send(:graphql_errors_present?, data)

          # Then: Returns false
          expect(result).to be false
        end
      end

      context 'when data has errors' do
        it 'returns true and logs errors', :aggregate_failures do
          # Given: Data with GraphQL errors
          data = { 'errors' => [{ 'message' => 'Test error' }] }

          # When: Checking for GraphQL errors
          result = nil
          output = capture_stdout { result = parser.send(:graphql_errors_present?, data) }

          # Then: Returns true
          expect(result).to be true

          # And: Logs the errors
          expect(output).to include('❌ GraphQL errors:')
          expect(output).to include('Test error')
        end
      end
    end

    describe '#extract_issues_data' do
      context 'when data contains complete issues information' do
        it 'extracts and structures issues data correctly', :aggregate_failures do
          # Given: Complete data with issues and page info
          data = {
            'data' => {
              'issues' => {
                'nodes' => [{ 'id' => 'test-issue' }],
                'pageInfo' => { 'hasNextPage' => true, 'endCursor' => 'test-cursor' }
              }
            }
          }

          # When: Extracting issues data
          result = parser.send(:extract_issues_data, data)

          # Then: Returns structured data
          expect(result).to include(
            issues: [{ 'id' => 'test-issue' }],
            page_info: include(
              has_next_page: true,
              end_cursor: 'test-cursor'
            )
          )
        end
      end

      context 'when issues data is missing' do
        it 'returns nil' do
          # Given: Data without issues
          data = { 'data' => {} }

          # When: Extracting issues data
          result = parser.send(:extract_issues_data, data)

          # Then: Returns nil
          expect(result).to be_nil
        end
      end

      context 'when nodes are missing' do
        it 'defaults to empty array for nodes' do
          # Given: Data with missing nodes
          data = {
            'data' => {
              'issues' => {
                'pageInfo' => { 'hasNextPage' => false }
              }
            }
          }

          # When: Extracting issues data
          result = parser.send(:extract_issues_data, data)

          # Then: Uses empty array for issues
          expect(result[:issues]).to eq([])
        end
      end

      context 'when pageInfo is missing' do
        it 'defaults page info values', :aggregate_failures do
          # Given: Data with missing pageInfo
          data = {
            'data' => {
              'issues' => {
                'nodes' => [{ 'id' => 'test' }]
              }
            }
          }

          # When: Extracting issues data
          result = parser.send(:extract_issues_data, data)

          # Then: Uses defaults for page info
          expect(result[:page_info]).to include(
            has_next_page: false,
            end_cursor: nil
          )
        end
      end
    end

    describe '#normalize_page_info' do
      context 'when page info is complete' do
        it 'normalizes field names correctly' do
          # Given: Complete page info with camelCase keys
          page_info = { 'hasNextPage' => true, 'endCursor' => 'cursor-123' }

          # When: Normalizing page info
          result = parser.send(:normalize_page_info, page_info)

          # Then: Returns snake_case keys
          expect(result).to eq({
                                 has_next_page: true,
                                 end_cursor: 'cursor-123'
                               })
        end
      end

      context 'when page info has missing fields' do
        it 'provides default values', :aggregate_failures do
          # Given: Empty page info
          page_info = {}

          # When: Normalizing page info
          result = parser.send(:normalize_page_info, page_info)

          # Then: Returns defaults
          expect(result).to eq({
                                 has_next_page: false,
                                 end_cursor: nil
                               })
        end
      end
    end
  end

  describe 'logging methods' do
    let(:response) { http_error_response }

    describe '#log_http_error' do
      it 'logs HTTP error message' do
        # Given: An HTTP error response
        # When: Logging the HTTP error
        output = capture_stdout { parser.send(:log_http_error) }

        # Then: Logs the error message
        expect(output).to include('❌ HTTP Error: 400 - Bad Request')
      end

      context 'when DEBUG is enabled' do
        it 'includes response body in the log' do
          # Given: DEBUG mode enabled
          allow(ENV).to receive(:[]).with('DEBUG').and_return('true')

          # When: Logging the HTTP error
          output = capture_stdout { parser.send(:log_http_error) }

          # Then: Includes response body
          expect(output).to include('Response body: Invalid request')
        end
      end
    end

    describe '#log_json_error' do
      let(:json_error) { JSON::ParserError.new('Invalid JSON syntax') }

      context 'when DEBUG is enabled' do
        it 'logs JSON parse error' do
          # Given: DEBUG mode enabled
          allow(ENV).to receive(:[]).with('DEBUG').and_return('true')

          # When: Logging the JSON error
          output = capture_stdout { parser.send(:log_json_error, json_error) }

          # Then: Logs the JSON parse error
          expect(output).to include('❌ JSON Parse Error: Invalid JSON syntax')
        end
      end

      context 'when DEBUG is disabled' do
        it 'does not log JSON error' do
          # Given: DEBUG mode disabled
          allow(ENV).to receive(:[]).with('DEBUG').and_return(nil)

          # When: Logging the JSON error
          output = capture_stdout { parser.send(:log_json_error, json_error) }

          # Then: Does not produce output
          expect(output).to be_empty
        end
      end
    end

    describe '#log_graphql_errors' do
      it 'logs all GraphQL errors with proper formatting', :aggregate_failures do
        # Given: Multiple GraphQL errors
        errors = [
          { 'message' => 'Authentication failed' },
          { 'message' => 'Rate limit exceeded' }
        ]

        # When: Logging the GraphQL errors
        output = capture_stdout { parser.send(:log_graphql_errors, errors) }

        # Then: Logs header and all error messages
        expect(output).to include('❌ GraphQL errors:')
        expect(output).to include('- Authentication failed')
        expect(output).to include('- Rate limit exceeded')
      end
    end
  end
end
