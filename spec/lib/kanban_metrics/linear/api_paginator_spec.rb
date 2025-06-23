# frozen_string_literal: true

require 'spec_helper'

RSpec.describe KanbanMetrics::Linear::ApiPaginator do
  # Test Data Setup
  subject(:paginator) { described_class.new(mock_http_client, mock_query_builder) }

  let(:mock_http_client) { instance_double(KanbanMetrics::Linear::HttpClient) }
  let(:mock_query_builder) { instance_double(KanbanMetrics::Linear::QueryBuilder) }
  let(:options) { KanbanMetrics::QueryOptions.new(team_id: 'team-123') }

  let(:single_page_response) do
    {
      'data' => {
        'issues' => {
          'nodes' => [
            { 'id' => 'issue-1', 'title' => 'Test Issue 1' },
            { 'id' => 'issue-2', 'title' => 'Test Issue 2' }
          ],
          'pageInfo' => {
            'hasNextPage' => false,
            'endCursor' => 'cursor-end'
          }
        }
      }
    }
  end

  let(:multi_page_response_1) do
    {
      'data' => {
        'issues' => {
          'nodes' => [
            { 'id' => 'issue-1', 'title' => 'Test Issue 1' }
          ],
          'pageInfo' => {
            'hasNextPage' => true,
            'endCursor' => 'cursor-1'
          }
        }
      }
    }
  end

  let(:multi_page_response_2) do
    {
      'data' => {
        'issues' => {
          'nodes' => [
            { 'id' => 'issue-2', 'title' => 'Test Issue 2' }
          ],
          'pageInfo' => {
            'hasNextPage' => false,
            'endCursor' => 'cursor-2'
          }
        }
      }
    }
  end

  describe '#initialize' do
    it 'creates a paginator instance with dependencies' do
      # Execute & Verify
      expect(paginator).to be_a(described_class)
    end
  end

  describe '#fetch_all_pages' do
    subject(:fetch_all_pages) { paginator.fetch_all_pages(options) }

    context 'with single page of results' do
      before do
        # Setup
        allow(mock_query_builder).to receive(:build_issues_query).and_return('test-query')
        allow(mock_http_client).to receive(:post_graphql).and_return(single_page_response)
      end

      it 'fetches all issues from single page' do
        # Execute
        result = fetch_all_pages

        # Verify
        aggregate_failures 'single page results' do
          expect(result).to be_an(Array)
          expect(result.length).to eq(2)
          expect(result[0]['id']).to eq('issue-1')
          expect(result[1]['id']).to eq('issue-2')
        end
      end

      it 'calls query builder with initial options' do
        # Execute
        fetch_all_pages

        # Verify
        expect(mock_query_builder).to have_received(:build_issues_query).with(options, nil)
      end

      it 'makes single HTTP request' do
        # Execute
        fetch_all_pages

        # Verify
        expect(mock_http_client).to have_received(:post_graphql).once
      end
    end

    context 'with multiple pages of results' do
      before do
        # Setup
        allow(mock_query_builder).to receive(:build_issues_query).and_return('test-query')
        allow(mock_http_client).to receive(:post_graphql)
          .and_return(multi_page_response_1, multi_page_response_2)
      end

      it 'fetches all issues from multiple pages' do
        # Execute
        result = fetch_all_pages

        # Verify
        aggregate_failures 'multiple page results' do
          expect(result).to be_an(Array)
          expect(result.length).to eq(2)
          expect(result[0]['id']).to eq('issue-1')
          expect(result[1]['id']).to eq('issue-2')
        end
      end

      it 'makes multiple HTTP requests' do
        # Execute
        fetch_all_pages

        # Verify
        expect(mock_http_client).to have_received(:post_graphql).twice
      end

      it 'passes cursor for subsequent pages' do
        # Execute
        fetch_all_pages

        # Verify
        aggregate_failures 'cursor handling' do
          expect(mock_query_builder).to have_received(:build_issues_query).with(options, nil)
          expect(mock_query_builder).to have_received(:build_issues_query).with(options, 'cursor-1')
        end
      end
    end

    context 'with empty response' do
      # Setup
      let(:empty_response) { { 'data' => {} } }

      before do
        allow(mock_query_builder).to receive(:build_issues_query).and_return('test-query')
        allow(mock_http_client).to receive(:post_graphql).and_return(empty_response)
      end

      it 'returns empty array for empty response' do
        # Execute
        result = fetch_all_pages

        # Verify
        expect(result).to eq([])
      end
    end

    context 'with nil response' do
      before do
        # Setup
        allow(mock_query_builder).to receive(:build_issues_query).and_return('test-query')
        allow(mock_http_client).to receive(:post_graphql).and_return(nil)
      end

      it 'handles nil response gracefully' do
        # Execute
        result = fetch_all_pages

        # Verify
        expect(result).to eq([])
      end
    end

    context 'with safety limit reached' do
      # Setup
      let(:always_has_next_page_response) do
        {
          'data' => {
            'issues' => {
              'nodes' => [{ 'id' => 'issue-1' }],
              'pageInfo' => {
                'hasNextPage' => true,
                'endCursor' => 'cursor-next'
              }
            }
          }
        }
      end

      before do
        allow(mock_query_builder).to receive(:build_issues_query).and_return('test-query')
        allow(mock_http_client).to receive(:post_graphql).and_return(always_has_next_page_response)
      end

      it 'stops at safety limit' do
        # Execute
        result = fetch_all_pages

        # Verify
        aggregate_failures 'safety limit enforcement' do
          expect(result.length).to eq(100) # MAX_PAGES limit
          expect(mock_http_client).to have_received(:post_graphql).exactly(100).times
        end
      end
    end
  end

  describe 'constants' do
    it 'defines MAX_PAGES constant through PaginationConfig' do
      # Execute & Verify
      expect(KanbanMetrics::Linear::PaginationConfig::MAX_PAGES).to eq(100)
    end
  end
end

RSpec.describe KanbanMetrics::Linear::PageState do
  subject(:page_state) { described_class.new }

  describe '#initialize' do
    it 'initializes with default values' do
      # Execute & Verify
      aggregate_failures 'default initialization' do
        expect(page_state.current_page).to eq(1)
        expect(page_state.after_cursor).to be_nil
        expect(page_state.has_next_page?).to be true
      end
    end
  end

  describe '#has_next_page?' do
    subject(:has_next_page) { page_state.has_next_page? }

    context 'with initial state' do
      it 'returns true initially' do
        # Execute & Verify
        expect(has_next_page).to be true
      end
    end

    context 'after update with no next page' do
      before do
        # Setup
        page_state.update({ has_next_page: false, end_cursor: 'final' })
      end

      it 'returns false after no next page update' do
        # Execute & Verify
        expect(has_next_page).to be false
      end
    end
  end

  describe '#update' do
    subject(:update_page_state) { page_state.update(page_info) }

    context 'with has_next_page false' do
      # Setup
      let(:page_info) { { has_next_page: false, end_cursor: 'cursor' } }

      it 'updates has_next_page status' do
        # Execute
        update_page_state

        # Verify
        expect(page_state.has_next_page?).to be false
      end
    end

    context 'with new cursor' do
      # Setup
      let(:page_info) { { has_next_page: true, end_cursor: 'new-cursor' } }

      it 'updates after_cursor' do
        # Execute
        update_page_state

        # Verify
        expect(page_state.after_cursor).to eq('new-cursor')
      end
    end

    context 'with page increment' do
      # Setup
      let(:page_info) { { has_next_page: true, end_cursor: 'cursor' } }

      it 'increments current_page' do
        # Execute & Verify
        expect { update_page_state }.to change(page_state, :current_page).from(1).to(2)
      end
    end

    context 'with multiple updates' do
      before do
        # Setup
        page_state.update({ has_next_page: true, end_cursor: 'cursor-1' })
        page_state.update({ has_next_page: false, end_cursor: 'cursor-2' })
      end

      it 'handles multiple updates correctly' do
        # Execute & Verify
        aggregate_failures 'multiple updates' do
          expect(page_state.current_page).to eq(3)
          expect(page_state.after_cursor).to eq('cursor-2')
          expect(page_state.has_next_page?).to be false
        end
      end
    end
  end

  describe '#safety_limit_reached?' do
    subject(:safety_limit_reached) { page_state.safety_limit_reached? }

    context 'with initial state' do
      it 'returns false initially' do
        # Execute & Verify
        expect(safety_limit_reached).to be false
      end
    end

    context 'below safety limit' do
      before do
        # Setup
        99.times { page_state.update({ has_next_page: true, end_cursor: 'cursor' }) }
      end

      it 'returns false below limit' do
        # Execute & Verify
        expect(safety_limit_reached).to be false
      end
    end

    context 'at safety limit' do
      before do
        # Setup
        100.times { page_state.update({ has_next_page: true, end_cursor: 'cursor' }) }
      end

      it 'returns true at limit' do
        # Execute & Verify
        expect(safety_limit_reached).to be true
      end
    end

    context 'above safety limit' do
      before do
        # Setup
        101.times { page_state.update({ has_next_page: true, end_cursor: 'cursor' }) }
      end

      it 'returns true above limit' do
        # Execute & Verify
        expect(safety_limit_reached).to be true
      end
    end
  end

  describe 'constants' do
    it 'defines MAX_PAGES constant' do
      # Execute & Verify
      expect(described_class::MAX_PAGES).to eq(100)
    end
  end
end
