# frozen_string_literal: true

require 'spec_helper'

RSpec.describe KanbanMetrics::Linear::Client do
  # Test Data Setup
  subject(:client) { described_class.new(api_token) }

  let(:api_token) { 'test-token-123' }
  let(:sample_options) { { team_id: 'team-123', start_date: '2024-01-01' } }
  let(:sample_issues) do
    [
      { 'id' => 'issue-1', 'title' => 'Test Issue 1' },
      { 'id' => 'issue-2', 'title' => 'Test Issue 2' }
    ]
  end

  # Mock Dependencies
  let(:mock_http_client) { instance_double(KanbanMetrics::Linear::HttpClient) }
  let(:mock_query_builder) { instance_double(KanbanMetrics::Linear::QueryBuilder) }
  let(:mock_cache) { instance_double(KanbanMetrics::Linear::Cache) }
  let(:mock_paginator) { instance_double(KanbanMetrics::Linear::ApiPaginator) }

  describe '#initialize' do
    it 'creates a new client instance' do
      # Execute & Verify
      expect(client).to be_a(described_class)
    end

    it 'initializes all dependencies correctly' do
      # Setup
      expect(KanbanMetrics::Linear::HttpClient).to receive(:new).with(api_token)
      expect(KanbanMetrics::Linear::QueryBuilder).to receive(:new)
      expect(KanbanMetrics::Linear::Cache).to receive(:new)

      # Execute & Verify
      described_class.new(api_token)
    end
  end

  describe '#fetch_issues' do
    subject(:fetch_issues) { client.fetch_issues(options) }

    before do
      # Setup - Mock all dependencies
      allow(KanbanMetrics::Linear::HttpClient).to receive(:new).and_return(mock_http_client)
      allow(KanbanMetrics::Linear::QueryBuilder).to receive(:new).and_return(mock_query_builder)
      allow(KanbanMetrics::Linear::Cache).to receive(:new).and_return(mock_cache)
      allow(KanbanMetrics::Linear::ApiPaginator).to receive(:new).and_return(mock_paginator)
    end

    context 'with caching enabled (default)' do
      # Setup
      let(:options) { sample_options }
      let(:cache_key) { 'test-cache-key' }

      context 'when cache hit' do
        before do
          # Setup
          allow(mock_cache).to receive(:generate_cache_key).and_return(cache_key)
          allow(mock_cache).to receive(:fetch_cached_issues).with(cache_key).and_return(sample_issues)
          allow(mock_paginator).to receive(:fetch_all_pages) # Stub method so we can spy on it
        end

        it 'returns cached issues without API call' do
          # Execute
          result = fetch_issues

          # Verify
          aggregate_failures 'cache hit behavior' do
            expect(result).to eq(sample_issues)
            expect(mock_cache).to have_received(:fetch_cached_issues).with(cache_key)
            expect(mock_paginator).not_to have_received(:fetch_all_pages)
          end
        end
      end

      context 'when cache miss' do
        before do
          # Setup
          allow(mock_cache).to receive(:generate_cache_key).and_return(cache_key)
          allow(mock_cache).to receive(:fetch_cached_issues).with(cache_key).and_return(nil)
          allow(mock_paginator).to receive(:fetch_all_pages).and_return(sample_issues)
          allow(mock_cache).to receive(:save_issues_to_cache)
        end

        it 'fetches from API and saves to cache' do
          # Execute
          result = fetch_issues

          # Verify
          aggregate_failures 'cache miss behavior' do
            expect(result).to eq(sample_issues)
            expect(mock_paginator).to have_received(:fetch_all_pages)
            expect(mock_cache).to have_received(:save_issues_to_cache).with(cache_key, sample_issues)
          end
        end
      end
    end

    context 'with caching disabled' do
      # Setup
      let(:options) { sample_options.merge(no_cache: true) }

      before do
        allow(mock_cache).to receive(:fetch_cached_issues).and_return(nil)
        allow(mock_paginator).to receive(:fetch_all_pages).and_return(sample_issues)
      end

      it 'bypasses cache and fetches from API directly' do
        # Execute
        result = fetch_issues

        # Verify
        aggregate_failures 'cache bypass behavior' do
          expect(result).to eq(sample_issues)
          expect(mock_paginator).to have_received(:fetch_all_pages)
          expect(mock_cache).not_to have_received(:fetch_cached_issues)
        end
      end
    end

    context 'with empty options' do
      # Setup
      let(:options) { {} }

      before do
        allow(mock_cache).to receive_messages(generate_cache_key: 'default-key', fetch_cached_issues: nil)
        allow(mock_paginator).to receive(:fetch_all_pages).and_return([])
        allow(mock_cache).to receive(:save_issues_to_cache)
      end

      it 'handles empty options gracefully' do
        # Execute
        result = fetch_issues

        # Verify
        expect(result).to eq([])
      end
    end

    context 'with no options' do
      subject(:fetch_issues) { client.fetch_issues }

      before do
        # Setup
        allow(mock_cache).to receive_messages(generate_cache_key: 'default-key', fetch_cached_issues: nil)
        allow(mock_paginator).to receive(:fetch_all_pages).and_return([])
        allow(mock_cache).to receive(:save_issues_to_cache)
      end

      it 'handles no options gracefully' do
        # Execute
        result = fetch_issues

        # Verify
        expect(result).to eq([])
      end
    end
  end

  describe 'private methods' do
    before do
      # Setup - Mock all dependencies
      allow(KanbanMetrics::Linear::HttpClient).to receive(:new).and_return(mock_http_client)
      allow(KanbanMetrics::Linear::QueryBuilder).to receive(:new).and_return(mock_query_builder)
      allow(KanbanMetrics::Linear::Cache).to receive(:new).and_return(mock_cache)
      allow(KanbanMetrics::Linear::ApiPaginator).to receive(:new).and_return(mock_paginator)
    end

    describe '#fetch_with_caching' do
      subject(:fetch_with_caching) { client.send(:fetch_with_caching, query_options) }

      # Setup
      let(:query_options) { KanbanMetrics::QueryOptions.new(sample_options) }
      let(:cache_key) { 'test-key' }

      context 'when cache hit' do
        before do
          # Setup
          allow(mock_cache).to receive(:generate_cache_key).with(query_options).and_return(cache_key)
          allow(mock_cache).to receive(:fetch_cached_issues).with(cache_key).and_return(sample_issues)
        end

        it 'returns cached issues' do
          # Execute
          result = fetch_with_caching

          # Verify
          expect(result).to eq(sample_issues)
        end
      end

      context 'when cache miss' do
        before do
          # Setup
          allow(mock_cache).to receive(:generate_cache_key).with(query_options).and_return(cache_key)
          allow(mock_cache).to receive(:fetch_cached_issues).with(cache_key).and_return(nil)
          allow(mock_paginator).to receive(:fetch_all_pages).with(query_options).and_return(sample_issues)
          allow(mock_cache).to receive(:save_issues_to_cache).with(cache_key, sample_issues)
        end

        it 'fetches from API and caches result' do
          # Execute
          result = fetch_with_caching

          # Verify
          aggregate_failures 'API fetch and cache save' do
            expect(result).to eq(sample_issues)
            expect(mock_paginator).to have_received(:fetch_all_pages).with(query_options)
            expect(mock_cache).to have_received(:save_issues_to_cache).with(cache_key, sample_issues)
          end
        end
      end
    end

    describe '#fetch_from_api' do
      subject(:fetch_from_api) { client.send(:fetch_from_api, query_options) }

      # Setup
      let(:query_options) { KanbanMetrics::QueryOptions.new(sample_options) }

      before do
        # Setup
        allow(mock_paginator).to receive(:fetch_all_pages).with(query_options).and_return(sample_issues)
      end

      it 'uses paginator to fetch all pages' do
        # Execute
        result = fetch_from_api

        # Verify
        aggregate_failures 'API paginated fetch' do
          expect(result).to eq(sample_issues)
          expect(mock_paginator).to have_received(:fetch_all_pages).with(query_options)
        end
      end
    end

    describe '#paginated_fetch' do
      subject(:paginated_fetch) { client.send(:paginated_fetch, query_options) }

      # Setup
      let(:query_options) { KanbanMetrics::QueryOptions.new(sample_options) }

      before do
        # Setup
        allow(mock_paginator).to receive(:fetch_all_pages).with(query_options).and_return(sample_issues)
      end

      it 'creates and uses ApiPaginator' do
        # Execute
        result = paginated_fetch

        # Verify
        aggregate_failures 'paginator creation and usage' do
          expect(result).to eq(sample_issues)
          expect(KanbanMetrics::Linear::ApiPaginator).to have_received(:new).with(mock_http_client, mock_query_builder)
        end
      end
    end

    describe 'logging methods' do
      describe '#log_cache_miss' do
        subject(:log_cache_miss) { client.send(:log_cache_miss) }

        context 'when not quiet mode' do
          before do
            # Setup
            allow(ENV).to receive(:[]).and_call_original
            allow(ENV).to receive(:[]).with('QUIET').and_return(nil)
            allow(ENV).to receive(:[]).with('DEBUG').and_return(nil)
          end

          it 'logs cache miss message' do
            # Execute & Verify
            expect { log_cache_miss }.to output(/Cache miss/).to_stdout
          end
        end

        context 'when debug enabled' do
          before do
            # Setup
            allow(ENV).to receive(:[]).and_call_original
            allow(ENV).to receive(:[]).with('DEBUG').and_return('true')
            allow(ENV).to receive(:[]).with('QUIET').and_return('true')
          end

          it 'logs cache miss even in quiet mode' do
            # Execute & Verify
            expect { log_cache_miss }.to output(/Cache miss/).to_stdout
          end
        end

        context 'when quiet and debug disabled' do
          before do
            # Setup
            allow(ENV).to receive(:[]).with('DEBUG').and_return(nil)
            allow(ENV).to receive(:[]).with('QUIET').and_return('true')
          end

          it 'does not log anything' do
            # Execute & Verify
            expect { log_cache_miss }.not_to output.to_stdout
          end
        end
      end

      describe '#log_api_fetch_start' do
        subject(:log_api_fetch_start) { client.send(:log_api_fetch_start, cache_disabled) }

        before do
          # Setup
          allow(ENV).to receive(:[]).with('DEBUG').and_return('true')
        end

        context 'with cache disabled' do
          # Setup
          let(:cache_disabled) { true }

          it 'logs cache disabled message' do
            # Execute & Verify
            expect { log_api_fetch_start }.to output(/Cache disabled/).to_stdout
          end
        end

        context 'with cache enabled' do
          # Setup
          let(:cache_disabled) { false }

          it 'logs normal fetch message' do
            # Execute & Verify
            expect { log_api_fetch_start }.to output(/Fetching from API/).to_stdout
          end
        end
      end

      describe '#log_api_fetch_complete' do
        subject(:log_api_fetch_complete) { client.send(:log_api_fetch_complete, issue_count) }

        context 'with large dataset' do
          # Setup
          let(:issue_count) { 300 }

          it 'logs completion message' do
            # Execute & Verify
            expect { log_api_fetch_complete }.to output(/Successfully fetched 300/).to_stdout
          end
        end

        context 'with small dataset and debug enabled' do
          # Setup
          let(:issue_count) { 50 }

          before do
            # Setup
            allow(ENV).to receive(:[]).with('DEBUG').and_return('true')
          end

          it 'logs completion message in debug mode' do
            # Execute & Verify
            expect { log_api_fetch_complete }.to output(/Successfully fetched 50/).to_stdout
          end
        end

        context 'with small dataset and debug disabled' do
          # Setup
          let(:issue_count) { 50 }

          before do
            # Setup
            allow(ENV).to receive(:[]).with('DEBUG').and_return(nil)
          end

          it 'does not log for small datasets' do
            # Execute & Verify
            expect { log_api_fetch_complete }.not_to output.to_stdout
          end
        end
      end
    end
  end
end
