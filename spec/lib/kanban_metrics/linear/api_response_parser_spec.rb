# frozen_string_literal: true

require 'spec_helper'

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
        allow(ENV).to receive(:fetch).with('DEBUG', nil).and_return('true')

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
end
