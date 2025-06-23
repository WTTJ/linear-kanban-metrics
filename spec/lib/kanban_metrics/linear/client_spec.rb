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
  let(:mock_orchestrator) { instance_double(KanbanMetrics::Linear::ApiRequestOrchestrator) }
  let(:mock_caching_strategy) { instance_double(KanbanMetrics::Linear::CachingStrategy) }
  let(:mock_cache) { instance_double(KanbanMetrics::Linear::Cache) }

  describe '#initialize' do
    it 'creates a new client instance' do
      # Execute & Verify
      expect(client).to be_a(described_class)
    end
  end

  describe '#fetch_issues' do
    subject(:fetch_issues) { client.fetch_issues(options) }

    before do
      # Setup - Mock service object creation and HTTP components
      allow(KanbanMetrics::Linear::HttpClient).to receive(:new).and_return(double('HttpClient'))
      allow(KanbanMetrics::Linear::QueryBuilder).to receive(:new).and_return(double('QueryBuilder'))
      allow(KanbanMetrics::Linear::ApiRequestOrchestrator).to receive(:new).and_return(mock_orchestrator)
      allow(KanbanMetrics::Linear::CachingStrategy).to receive(:new).and_return(mock_caching_strategy)
      allow(KanbanMetrics::Linear::Cache).to receive(:new).and_return(mock_cache)
    end

    context 'with caching enabled (default)' do
      let(:options) { sample_options }

      before do
        allow(mock_caching_strategy).to receive(:fetch_with_cache).and_yield.and_return(sample_issues)
        allow(mock_orchestrator).to receive(:fetch_issues).and_return(sample_issues)
      end

      it 'uses caching strategy to fetch issues' do
        # Execute
        result = fetch_issues

        # Verify
        aggregate_failures 'caching behavior' do
          expect(result).to eq(sample_issues)
          expect(mock_caching_strategy).to have_received(:fetch_with_cache)
        end
      end
    end

    context 'with caching disabled' do
      let(:options) { sample_options.merge(no_cache: true) }

      before do
        allow(mock_orchestrator).to receive(:fetch_issues).and_return(sample_issues)
        allow(mock_caching_strategy).to receive(:fetch_with_cache)
      end

      it 'bypasses cache and fetches directly via orchestrator' do
        # Execute
        result = fetch_issues

        # Verify
        aggregate_failures 'cache bypass behavior' do
          expect(result).to eq(sample_issues)
          expect(mock_orchestrator).to have_received(:fetch_issues)
          expect(mock_caching_strategy).not_to have_received(:fetch_with_cache)
        end
      end
    end

    context 'with empty options' do
      let(:options) { {} }

      before do
        allow(mock_caching_strategy).to receive(:fetch_with_cache).and_return([])
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
        allow(mock_caching_strategy).to receive(:fetch_with_cache).and_return([])
      end

      it 'handles no options gracefully' do
        # Execute
        result = fetch_issues

        # Verify
        expect(result).to eq([])
      end
    end
  end
end
