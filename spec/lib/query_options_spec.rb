# frozen_string_literal: true

require 'spec_helper'

RSpec.describe KanbanMetrics::QueryOptions do
  describe '#initialize' do
    context 'when no options are provided' do
      it 'sets default values correctly' do
        # Arrange & Act
        query_options = described_class.new

        # Assert
        aggregate_failures 'default values validation' do
          expect(query_options.team_id).to be_nil
          expect(query_options.start_date).to be_nil
          expect(query_options.end_date).to be_nil
          expect(query_options.page_size).to eq(250)
          expect(query_options.include_archived).to be false
        end
      end
    end

    context 'when options are provided' do
      it 'accepts and stores provided options correctly' do
        # Arrange
        options = {
          team_id: 'team-123',
          start_date: '2024-01-01',
          end_date: '2024-01-31',
          page_size: 100,
          include_archived: true
        }

        # Act
        query_options = described_class.new(options)

        # Assert
        aggregate_failures 'provided options validation' do
          expect(query_options.team_id).to eq('team-123')
          expect(query_options.start_date).to eq('2024-01-01')
          expect(query_options.end_date).to eq('2024-01-31')
          expect(query_options.page_size).to eq(100)
          expect(query_options.include_archived).to be true
        end
      end

      it 'handles partial options correctly' do
        # Arrange
        partial_options = {
          team_id: 'team-456',
          include_archived: true
        }

        # Act
        query_options = described_class.new(partial_options)

        # Assert
        aggregate_failures 'partial options with defaults' do
          expect(query_options.team_id).to eq('team-456')
          expect(query_options.include_archived).to be true
          expect(query_options.start_date).to be_nil
          expect(query_options.end_date).to be_nil
          expect(query_options.page_size).to eq(250) # default
        end
      end
    end

    context 'when normalizing page size' do
      it 'normalizes page size to maximum of 250' do
        # Arrange
        oversized_page_size = 500

        # Act
        query_options = described_class.new(page_size: oversized_page_size)

        # Assert
        aggregate_failures 'page size normalization - maximum' do
          expect(query_options.page_size).to eq(250)
          expect(query_options.page_size).to be <= 250
        end
      end

      it 'normalizes page size to minimum of 1' do
        # Arrange
        undersized_page_size = 0

        # Act
        query_options = described_class.new(page_size: undersized_page_size)

        # Assert
        aggregate_failures 'page size normalization - minimum' do
          expect(query_options.page_size).to eq(1)
          expect(query_options.page_size).to be >= 1
        end
      end

      it 'handles string page size correctly' do
        # Arrange
        string_page_size = '100'

        # Act
        query_options = described_class.new(page_size: string_page_size)

        # Assert
        aggregate_failures 'string page size handling' do
          expect(query_options.page_size).to eq(100)
          expect(query_options.page_size).to be_a(Integer)
        end
      end

      it 'handles invalid string page size gracefully' do
        # Arrange
        invalid_string_page_size = 'invalid'

        # Act
        query_options = described_class.new(page_size: invalid_string_page_size)

        # Assert
        expect(query_options.page_size).to eq(250) # should fallback to default
      end

      it 'handles negative page size' do
        # Arrange
        negative_page_size = -10

        # Act
        query_options = described_class.new(page_size: negative_page_size)

        # Assert
        expect(query_options.page_size).to eq(1) # should normalize to minimum
      end
    end
  end

  describe '#cache_key_data' do
    context 'when generating cache key data' do
      it 'returns hash of relevant data for cache key generation' do
        # Arrange
        query_options = described_class.new(
          team_id: 'team-123',
          start_date: '2024-01-01',
          end_date: '2024-01-31',
          page_size: 100,
          include_archived: true,
          format: 'json' # This should be excluded from cache key
        )

        # Act
        cache_data = query_options.cache_key_data

        # Assert
        aggregate_failures 'cache key data content' do
          expect(cache_data).to be_a(Hash)
          expect(cache_data).to include(
            team_id: 'team-123',
            start_date: '2024-01-01',
            end_date: '2024-01-31',
            page_size: 100,
            include_archived: true
          )
          expect(cache_data).not_to have_key(:format)
          expect(cache_data).not_to have_key('format')
        end
      end

      it 'excludes nil values from cache data' do
        # Arrange
        query_options = described_class.new(team_id: 'team-123')

        # Act
        cache_data = query_options.cache_key_data

        # Assert
        aggregate_failures 'nil value exclusion' do
          expect(cache_data).to include(team_id: 'team-123', include_archived: false)
          expect(cache_data).not_to have_key(:start_date)
          expect(cache_data).not_to have_key(:end_date)
          expect(cache_data.keys).not_to include(nil)
          expect(cache_data.values).not_to include(nil)
        end
      end

      it 'handles all nil values correctly' do
        # Arrange
        query_options = described_class.new

        # Act
        cache_data = query_options.cache_key_data

        # Assert
        aggregate_failures 'all nil values handling' do
          expect(cache_data).to be_a(Hash)
          expect(cache_data).not_to be_empty
          expect(cache_data).to include(include_archived: false)
          expect(cache_data.values).not_to include(nil)
        end
      end
    end
  end

  describe '#to_h' do
    context 'when converting to hash' do
      it 'returns all options as hash' do
        # Arrange
        options = {
          team_id: 'team-123',
          start_date: '2024-01-01',
          end_date: '2024-01-31',
          page_size: 100,
          include_archived: true
        }
        query_options = described_class.new(options)

        # Act
        result = query_options.to_h

        # Assert
        aggregate_failures 'hash conversion validation' do
          expect(result).to be_a(Hash)
          expect(result).to include(options)
          expect(result.keys).to all(be_a(Symbol))
        end
      end

      it 'includes default values in hash' do
        # Arrange
        query_options = described_class.new(team_id: 'team-123')

        # Act
        result = query_options.to_h

        # Assert
        aggregate_failures 'default values in hash' do
          expect(result).to include(team_id: 'team-123')
          expect(result).to include(page_size: 250)
          expect(result).to include(include_archived: false)
          expect(result).to have_key(:start_date)
          expect(result).to have_key(:end_date)
        end
      end

      it 'preserves option types in hash' do
        # Arrange
        options = {
          team_id: 'team-123',
          page_size: 100,
          include_archived: true
        }
        query_options = described_class.new(options)

        # Act
        result = query_options.to_h

        # Assert
        aggregate_failures 'type preservation' do
          expect(result[:team_id]).to be_a(String)
          expect(result[:page_size]).to be_a(Integer)
          expect(result[:include_archived]).to be_a(TrueClass).or be_a(FalseClass)
        end
      end
    end
  end
end
