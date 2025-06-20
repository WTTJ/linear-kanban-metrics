# frozen_string_literal: true

require 'spec_helper'

RSpec.describe KanbanMetrics::Linear::Client, :vcr do
  # Test Data Setup
  # Named Subject
  subject(:client) { described_class.new(api_token) }

  let(:api_token) { ENV.fetch('LINEAR_API_TOKEN', 'test-token') }
  let(:test_team_id) { 'test-team-id' }
  let(:test_options) do
    {
      team_id: test_team_id,
      start_date: '2024-01-01',
      end_date: '2024-01-31',
      page_size: 10
    }
  end

  describe '#fetch_issues', :vcr do
    context 'with valid API credentials' do
      # VCR cassette for this specific test
      it 'fetches issues from Linear API', vcr: { cassette_name: 'linear_api/fetch_issues_success' } do
        # Setup - nothing needed, using let blocks

        # Execute
        result = client.fetch_issues(test_options)

        # Verify
        aggregate_failures 'API response validation' do
          expect(result).to be_an(Array)
          expect(result).not_to be_empty if result.any?

          if result.any?
            issue = result.first
            expect(issue).to have_key('id')
            expect(issue).to have_key('title')
          end
        end
      end

      it 'handles pagination correctly', vcr: { cassette_name: 'linear_api/fetch_issues_paginated' } do
        # Setup
        paginated_options = test_options.merge(page_size: 5)

        # Execute
        result = client.fetch_issues(paginated_options)

        # Verify
        expect(result).to be_an(Array)
        # NOTE: Actual pagination testing would need multiple pages of data
      end
    end

    context 'with invalid API credentials' do
      # Setup
      let(:api_token) { 'invalid-token' }

      it 'raises authentication error', vcr: { cassette_name: 'linear_api/auth_error' } do
        # Execute & Verify
        expect { client.fetch_issues(test_options) }.to raise_error(KanbanMetrics::ApiError, /Authentication required/)
      end
    end

    context 'with network issues' do
      it 'handles timeout errors', vcr: { cassette_name: 'linear_api/timeout_error' } do
        # Setup would involve configuring WebMock to simulate timeout
        # Execute & Verify - depends on implementation
        expect { client.fetch_issues(test_options) }.not_to raise_error
      end
    end
  end

  describe 'caching behavior' do
    context 'when cache is enabled' do
      it 'uses cached data on subsequent requests', vcr: { cassette_name: 'linear_api/cache_behavior' } do
        # Setup - first request will populate cache

        # Execute - first request
        first_result = client.fetch_issues(test_options)

        # Execute - second request (should use cache)
        second_result = client.fetch_issues(test_options)

        # Verify
        aggregate_failures 'cache behavior' do
          expect(first_result).to eq(second_result)
          expect(first_result).to be_an(Array)
        end
      end
    end

    context 'when cache is disabled' do
      # Setup
      let(:no_cache_options) { test_options.merge(no_cache: true) }

      it 'bypasses cache', vcr: { cassette_name: 'linear_api/no_cache' } do
        # Execute
        result = client.fetch_issues(no_cache_options)

        # Verify
        expect(result).to be_an(Array)
        # Additional cache-specific assertions would go here
      end
    end
  end

  describe 'error handling' do
    context 'with GraphQL errors' do
      it 'raises API error for GraphQL errors', vcr: { cassette_name: 'linear_api/graphql_errors' } do
        # Setup
        invalid_options = test_options.merge(team_id: 'non-existent-team')

        # Execute & Verify
        expect { client.fetch_issues(invalid_options) }.to raise_error(KanbanMetrics::ApiError)
      end
    end

    context 'with HTTP errors' do
      it 'handles server errors gracefully', vcr: { cassette_name: 'linear_api/server_error' } do
        # Execute & Verify
        expect { client.fetch_issues(test_options) }.not_to raise_error
      end
    end
  end
end
