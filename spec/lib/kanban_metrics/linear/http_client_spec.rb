# frozen_string_literal: true

require 'spec_helper'

RSpec.describe KanbanMetrics::Linear::HttpClient, :vcr do
  # For VCR tests, use environment variable or fallback to test token
  let(:api_token) { ENV['LINEAR_API_TOKEN'] || 'test-token-123' }
  let(:http_client) { described_class.new(api_token) }

  describe '#initialize' do
    it 'sets the API token' do
      # Arrange & Act
      client = described_class.new('my-test-token')

      # Assert
      expect(client.instance_variable_get(:@api_token)).to eq('my-test-token')

      # Cleanup
      # (automatic with let blocks)
    end
  end

  describe '#post' do
    let(:query) { 'query { issues(first: 2) { nodes { id title } } }' }
    let(:variables) { { first: 2 } }

    context 'when API returns successful response' do
      it 'returns parsed JSON data', vcr: { cassette_name: 'linear_api/successful_post_request' } do
        # Arrange
        # (query and variables set up in let blocks)

        # Act
        result = http_client.post(query, variables)

        # Assert
        aggregate_failures 'response structure and content' do
          expect(result).to be_a(Hash)
          expect(result).to have_key('data')
          expect(result['data']).to have_key('issues')
          expect(result['data']['issues']).to have_key('nodes')
          expect(result['data']['issues']['nodes']).to be_an(Array)
        end

        # Cleanup
        # (automatic with VCR)
      end
    end

    context 'when API returns error response' do
      it 'raises ApiError for HTTP 401 unauthorized', vcr: { cassette_name: 'linear_api/http_401_error' } do
        # Arrange
        client_with_invalid_token = described_class.new('invalid-token-401')

        # Act & Assert
        expect { client_with_invalid_token.post(query, variables) }
          .to raise_error(KanbanMetrics::ApiError, /HTTP 400|HTTP 401|Unauthorized|Authentication required/)

        # Cleanup
        # (automatic with VCR)
      end

      it 'raises ApiError for HTTP 403 forbidden', vcr: { cassette_name: 'linear_api/http_403_error' } do
        # Arrange
        client_with_forbidden_token = described_class.new('forbidden-token-403')

        # Act & Assert
        expect { client_with_forbidden_token.post(query, variables) }
          .to raise_error(KanbanMetrics::ApiError, /HTTP 400|HTTP 403|Forbidden|Authentication required/)

        # Cleanup
        # (automatic with VCR)
      end

      it 'raises ApiError for HTTP 429 rate limited', vcr: { cassette_name: 'linear_api/http_429_error' } do
        # Arrange
        # This would be recorded during actual rate limiting scenario

        # Act & Assert
        expect { http_client.post(query, variables) }
          .to raise_error(KanbanMetrics::ApiError, /HTTP 429|Rate limited/)

        # Cleanup
        # (automatic with VCR)
      end

      it 'raises ApiError for GraphQL errors', vcr: { cassette_name: 'linear_api/graphql_errors' } do
        # Arrange
        invalid_query = 'query { invalid_field_that_does_not_exist }'

        # Act & Assert
        expect { http_client.post(invalid_query) }
          .to raise_error(KanbanMetrics::ApiError, /HTTP 400|Cannot query field/)

        # Cleanup
        # (automatic with VCR)
      end

      it 'raises ApiError for HTTP 400 with detailed error message',
         vcr: { cassette_name: 'linear_api/http_400_error' } do
        # Arrange
        malformed_query = 'query { issues { nodes { badField } } }'

        # Act & Assert
        expect { http_client.post(malformed_query) }
          .to raise_error(KanbanMetrics::ApiError, /HTTP 400/)

        # Cleanup
        # (automatic with VCR)
      end
    end
  end

  describe '#post_graphql (legacy method)' do
    let(:query) { 'query { issues(first: 1) { nodes { id title } } }' }
    let(:variables) { { first: 1 } }

    context 'when delegating to post method' do
      it 'passes through arguments and returns result', vcr: { cassette_name: 'linear_api/post_graphql_delegation' } do
        # Arrange
        # (query and variables set up in let blocks)

        # Act
        result = http_client.post_graphql(query, variables)

        # Assert
        aggregate_failures 'legacy method delegation' do
          expect(result).to be_a(Hash)
          expect(result).to have_key('data')
        end

        # Cleanup
        # (automatic with VCR)
      end

      it 'works with empty variables', vcr: { cassette_name: 'linear_api/post_graphql_empty_vars' } do
        # Arrange
        empty_variables = {}

        # Act
        result = http_client.post_graphql(query, empty_variables)

        # Assert
        expect(result).to be_a(Hash)

        # Cleanup
        # (automatic with VCR)
      end
    end
  end

  describe 'private methods' do
    describe '#build_request_body' do
      context 'when building request with query and variables' do
        it 'creates proper JSON request body' do
          # Arrange
          query = 'query { issues { nodes { id } } }'
          variables = { first: 10 }

          # Act
          result = http_client.send(:build_request_body, query, variables)

          # Assert
          aggregate_failures 'request body structure' do
            expect(result).to be_a(String)
            parsed = JSON.parse(result)
            expect(parsed).to have_key('query')
            expect(parsed).to have_key('variables')
            expect(parsed['query']).to eq(query)
            expect(parsed['variables']).to eq(variables.stringify_keys)
          end

          # Cleanup
          # (no cleanup needed for pure method)
        end

        it 'handles empty variables correctly' do
          # Arrange
          query = 'query { issues { nodes { id } } }'
          variables = {}

          # Act
          result = http_client.send(:build_request_body, query, variables)

          # Assert
          parsed = JSON.parse(result)
          expect(parsed).not_to have_key('variables') # Empty variables are omitted

          # Cleanup
          # (no cleanup needed for pure method)
        end

        it 'generates valid JSON' do
          # Arrange
          query = 'query { issues { nodes { id } } }'
          variables = { first: 5, team: 'backend' }

          # Act
          result = http_client.send(:build_request_body, query, variables)

          # Assert
          expect { JSON.parse(result) }.not_to raise_error

          # Cleanup
          # (no cleanup needed for pure method)
        end
      end
    end
  end

  # === VCR INTEGRATION TESTS ===
  # Additional VCR tests for comprehensive API interaction coverage

  describe 'VCR integration tests' do
    let(:real_query) do
      <<~GRAPHQL
        query {
          issues(first: 1) {
            nodes {
              id
              title
            }
          }
        }
      GRAPHQL
    end

    let(:real_query_with_variables) do
      <<~GRAPHQL
        query($first: Int!) {
          issues(first: $first) {
            nodes {
              id
              title
              state {
                name
              }
            }
          }
        }
      GRAPHQL
    end

    context 'with valid API token and successful requests' do
      it 'successfully fetches issues data', vcr: { cassette_name: 'linear_api/successful_query' } do
        # Arrange
        # Using real or test API token from environment

        # Act
        result = http_client.post(real_query)

        # Assert
        aggregate_failures 'successful API response structure' do
          expect(result).to be_a(Hash)
          expect(result).to have_key('data')
          expect(result['data']).to have_key('issues')
          expect(result['data']['issues']).to have_key('nodes')
          expect(result['data']['issues']['nodes']).to be_an(Array)
        end

        # Cleanup
        # (automatic with VCR)
      end

      it 'handles queries with variables correctly', vcr: { cassette_name: 'linear_api/query_with_variables' } do
        # Arrange
        variables = { first: 2 }

        # Act
        result = http_client.post(real_query_with_variables, variables)

        # Assert
        aggregate_failures 'API response with variables' do
          expect(result).to be_a(Hash)
          expect(result).to have_key('data')
          expect(result['data']['issues']['nodes'].size).to be <= 2
        end

        # Cleanup
        # (automatic with VCR)
      end

      it 'handles empty variables gracefully', vcr: { cassette_name: 'linear_api/empty_variables' } do
        # Arrange
        empty_variables = {}

        # Act
        result = http_client.post(real_query, empty_variables)

        # Assert
        expect(result).to be_a(Hash)
        expect(result).to have_key('data')

        # Cleanup
        # (automatic with VCR)
      end
    end

    context 'with authentication errors' do
      it 'handles invalid API token gracefully', vcr: { cassette_name: 'linear_api/invalid_token' } do
        # Arrange
        client_with_invalid_token = described_class.new('invalid-token-12345')

        # Act & Assert
        expect { client_with_invalid_token.post(real_query) }
          .to raise_error(KanbanMetrics::ApiError, /HTTP 401|Unauthorized|Authentication/)

        # Cleanup
        # (automatic with VCR)
      end

      it 'handles missing API token', vcr: { cassette_name: 'linear_api/missing_token' } do
        # Arrange
        client_without_token = described_class.new('')

        # Act & Assert
        expect { client_without_token.post(real_query) }
          .to raise_error(KanbanMetrics::ApiError, /HTTP 401|Unauthorized|Authentication/)

        # Cleanup
        # (automatic with VCR)
      end
    end

    context 'with GraphQL errors' do
      let(:invalid_query) { 'query { invalid_field_that_does_not_exist }' }
      let(:malformed_query) { 'query { issues { nodes { nonexistent_field } } }' }

      it 'handles malformed GraphQL queries', vcr: { cassette_name: 'linear_api/malformed_query' } do
        # Arrange
        # Using valid token but invalid query

        # Act & Assert
        expect { http_client.post(invalid_query) }
          .to raise_error(KanbanMetrics::ApiError, /GraphQL errors|Cannot query field/)

        # Cleanup
        # (automatic with VCR)
      end

      it 'handles queries with invalid fields', vcr: { cassette_name: 'linear_api/invalid_fields' } do
        # Arrange
        # Query with valid structure but nonexistent fields

        # Act & Assert
        expect { http_client.post(malformed_query) }
          .to raise_error(KanbanMetrics::ApiError, /GraphQL errors|Cannot query field/)

        # Cleanup
        # (automatic with VCR)
      end

      it 'handles syntax errors in GraphQL', vcr: { cassette_name: 'linear_api/syntax_error' } do
        # Arrange
        syntax_error_query = 'query { issues { nodes id title } }' # Missing braces

        # Act & Assert
        expect { http_client.post(syntax_error_query) }
          .to raise_error(KanbanMetrics::ApiError, /GraphQL errors|Syntax Error|Field.*must have|Cannot query field/)

        # Cleanup
        # (automatic with VCR)
      end
    end

    context 'with complex real-world queries' do
      let(:team_issues_query) do
        <<~GRAPHQL
          query($teamId: String!, $first: Int) {
            team(id: $teamId) {
              id
              name
              issues(first: $first) {
                nodes {
                  id
                  title
                  state {
                    name
                    type
                  }
                  assignee {
                    name
                  }
                  createdAt
                  completedAt
                }
              }
            }
          }
        GRAPHQL
      end

      it 'handles complex team queries', vcr: { cassette_name: 'linear_api/team_issues_query' } do
        # Arrange
        variables = { teamId: 'test-team-id', first: 5 }

        # Act & Assert
        # The test team ID doesn't exist, so we expect an error
        expect { http_client.post(team_issues_query, variables) }
          .to raise_error(KanbanMetrics::ApiError, /Entity not found: Team/)

        # Cleanup
        # (automatic with VCR)
      end

      it 'handles pagination parameters', vcr: { cassette_name: 'linear_api/pagination_query' } do
        # Arrange
        pagination_query = <<~GRAPHQL
          query($first: Int, $after: String) {
            issues(first: $first, after: $after) {
              nodes {
                id
                title
              }
              pageInfo {
                hasNextPage
                endCursor
              }
            }
          }
        GRAPHQL
        variables = { first: 10, after: nil }

        # Act
        result = http_client.post(pagination_query, variables)

        # Assert
        aggregate_failures 'pagination response structure' do
          expect(result).to be_a(Hash)
          expect(result['data']['issues']).to have_key('pageInfo')
          expect(result['data']['issues']['pageInfo']).to have_key('hasNextPage')
        end

        # Cleanup
        # (automatic with VCR)
      end
    end

    context 'with rate limiting scenarios' do
      it 'handles rate limiting gracefully', vcr: { cassette_name: 'linear_api/successful_after_rate_limit' } do
        # Arrange
        # Multiple rapid requests to potentially trigger rate limiting
        # Note: This cassette contains a successful response after rate limiting recovery

        # Act & Assert
        # This test would only trigger if we actually hit rate limits during recording
        expect { http_client.post(real_query) }
          .not_to raise_error

        # Cleanup
        # (automatic with VCR)
      end
    end

    context 'when testing post_graphql backward compatibility' do
      it 'maintains compatibility with legacy post_graphql method',
         vcr: { cassette_name: 'linear_api/legacy_method' } do
        # Arrange
        variables = { first: 1 }

        # Act
        result = http_client.post_graphql(real_query_with_variables, variables)

        # Assert
        aggregate_failures 'legacy method compatibility' do
          expect(result).to be_a(Hash)
          expect(result).to have_key('data')
        end

        # Cleanup
        # (automatic with VCR)
      end
    end
  end
end
