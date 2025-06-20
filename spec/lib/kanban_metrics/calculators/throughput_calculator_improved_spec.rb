# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../../lib/kanban_metrics/calculators/throughput_calculator'

RSpec.describe KanbanMetrics::Calculators::ThroughputCalculator do
  # === TEST DATA SETUP ===
  subject(:stats) { calculator.stats }

  let(:completed_issues_same_week) do
    [
      {
        'id' => 'issue-1',
        'completedAt' => '2024-01-01T10:00:00Z', # Monday
        'title' => 'First issue'
      },
      {
        'id' => 'issue-2',
        'completedAt' => '2024-01-03T10:00:00Z', # Wednesday
        'title' => 'Second issue'
      },
      {
        'id' => 'issue-3',
        'completedAt' => '2024-01-05T10:00:00Z', # Friday
        'title' => 'Third issue'
      }
    ]
  end

  let(:completed_issues_multiple_weeks) do
    [
      # Week 1
      {
        'id' => 'issue-1',
        'completedAt' => '2024-01-01T10:00:00Z',
        'title' => 'Week 1 issue 1'
      },
      {
        'id' => 'issue-2',
        'completedAt' => '2024-01-03T10:00:00Z',
        'title' => 'Week 1 issue 2'
      },
      # Week 2
      {
        'id' => 'issue-3',
        'completedAt' => '2024-01-08T10:00:00Z',
        'title' => 'Week 2 issue 1'
      },
      {
        'id' => 'issue-4',
        'completedAt' => '2024-01-10T10:00:00Z',
        'title' => 'Week 2 issue 2'
      },
      {
        'id' => 'issue-5',
        'completedAt' => '2024-01-12T10:00:00Z',
        'title' => 'Week 2 issue 3'
      }
    ]
  end

  let(:empty_issues) { [] }

  # === NAMED SUBJECT ===
  let(:calculator) { described_class.new(completed_issues) }

  describe '#initialize' do
    context 'with completed issues' do
      # Setup
      let(:completed_issues) { completed_issues_same_week }

      it 'creates calculator instance' do
        expect(calculator).to be_a(described_class)
      end

      it 'stores the completed issues' do
        expect(calculator.instance_variable_get(:@completed_issues)).to eq(completed_issues)
      end
    end

    context 'with empty array' do
      # Setup
      let(:completed_issues) { empty_issues }

      it 'accepts empty array' do
        expect(calculator).to be_a(described_class)
      end
    end
  end

  describe '#stats' do
    context 'with empty completed issues' do
      # Setup
      let(:completed_issues) { empty_issues }

      it 'returns default stats structure', :aggregate_failures do
        # Verify structure and values
        expect(stats).to be_a(Hash)
        expect(stats).to have_key(:weekly_avg)
        expect(stats).to have_key(:total_completed)
        expect(stats[:weekly_avg]).to eq(0.0)
        expect(stats[:total_completed]).to eq(0)
      end
    end

    context 'with issues completed in the same week' do
      # Setup
      let(:completed_issues) { completed_issues_same_week }

      it 'calculates total completed correctly' do
        expect(stats[:total_completed]).to eq(3)
      end

      it 'calculates weekly average correctly' do
        # All issues in same week = 3 issues / 1 week = 3.0
        expect(stats[:weekly_avg]).to eq(3.0)
      end

      it 'rounds weekly average to 2 decimal places' do
        expect(stats[:weekly_avg]).to be_a(Float)
        expect(stats[:weekly_avg].round(2)).to eq(stats[:weekly_avg])
      end

      it 'returns throughput statistics with correct structure', :aggregate_failures do
        expect(stats).to be_a(Hash)
        expect(stats).to have_key(:weekly_avg)
        expect(stats).to have_key(:total_completed)
        expect(stats[:weekly_avg]).to be_a(Numeric)
        expect(stats[:total_completed]).to be_a(Integer)
      end
    end

    context 'with issues completed across multiple weeks' do
      # Setup
      let(:completed_issues) { completed_issues_multiple_weeks }

      it 'groups issues by week correctly' do
        # Week 1: 2 issues, Week 2: 3 issues
        # Average: (2 + 3) / 2 = 2.5
        expect(stats[:weekly_avg]).to eq(2.5)
      end

      it 'calculates total across all weeks' do
        expect(stats[:total_completed]).to eq(5)
      end

      it 'calculates average across weeks with proper rounding' do
        # Ensure proper decimal handling
        result = stats[:weekly_avg]
        expect(result).to be_a(Float)
        expect(result.to_s.split('.').last.length).to be <= 2
      end
    end
  end

  describe 'private methods' do
    # Setup
    let(:completed_issues) { completed_issues_multiple_weeks }

    describe '#calculate_average' do
      it 'calculates average of an array' do
        # Setup
        test_array = [1, 2, 3, 4, 5]

        # Execute
        result = calculator.send(:calculate_average, test_array)

        # Verify
        expect(result).to eq(3.0)
      end

      it 'returns 0 for empty array' do
        # Setup
        empty_array = []

        # Execute & Verify
        result = calculator.send(:calculate_average, empty_array)
        expect(result).to eq(0.0)
      end

      it 'rounds to 2 decimal places' do
        # Setup
        test_array = [1, 2] # Average should be 1.5

        # Execute
        result = calculator.send(:calculate_average, test_array)

        # Verify
        expect(result).to eq(1.5)
        expect(result.round(2)).to eq(result)
      end
    end

    describe '#group_by_week' do
      it 'groups issues by week string format' do
        # Execute
        grouped = calculator.send(:group_by_week)

        # Verify
        aggregate_failures 'week grouping' do
          expect(grouped).to be_a(Hash)
          expect(grouped.keys).to all(be_a(String))
          expect(grouped.keys).to all(match(/\d{4}-W\d{2}/)) # Format: YYYY-WNN
          expect(grouped.values).to all(be_an(Array))
        end
      end

      it 'groups issues correctly by week' do
        # Execute
        grouped = calculator.send(:group_by_week)

        # Verify
        expect(grouped.size).to eq(2) # Two different weeks
        week_sizes = grouped.values.map(&:size)
        expect(week_sizes).to contain_exactly(2, 3) # Week 1: 2 issues, Week 2: 3 issues
      end
    end

    describe '#calculate_weekly_counts' do
      it 'returns array of weekly counts' do
        # Execute
        weekly_counts = calculator.send(:calculate_weekly_counts)

        # Verify
        aggregate_failures 'weekly counts' do
          expect(weekly_counts).to be_an(Array)
          expect(weekly_counts).to all(be_a(Numeric))
          expect(weekly_counts.sum).to eq(completed_issues.size)
        end
      end

      it 'returns correct counts for each week' do
        # Execute
        weekly_counts = calculator.send(:calculate_weekly_counts)

        # Verify
        expect(weekly_counts).to contain_exactly(2, 3)
      end
    end
  end

  describe 'edge cases and error handling' do
    context 'with malformed completion dates' do
      # Setup
      let(:completed_issues) do
        [
          { 'id' => 'issue-1', 'completedAt' => 'invalid-date' },
          { 'id' => 'issue-2', 'completedAt' => nil },
          { 'id' => 'issue-3', 'completedAt' => '2024-01-01T10:00:00Z' }
        ]
      end

      it 'handles invalid dates gracefully' do
        # Execute & Verify - should not raise errors
        expect { stats }.not_to raise_error
        expect(stats).to be_a(Hash)
      end
    end

    context 'with very large datasets' do
      # Setup - simulate large dataset
      let(:completed_issues) do
        (1..1000).map do |i|
          {
            'id' => "issue-#{i}",
            'completedAt' => (Date.today - rand(365)).strftime('%Y-%m-%dT10:00:00Z')
          }
        end
      end

      it 'performs efficiently with large datasets' do
        # Execute with timing
        start_time = Time.now
        result = stats
        duration = Time.now - start_time

        # Verify performance and correctness
        aggregate_failures 'large dataset handling' do
          expect(duration).to be < 1.0 # Should complete within 1 second
          expect(result).to be_a(Hash)
          expect(result[:total_completed]).to eq(1000)
          expect(result[:weekly_avg]).to be_a(Float)
        end
      end
    end
  end
end
