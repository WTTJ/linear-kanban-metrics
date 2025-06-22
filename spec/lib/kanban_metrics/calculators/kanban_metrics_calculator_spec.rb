# frozen_string_literal: true

require 'spec_helper'

RSpec.describe KanbanMetrics::Calculators::KanbanMetricsCalculator do
  # Test Data Setup
  let(:completed_issue_1) do
    {
      'id' => 'issue-1',
      'title' => 'Completed Issue 1',
      'state' => { 'type' => 'completed' },
      'completedAt' => '2024-01-05T10:00:00Z',
      'createdAt' => '2024-01-01T10:00:00Z',
      'startedAt' => '2024-01-02T10:00:00Z',
      'team' => { 'name' => 'Backend Team' }
    }
  end

  let(:in_progress_issue) do
    {
      'id' => 'issue-2',
      'title' => 'In Progress Issue',
      'state' => { 'type' => 'started' },
      'createdAt' => '2024-01-03T10:00:00Z',
      'startedAt' => '2024-01-04T10:00:00Z',
      'team' => { 'name' => 'Frontend Team' }
    }
  end

  let(:backlog_issue) do
    {
      'id' => 'issue-3',
      'title' => 'Backlog Issue',
      'state' => { 'type' => 'backlog' },
      'createdAt' => '2024-01-02T10:00:00Z',
      'team' => { 'name' => 'Backend Team' }
    }
  end

  let(:completed_issue_2) do
    {
      'id' => 'issue-4',
      'title' => 'Another Completed Issue',
      'state' => { 'type' => 'completed' },
      'completedAt' => '2024-01-07T10:00:00Z',
      'createdAt' => '2024-01-01T10:00:00Z',
      'startedAt' => '2024-01-03T10:00:00Z',
      'team' => { 'name' => 'Frontend Team' }
    }
  end

  let(:sample_issues) { [completed_issue_1, in_progress_issue, backlog_issue, completed_issue_2] }
  let(:empty_issues) { [] }

  describe '#initialize' do
    subject(:calculator) { described_class.new(issues) }

    context 'with sample issues' do
      # Setup
      let(:issues) { sample_issues }

      it 'creates a calculator instance' do
        # Execute & Verify
        expect(calculator).to be_a(described_class)
      end
    end

    context 'with empty issues' do
      # Setup
      let(:issues) { empty_issues }

      it 'creates a calculator instance for empty array' do
        # Execute & Verify
        expect(calculator).to be_a(described_class)
      end
    end
  end

  describe '#overall_metrics' do
    subject(:overall_metrics) { calculator.overall_metrics }

    context 'with sample issues' do
      # Setup
      let(:calculator) { described_class.new(sample_issues) }

      it 'returns a hash with all required metrics' do
        # Execute & Verify
        aggregate_failures 'overall metrics structure' do
          expect(overall_metrics).to be_a(Hash)
          expect(overall_metrics).to have_key(:total_issues)
          expect(overall_metrics).to have_key(:completed_issues)
          expect(overall_metrics).to have_key(:in_progress_issues)
          expect(overall_metrics).to have_key(:backlog_issues)
          expect(overall_metrics).to have_key(:cycle_time)
          expect(overall_metrics).to have_key(:lead_time)
          expect(overall_metrics).to have_key(:throughput)
          expect(overall_metrics).to have_key(:flow_efficiency)
        end
      end

      it 'calculates issue counts correctly' do
        # Execute & Verify
        aggregate_failures 'issue counts' do
          expect(overall_metrics[:total_issues]).to eq(4)
          expect(overall_metrics[:completed_issues]).to eq(2)
          expect(overall_metrics[:in_progress_issues]).to eq(1)
          expect(overall_metrics[:backlog_issues]).to eq(1)
        end
      end

      it 'includes time-based metrics with proper structure' do
        # Execute & Verify
        aggregate_failures 'time metrics structure' do
          expect(overall_metrics[:cycle_time]).to be_a(Hash)
          expect(overall_metrics[:cycle_time]).to have_key(:average)
          expect(overall_metrics[:cycle_time]).to have_key(:median)
          expect(overall_metrics[:cycle_time]).to have_key(:p95)

          expect(overall_metrics[:lead_time]).to be_a(Hash)
          expect(overall_metrics[:lead_time]).to have_key(:average)
          expect(overall_metrics[:lead_time]).to have_key(:median)
          expect(overall_metrics[:lead_time]).to have_key(:p95)
        end
      end

      it 'includes throughput metrics with proper structure' do
        # Execute & Verify
        aggregate_failures 'throughput metrics' do
          expect(overall_metrics[:throughput]).to be_a(Hash)
          expect(overall_metrics[:throughput]).to have_key(:weekly_avg)
          expect(overall_metrics[:throughput]).to have_key(:total_completed)
          expect(overall_metrics[:throughput][:total_completed]).to eq(2)
        end
      end

      it 'includes flow efficiency within valid range' do
        # Execute & Verify
        aggregate_failures 'flow efficiency' do
          expect(overall_metrics[:flow_efficiency]).to be_a(Float)
          expect(overall_metrics[:flow_efficiency]).to be >= 0
          expect(overall_metrics[:flow_efficiency]).to be <= 100
        end
      end
    end

    context 'with empty issues' do
      # Setup
      let(:calculator) { described_class.new(empty_issues) }

      it 'returns zero metrics for empty issues' do
        # Execute & Verify
        aggregate_failures 'empty issues metrics' do
          expect(overall_metrics[:total_issues]).to eq(0)
          expect(overall_metrics[:completed_issues]).to eq(0)
          expect(overall_metrics[:in_progress_issues]).to eq(0)
          expect(overall_metrics[:backlog_issues]).to eq(0)
          expect(overall_metrics[:flow_efficiency]).to eq(0)
        end
      end
    end
  end

  describe '#team_metrics' do
    subject(:team_metrics) { calculator.team_metrics }

    context 'with sample issues' do
      # Setup
      let(:calculator) { described_class.new(sample_issues) }

      it 'returns metrics grouped by team' do
        # Execute & Verify
        aggregate_failures 'team grouping' do
          expect(team_metrics).to be_a(Hash)
          expect(team_metrics).to have_key('Backend Team')
          expect(team_metrics).to have_key('Frontend Team')
        end
      end

      it 'calculates correct metrics for Backend Team' do
        # Setup
        backend_metrics = team_metrics['Backend Team']

        # Execute & Verify
        aggregate_failures 'backend team metrics' do
          expect(backend_metrics[:total_issues]).to eq(2)
          expect(backend_metrics[:completed_issues]).to eq(1)
          expect(backend_metrics[:backlog_issues]).to eq(1)
        end
      end

      it 'calculates correct metrics for Frontend Team' do
        # Setup
        frontend_metrics = team_metrics['Frontend Team']

        # Execute & Verify
        aggregate_failures 'frontend team metrics' do
          expect(frontend_metrics[:total_issues]).to eq(2)
          expect(frontend_metrics[:completed_issues]).to eq(1)
          expect(frontend_metrics[:in_progress_issues]).to eq(1)
        end
      end

      it 'includes time metrics for each team' do
        # Execute & Verify
        team_metrics.each_value do |metrics|
          aggregate_failures 'team time metrics' do
            expect(metrics).to have_key(:cycle_time)
            expect(metrics).to have_key(:lead_time)
            expect(metrics[:cycle_time]).to be_a(Hash)
            expect(metrics[:lead_time]).to be_a(Hash)
          end
        end
      end

      it 'includes throughput count for each team' do
        # Execute & Verify
        team_metrics.each_value do |metrics|
          aggregate_failures 'team throughput' do
            expect(metrics).to have_key(:throughput)
            expect(metrics[:throughput]).to be_a(Integer)
            expect(metrics[:throughput]).to be >= 0
          end
        end
      end
    end

    context 'with issues without team information' do
      # Setup
      let(:issues_without_teams) do
        [
          {
            'id' => 'issue-1',
            'state' => { 'type' => 'completed' },
            'completedAt' => '2024-01-05T10:00:00Z'
          }
        ]
      end
      let(:calculator) { described_class.new(issues_without_teams) }

      it 'groups issues without team as "Unknown Team"' do
        # Execute & Verify
        aggregate_failures 'unknown team handling' do
          expect(team_metrics).to have_key('Unknown Team')
          expect(team_metrics['Unknown Team'][:total_issues]).to eq(1)
        end
      end
    end

    context 'with empty issues' do
      # Setup
      let(:calculator) { described_class.new(empty_issues) }

      it 'returns empty hash for empty issues' do
        # Execute & Verify
        aggregate_failures 'empty team metrics' do
          expect(team_metrics).to be_a(Hash)
          expect(team_metrics).to be_empty
        end
      end
    end
  end

  describe 'integration with other calculators' do
    subject(:overall_metrics) { calculator.overall_metrics }

    # Setup
    let(:calculator) { described_class.new(sample_issues) }

    it 'integrates with IssuePartitioner' do
      # Setup - expect Domain::Issue objects to be passed to partition
      expect(KanbanMetrics::Calculators::IssuePartitioner).to receive(:partition) do |issues|
        expect(issues).to all(be_a(KanbanMetrics::Domain::Issue))
        # Return mock data for the test
        [[], [], []]
      end

      # Execute & Verify
      overall_metrics
    end

    it 'integrates with TimeMetricsCalculator' do
      # Setup - expect Domain::Issue objects to be passed to TimeMetricsCalculator
      expect(KanbanMetrics::Calculators::TimeMetricsCalculator).to receive(:new) do |completed_issues|
        expect(completed_issues).to all(be_a(KanbanMetrics::Domain::Issue))
        double('time_calculator', cycle_time_stats: {}, lead_time_stats: {})
      end

      # Execute & Verify
      overall_metrics
    end

    it 'integrates with ThroughputCalculator' do
      # Setup - expect Domain::Issue objects to be passed to ThroughputCalculator
      expect(KanbanMetrics::Calculators::ThroughputCalculator).to receive(:new) do |completed_issues|
        expect(completed_issues).to all(be_a(KanbanMetrics::Domain::Issue))
        double('throughput_calculator', stats: { total_completed: 0 })
      end

      # Execute & Verify
      overall_metrics
    end

    it 'integrates with FlowEfficiencyCalculator' do
      # Setup - expect Domain::Issue objects to be passed to FlowEfficiencyCalculator
      expect(KanbanMetrics::Calculators::FlowEfficiencyCalculator).to receive(:new) do |completed_issues|
        expect(completed_issues).to all(be_a(KanbanMetrics::Domain::Issue))
        double('flow_efficiency_calculator', calculate: 0.0)
      end

      # Execute & Verify
      overall_metrics
    end
  end
end
