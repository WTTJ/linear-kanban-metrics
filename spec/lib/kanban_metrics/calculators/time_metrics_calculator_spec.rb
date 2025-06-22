# frozen_string_literal: true

require 'spec_helper'

RSpec.describe KanbanMetrics::Calculators::TimeMetricsCalculator do
  # === CLASS METHODS ===
  # === INSTANCE METHODS ===
  # Test Data Setup
  subject(:calculator) { described_class.new(issues) }

  let(:empty_issues) { [] }
  let(:incomplete_issues) do
    [
      { 'id' => 'issue-4', 'createdAt' => '2024-01-01T10:00:00Z' },
      { 'id' => 'issue-5', 'startedAt' => '2024-01-01T10:00:00Z' }
    ]
  end
  let(:issues_with_times) do
    [
      {
        'id' => 'issue-1',
        'createdAt' => '2024-01-01T10:00:00Z',
        'startedAt' => '2024-01-02T10:00:00Z',
        'completedAt' => '2024-01-05T10:00:00Z'
      },
      {
        'id' => 'issue-2',
        'createdAt' => '2024-01-01T10:00:00Z',
        'completedAt' => '2024-01-03T10:00:00Z',
        'history' => {
          'nodes' => [
            {
              'createdAt' => '2024-01-01T14:00:00Z',
              'toState' => { 'type' => 'started' }
            }
          ]
        }
      },
      {
        'id' => 'issue-3',
        'createdAt' => '2024-01-01T10:00:00Z',
        'startedAt' => '2024-01-01T12:00:00Z',
        'completedAt' => '2024-01-02T10:00:00Z'
      }
    ]
  end

  describe '.cycle_time_stats' do
    it 'calculates cycle time statistics directly' do
      issues = [
        {
          'id' => 'issue-1',
          'startedAt' => '2024-01-01T10:00:00Z',
          'completedAt' => '2024-01-03T10:00:00Z'
        },
        {
          'id' => 'issue-2',
          'startedAt' => '2024-01-01T10:00:00Z',
          'completedAt' => '2024-01-05T10:00:00Z'
        }
      ]

      result = described_class.cycle_time_stats(issues)

      expect(result).to include(
        average: be_a(Float),
        median: be_a(Float),
        p95: be_a(Float)
      )
    end
  end

  describe '.lead_time_stats' do
    it 'calculates lead time statistics directly' do
      issues = [
        {
          'id' => 'issue-1',
          'createdAt' => '2024-01-01T10:00:00Z',
          'completedAt' => '2024-01-03T10:00:00Z'
        },
        {
          'id' => 'issue-2',
          'createdAt' => '2024-01-01T10:00:00Z',
          'completedAt' => '2024-01-05T10:00:00Z'
        }
      ]

      result = described_class.lead_time_stats(issues)

      expect(result).to include(
        average: be_a(Float),
        median: be_a(Float),
        p95: be_a(Float)
      )
    end
  end

  describe '#initialize' do
    # Setup
    let(:issues) { issues_with_times }

    it 'creates calculator instance with issues' do
      # Execute & Verify
      expect(calculator).to be_a(described_class)
    end
  end

  describe '#cycle_time_stats' do
    subject(:cycle_time_stats) { calculator.cycle_time_stats }

    context 'with issues having complete cycle time data' do
      # Setup
      let(:issues) { issues_with_times }

      it 'returns cycle time statistics structure' do
        # Execute
        result = cycle_time_stats

        # Verify
        aggregate_failures 'cycle time stats structure' do
          expect(result).to be_a(Hash)
          expect(result).to have_key(:average)
          expect(result).to have_key(:median)
          expect(result).to have_key(:p95)
          expect(result[:average]).to be_a(Float)
          expect(result[:median]).to be_a(Float)
          expect(result[:p95]).to be_a(Float)
        end
      end

      it 'calculates meaningful cycle times' do
        # Execute
        result = cycle_time_stats

        # Verify
        aggregate_failures 'meaningful cycle time values' do
          expect(result[:average]).to be > 0
          expect(result[:median]).to be > 0
          expect(result[:p95]).to be > 0
        end
      end
    end

    context 'with empty issues' do
      # Setup
      let(:issues) { empty_issues }

      it 'returns zero stats for empty issues' do
        # Execute
        result = cycle_time_stats

        # Verify
        aggregate_failures 'empty cycle time stats' do
          expect(result[:average]).to eq(0)
          expect(result[:median]).to eq(0)
          expect(result[:p95]).to eq(0)
        end
      end
    end

    context 'with incomplete issues' do
      # Setup
      let(:issues) { incomplete_issues }

      it 'filters out issues without required data' do
        # Execute
        result = cycle_time_stats

        # Verify
        aggregate_failures 'incomplete issues filtered' do
          expect(result[:average]).to eq(0)
          expect(result[:median]).to eq(0)
          expect(result[:p95]).to eq(0)
        end
      end
    end
  end

  describe '#lead_time_stats' do
    subject(:lead_time_stats) { calculator.lead_time_stats }

    context 'with issues having complete lead time data' do
      # Setup
      let(:issues) { issues_with_times }

      it 'returns lead time statistics structure' do
        # Execute
        result = lead_time_stats

        # Verify
        aggregate_failures 'lead time stats structure' do
          expect(result).to be_a(Hash)
          expect(result).to have_key(:average)
          expect(result).to have_key(:median)
          expect(result).to have_key(:p95)
          expect(result[:average]).to be_a(Float)
          expect(result[:median]).to be_a(Float)
          expect(result[:p95]).to be_a(Float)
        end
      end

      it 'calculates meaningful lead times' do
        # Execute
        result = lead_time_stats

        # Verify
        aggregate_failures 'meaningful lead time values' do
          expect(result[:average]).to be > 0
          expect(result[:median]).to be > 0
          expect(result[:p95]).to be > 0
        end
      end
    end

    context 'with empty issues' do
      # Setup
      let(:issues) { empty_issues }

      it 'returns zero stats for empty issues' do
        # Execute
        result = lead_time_stats

        # Verify
        aggregate_failures 'empty lead time stats' do
          expect(result[:average]).to eq(0)
          expect(result[:median]).to eq(0)
          expect(result[:p95]).to eq(0)
        end
      end
    end
  end

  describe 'private methods' do
    # Setup
    let(:issues) { issues_with_times }

    describe '#calculate_average' do
      subject(:calculate_average) { calculator.send(:calculate_average, input_array) }

      context 'with numeric array' do
        # Setup
        let(:input_array) { [1.0, 2.0, 3.0, 4.0, 5.0] }

        it 'calculates correct average' do
          # Execute
          result = calculate_average

          # Verify
          expect(result).to eq(3.0)
        end
      end

      context 'with empty array' do
        # Setup
        let(:input_array) { [] }

        it 'returns zero for empty array' do
          # Execute
          result = calculate_average

          # Verify
          expect(result).to eq(0)
        end
      end

      context 'with decimal result' do
        # Setup
        let(:input_array) { [1.0, 2.0] }

        it 'rounds to 2 decimal places' do
          # Execute
          result = calculate_average

          # Verify
          expect(result.to_s.split('.').last.length).to be <= 2
        end
      end
    end

    describe '#calculate_median' do
      subject(:calculate_median) { calculator.send(:calculate_median, input_array) }

      context 'with odd-sized array' do
        # Setup
        let(:input_array) { [1.0, 2.0, 3.0, 4.0, 5.0] }

        it 'calculates median for odd array' do
          # Execute
          result = calculate_median

          # Verify
          expect(result).to eq(3.0)
        end
      end

      context 'with even-sized array' do
        # Setup
        let(:input_array) { [1.0, 2.0, 3.0, 4.0] }

        it 'calculates median for even array' do
          # Execute
          result = calculate_median

          # Verify
          expect(result).to eq(2.5)
        end
      end

      context 'with empty array' do
        # Setup
        let(:input_array) { [] }

        it 'returns zero for empty array' do
          # Execute
          result = calculate_median

          # Verify
          expect(result).to eq(0)
        end
      end

      context 'with decimal precision' do
        # Setup
        let(:input_array) { [1.0, 2.0, 3.0] }

        it 'rounds to 2 decimal places' do
          # Execute
          result = calculate_median

          # Verify
          expect(result.to_s.split('.').last.length).to be <= 2
        end
      end
    end

    describe '#calculate_percentile' do
      subject(:calculate_percentile) { calculator.send(:calculate_percentile, input_array, percentile) }

      context 'with large array' do
        # Setup
        let(:input_array) { (1..100).map(&:to_f) }
        let(:percentile) { 95 }

        it 'calculates 95th percentile correctly' do
          # Execute
          result = calculate_percentile

          # Verify
          expect(result).to be_within(5).of(95)
        end
      end

      context 'with empty array' do
        # Setup
        let(:input_array) { [] }
        let(:percentile) { 95 }

        it 'returns zero for empty array' do
          # Execute
          result = calculate_percentile

          # Verify
          expect(result).to eq(0)
        end
      end

      context 'with single element' do
        # Setup
        let(:input_array) { [5.0] }
        let(:percentile) { 95 }

        it 'handles single element array' do
          # Execute
          result = calculate_percentile

          # Verify
          expect(result).to eq(5.0)
        end
      end
    end
  end
end
