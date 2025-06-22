# frozen_string_literal: true

require 'spec_helper'

RSpec.describe KanbanMetrics::Calculators::ThroughputCalculator do
  # Test Data Setup
  subject(:calculator) { described_class.new(issues) }

  let(:completed_issues) do
    [
      { 'id' => 'issue-1', 'completedAt' => '2024-01-01T10:00:00Z' },
      { 'id' => 'issue-2', 'completedAt' => '2024-01-02T14:30:00Z' },
      { 'id' => 'issue-3', 'completedAt' => '2024-01-08T09:15:00Z' },
      { 'id' => 'issue-4', 'completedAt' => '2024-01-10T16:45:00Z' },
      { 'id' => 'issue-5', 'completedAt' => '2024-01-15T11:20:00Z' }
    ]
  end

  let(:empty_issues) { [] }

  describe '#initialize' do
    context 'with completed issues' do
      # Setup
      let(:issues) { completed_issues }

      it 'creates calculator instance with issues' do
        # Execute & Verify
        expect(calculator).to be_a(described_class)
      end
    end

    context 'with empty issues' do
      # Setup
      let(:issues) { empty_issues }

      it 'creates calculator instance with empty array' do
        # Execute & Verify
        expect(calculator).to be_a(described_class)
      end
    end
  end

  describe '#stats' do
    subject(:stats) { calculator.stats }

    context 'with empty completed issues' do
      # Setup
      let(:issues) { empty_issues }

      it 'returns default stats for empty issues' do
        # Execute
        result = stats

        # Verify
        expect(result).to eq({
                               weekly_avg: 0,
                               total_completed: 0
                             })
      end
    end

    context 'with completed issues' do
      # Setup
      let(:issues) { completed_issues }

      it 'returns throughput statistics structure' do
        # Execute
        result = stats

        # Verify
        aggregate_failures 'stats structure' do
          expect(result).to be_a(Hash)
          expect(result).to have_key(:weekly_avg)
          expect(result).to have_key(:total_completed)
          expect(result[:total_completed]).to eq(5)
          expect(result[:weekly_avg]).to be_a(Float)
          expect(result[:weekly_avg]).to be > 0
        end
      end

      it 'calculates total completed correctly' do
        # Execute
        result = stats

        # Verify
        expect(result[:total_completed]).to eq(completed_issues.size)
      end

      it 'rounds weekly average to 2 decimal places' do
        # Execute
        result = stats

        # Verify
        expect(result[:weekly_avg].to_s.split('.').last.length).to be <= 2
      end
    end

    context 'with issues completed in the same week' do
      # Setup
      let(:issues) do
        [
          { 'id' => 'issue-1', 'completedAt' => '2024-01-01T10:00:00Z' },
          { 'id' => 'issue-2', 'completedAt' => '2024-01-02T14:30:00Z' },
          { 'id' => 'issue-3', 'completedAt' => '2024-01-03T09:15:00Z' }
        ]
      end

      it 'groups issues by week correctly' do
        # Execute
        result = stats

        # Verify
        aggregate_failures 'same week grouping' do
          expect(result[:total_completed]).to eq(3)
          expect(result[:weekly_avg]).to eq(3.0)
        end
      end
    end

    context 'with issues completed across multiple weeks' do
      # Setup
      let(:issues) do
        [
          { 'id' => 'issue-1', 'completedAt' => '2024-01-01T10:00:00Z' }, # Week 1
          { 'id' => 'issue-2', 'completedAt' => '2024-01-08T14:30:00Z' }, # Week 2
          { 'id' => 'issue-3', 'completedAt' => '2024-01-15T09:15:00Z' }, # Week 3
          { 'id' => 'issue-4', 'completedAt' => '2024-01-16T09:15:00Z' }  # Week 3
        ]
      end

      it 'calculates average across multiple weeks' do
        # Execute
        result = stats

        # Verify
        aggregate_failures 'multi-week average' do
          expect(result[:total_completed]).to eq(4)
          # Should have 3 weeks: 1 issue, 1 issue, 2 issues = average of 1.33
          expect(result[:weekly_avg]).to be_within(0.01).of(1.33)
        end
      end
    end
  end

  describe 'private methods' do
    # Setup
    let(:issues) { completed_issues }

    describe '#group_by_week' do
      subject(:group_by_week) { calculator.send(:group_by_week) }

      it 'groups issues by week string format' do
        # Execute
        result = group_by_week

        # Verify
        aggregate_failures 'week grouping format' do
          expect(result).to be_a(Hash)
          expect(result.keys).to all(match(/\A\d{4}-W\d{2}\z/))
        end
      end
    end

    describe '#calculate_weekly_counts' do
      subject(:calculate_weekly_counts) { calculator.send(:calculate_weekly_counts) }

      it 'returns array of weekly counts' do
        # Execute
        result = calculate_weekly_counts

        # Verify
        aggregate_failures 'weekly counts structure' do
          expect(result).to be_an(Array)
          expect(result).to all(be_a(Integer))
          expect(result.sum).to eq(completed_issues.size)
        end
      end
    end

    describe '#calculate_average' do
      subject(:calculate_average) { calculator.send(:calculate_average, input_array) }

      context 'with numeric array' do
        # Setup
        let(:input_array) { [1, 2, 3, 4, 5] }

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
        let(:input_array) { [1, 2] }

        it 'rounds to 2 decimal places' do
          # Execute
          result = calculate_average

          # Verify
          aggregate_failures 'decimal precision' do
            expect(result).to eq(1.5)
            expect(result.to_s.split('.').last.length).to be <= 2
          end
        end
      end
    end
  end
end
