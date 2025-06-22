# frozen_string_literal: true

require 'spec_helper'

RSpec.describe KanbanMetrics::Linear::QueryBuilder do
  let(:query_builder) { described_class.new }

  describe '#build_issues_query' do
    let(:base_options) { KanbanMetrics::QueryOptions.new(page_size: 50) }

    context 'when building query with team identifier' do
      it 'uses team key filter for short team identifiers' do
        # Arrange
        options = KanbanMetrics::QueryOptions.new(team_id: 'ROI', page_size: 50)

        # Act
        query = query_builder.build_issues_query(options)

        # Assert
        aggregate_failures 'team key filter usage' do
          expect(query).to include('filter: { team: { key: { eq: "ROI" } } }')
          expect(query).to include('first: 50')
          expect(query).to include('pageInfo { hasNextPage endCursor }')
          expect(query).to include('nodes {')
        end

        # Cleanup
        # (automatic with let blocks)
      end

      it 'uses team ID filter for UUID team identifiers' do
        # Arrange
        uuid = '5cb3ee70-693d-406b-a6a5-23a002ef10d6'
        options = KanbanMetrics::QueryOptions.new(team_id: uuid, page_size: 50)

        # Act
        query = query_builder.build_issues_query(options)

        # Assert
        aggregate_failures 'team UUID filter usage' do
          expect(query).to include("filter: { team: { id: { eq: \"#{uuid}\" } } }")
          expect(query).to include('first: 50')
        end

        # Cleanup
        # (automatic with let blocks)
      end

      it 'handles various team key formats' do
        # Arrange
        test_cases = %w[ROI FRONT BACKEND AI DEVOPS]

        test_cases.each do |team_key|
          # Act
          options = KanbanMetrics::QueryOptions.new(team_id: team_key, page_size: 50)
          query = query_builder.build_issues_query(options)

          # Assert
          expect(query).to include("team: { key: { eq: \"#{team_key}\" } }")
        end

        # Cleanup
        # (automatic with let blocks)
      end
    end

    context 'when building query with date filters' do
      it 'includes date range filters when provided' do
        # Arrange
        options = KanbanMetrics::QueryOptions.new(
          start_date: '2025-01-01',
          end_date: '2025-01-31',
          page_size: 50
        )

        # Act
        query = query_builder.build_issues_query(options)

        # Assert
        aggregate_failures 'date filter inclusion' do
          expect(query).to include('updatedAt: { gte: "2025-01-01T00:00:00.000Z", lte: "2025-01-31T23:59:59.999Z" }')
          expect(query).to include('first: 50')
        end

        # Cleanup
        # (automatic with let blocks)
      end

      it 'handles only start date' do
        # Arrange
        options = KanbanMetrics::QueryOptions.new(
          start_date: '2025-01-01',
          page_size: 50
        )

        # Act
        query = query_builder.build_issues_query(options)

        # Assert
        expect(query).to include('updatedAt: { gte: "2025-01-01T00:00:00.000Z" }')

        # Cleanup
        # (automatic with let blocks)
      end

      it 'handles only end date' do
        # Arrange
        options = KanbanMetrics::QueryOptions.new(
          end_date: '2025-01-31',
          page_size: 50
        )

        # Act
        query = query_builder.build_issues_query(options)

        # Assert
        expect(query).to include('updatedAt: { lte: "2025-01-31T23:59:59.999Z" }')

        # Cleanup
        # (automatic with let blocks)
      end
    end

    context 'when building query with include_archived option' do
      it 'includes includeArchived parameter when true' do
        # Arrange
        options = KanbanMetrics::QueryOptions.new(
          include_archived: true,
          page_size: 50
        )

        # Act
        query = query_builder.build_issues_query(options)

        # Assert
        expect(query).to include('includeArchived: true')

        # Cleanup
        # (automatic with let blocks)
      end

      it 'excludes includeArchived parameter when false' do
        # Arrange
        options = KanbanMetrics::QueryOptions.new(
          include_archived: false,
          page_size: 50
        )

        # Act
        query = query_builder.build_issues_query(options)

        # Assert
        expect(query).not_to include('includeArchived')

        # Cleanup
        # (automatic with let blocks)
      end
    end

    context 'when building query with pagination' do
      it 'includes after cursor when provided' do
        # Arrange
        after_cursor = 'cursor-abc-123'

        # Act
        query = query_builder.build_issues_query(base_options, after_cursor)

        # Assert
        aggregate_failures 'pagination with cursor' do
          expect(query).to include('first: 50')
          expect(query).to include('after: "cursor-abc-123"')
        end

        # Cleanup
        # (automatic with let blocks)
      end

      it 'excludes after cursor when not provided' do
        # Arrange
        # (base_options set up in let block)

        # Act
        query = query_builder.build_issues_query(base_options)

        # Assert
        aggregate_failures 'pagination without cursor' do
          expect(query).to include('first: 50')
          expect(query).not_to include('after:')
        end

        # Cleanup
        # (automatic with let blocks)
      end
    end

    context 'when building complex queries' do
      it 'combines multiple filters correctly' do
        # Arrange
        options = KanbanMetrics::QueryOptions.new(
          team_id: 'ROI',
          start_date: '2025-01-01',
          end_date: '2025-01-31',
          include_archived: true,
          page_size: 100
        )
        after_cursor = 'complex-cursor-123'

        # Act
        query = query_builder.build_issues_query(options, after_cursor)

        # Assert
        aggregate_failures 'complex query structure' do
          expect(query).to include('team: { key: { eq: "ROI" } }')
          expect(query).to include('updatedAt: { gte: "2025-01-01T00:00:00.000Z", lte: "2025-01-31T23:59:59.999Z" }')
          expect(query).to include('includeArchived: true')
          expect(query).to include('first: 100')
          expect(query).to include('after: "complex-cursor-123"')
        end

        # Cleanup
        # (automatic with let blocks)
      end
    end
  end

  describe 'private methods' do
    describe '#team_filter' do
      it 'detects UUID and uses ID filter' do
        # Arrange
        uuid = '5cb3ee70-693d-406b-a6a5-23a002ef10d6'

        # Act
        result = query_builder.send(:team_filter, uuid)

        # Assert
        expect(result).to eq("team: { id: { eq: \"#{uuid}\" } }")

        # Cleanup
        # (no cleanup needed for private method test)
      end

      it 'detects team key and uses key filter' do
        # Arrange
        team_key = 'ROI'

        # Act
        result = query_builder.send(:team_filter, team_key)

        # Assert
        expect(result).to eq("team: { key: { eq: \"#{team_key}\" } }")

        # Cleanup
        # (no cleanup needed for private method test)
      end

      it 'handles various team key formats' do
        # Arrange
        team_keys = %w[A AB ABC ABCD FRONT BACKEND]

        team_keys.each do |key|
          # Act
          result = query_builder.send(:team_filter, key)

          # Assert
          expect(result).to eq("team: { key: { eq: \"#{key}\" } }")
        end

        # Cleanup
        # (no cleanup needed for private method test)
      end
    end
  end
end
