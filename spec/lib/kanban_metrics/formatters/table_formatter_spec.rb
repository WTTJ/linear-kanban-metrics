# frozen_string_literal: true

require 'spec_helper'

RSpec.describe KanbanMetrics::Formatters::TableFormatter do
  # Test Data Setup
  subject(:formatter) { described_class.new(metrics_param, team_metrics_param, issues_param) }

  let(:metrics) do
    {
      total_issues: 100,
      completed_issues: 60,
      in_progress_issues: 25,
      backlog_issues: 15,
      cycle_time: {
        average: 8.5,
        median: 6.0,
        p95: 18.2
      },
      lead_time: {
        average: 12.3,
        median: 9.1,
        p95: 25.7
      },
      throughput: {
        weekly_avg: 15.2,
        total_completed: 60
      },
      flow_efficiency: 65.5
    }
  end

  let(:team_metrics) do
    {
      'Backend Team' => {
        total_issues: 60,
        completed_issues: 40,
        in_progress_issues: 15,
        backlog_issues: 5,
        cycle_time: { average: 7.2, median: 5.5 },
        lead_time: { average: 10.8, median: 8.2 },
        throughput: 40
      },
      'Frontend Team' => {
        total_issues: 40,
        completed_issues: 20,
        in_progress_issues: 10,
        backlog_issues: 10,
        cycle_time: { average: 10.1, median: 7.8 },
        lead_time: { average: 14.5, median: 11.2 },
        throughput: 20
      }
    }
  end

  let(:sample_issues) do
    [
      {
        'identifier' => 'PROJ-123',
        'title' => 'Implement user authentication system',
        'state' => { 'name' => 'Done' },
        'createdAt' => '2024-01-01T10:00:00Z',
        'startedAt' => '2024-01-02T14:00:00Z',
        'completedAt' => '2024-01-05T16:00:00Z',
        'team' => { 'name' => 'Backend Team' }
      },
      {
        'identifier' => 'PROJ-124',
        'title' => 'Fix login page styling and layout issues',
        'state' => { 'name' => 'In Progress' },
        'createdAt' => '2024-01-03T09:00:00Z',
        'startedAt' => '2024-01-04T11:00:00Z',
        'completedAt' => nil,
        'team' => { 'name' => 'Frontend Team' }
      }
    ]
  end

  describe '.print_all' do
    subject(:print_all) { described_class.print_all(metrics, team_metrics: team_metrics, issues: sample_issues) }

    it 'prints all sections without errors' do
      # Execute & Verify
      expect { print_all }.not_to raise_error
    end

    it 'includes summary, cycle time, lead time, throughput, team metrics, individual tickets, and KPI definitions' do
      # Execute
      output = capture_stdout { print_all }

      # Verify
      aggregate_failures 'all sections content' do
        expect(output).to include('📈 SUMMARY')
        expect(output).to include('⏱️  CYCLE TIME')
        expect(output).to include('📏 LEAD TIME')
        expect(output).to include('🚀 THROUGHPUT')
        expect(output).to include('👥 TEAM METRICS')
        expect(output).to include('🎫 INDIVIDUAL TICKET DETAILS')
        expect(output).to include('📚 KPI DEFINITIONS')
      end
    end

    context 'without team metrics' do
      subject(:print_all) { described_class.print_all(metrics, team_metrics: nil, issues: sample_issues) }

      it 'skips team metrics section' do
        # Execute
        output = capture_stdout { print_all }

        # Verify
        expect(output).not_to include('👥 TEAM METRICS')
      end
    end

    context 'without issues' do
      subject(:print_all) { described_class.print_all(metrics, team_metrics: team_metrics, issues: nil) }

      it 'skips individual tickets section' do
        # Execute
        output = capture_stdout { print_all }

        # Verify
        expect(output).not_to include('🎫 INDIVIDUAL TICKET DETAILS')
      end
    end
  end

  describe '#initialize' do
    context 'with metrics only' do
      # Setup
      let(:metrics_param) { metrics }
      let(:team_metrics_param) { nil }
      let(:issues_param) { nil }

      it 'creates formatter instance with metrics only' do
        # Execute & Verify
        expect(formatter).to be_a(described_class)
      end
    end

    context 'with metrics and team_metrics' do
      # Setup
      let(:metrics_param) { metrics }
      let(:team_metrics_param) { team_metrics }
      let(:issues_param) { nil }

      it 'creates formatter instance with team metrics' do
        # Execute & Verify
        expect(formatter).to be_a(described_class)
      end
    end
  end

  describe 'constants' do
    it 'defines KPI descriptions structure' do
      # Execute & Verify
      aggregate_failures 'KPI descriptions structure' do
        expect(described_class::KPI_DESCRIPTIONS).to be_a(Hash)
        expect(described_class::KPI_DESCRIPTIONS).to have_key(:total_issues)
        expect(described_class::KPI_DESCRIPTIONS).to have_key(:flow_efficiency)
        expect(described_class::KPI_DESCRIPTIONS).to have_key(:average_cycle_time)
      end
    end

    it 'has meaningful descriptions for all KPIs' do
      # Execute & Verify
      described_class::KPI_DESCRIPTIONS.each_value do |description|
        aggregate_failures 'description content' do
          expect(description).to be_a(String)
          expect(description).not_to be_empty
        end
      end
    end
  end

  describe '#print_summary' do
    subject(:print_summary) { formatter.print_summary }

    # Setup
    let(:metrics_param) { metrics }
    let(:team_metrics_param) { nil }
    let(:issues_param) { nil }

    it 'prints summary without errors' do
      # Execute & Verify
      expect { print_summary }.not_to raise_error
    end

    it 'outputs the summary section header' do
      # Execute & Verify
      expect { print_summary }.to output(/📈 SUMMARY/).to_stdout
    end

    it 'includes all summary metrics' do
      # Execute
      output = capture_stdout { print_summary }

      # Verify
      aggregate_failures 'summary metrics content' do
        expect(output).to include('Total Issues')
        expect(output).to include('Completed Issues')
        expect(output).to include('In Progress Issues')
        expect(output).to include('Backlog Issues')
        expect(output).to include('Flow Efficiency')
        expect(output).to include('100')
        expect(output).to include('60')
        expect(output).to include('25')
        expect(output).to include('15')
        expect(output).to include('65.5%')
      end
    end
  end

  describe '#print_cycle_time' do
    subject(:print_cycle_time) { formatter.print_cycle_time }

    # Setup
    let(:metrics_param) { metrics }
    let(:team_metrics_param) { nil }
    let(:issues_param) { nil }

    it 'prints cycle time without errors' do
      # Execute & Verify
      expect { print_cycle_time }.not_to raise_error
    end

    it 'outputs the cycle time section header' do
      # Execute & Verify
      expect { print_cycle_time }.to output(/⏱️  CYCLE TIME/).to_stdout
    end

    it 'includes cycle time metrics' do
      # Execute
      output = capture_stdout { print_cycle_time }

      # Verify
      aggregate_failures 'cycle time metrics content' do
        expect(output).to include('Average Cycle Time')
        expect(output).to include('Median Cycle Time')
        expect(output).to include('95th Percentile')
        expect(output).to include('8.5')
        expect(output).to include('6.0')
        expect(output).to include('18.2')
      end
    end
  end

  describe '#print_lead_time' do
    subject(:print_lead_time) { formatter.print_lead_time }

    # Setup
    let(:metrics_param) { metrics }
    let(:team_metrics_param) { nil }
    let(:issues_param) { nil }

    it 'prints lead time without errors' do
      # Execute & Verify
      expect { print_lead_time }.not_to raise_error
    end

    it 'outputs the lead time section header' do
      # Execute & Verify
      expect { print_lead_time }.to output(/📏 LEAD TIME/).to_stdout
    end

    it 'includes lead time metrics' do
      # Execute
      output = capture_stdout { print_lead_time }

      # Verify
      aggregate_failures 'lead time metrics content' do
        expect(output).to include('Average Lead Time')
        expect(output).to include('Median Lead Time')
        expect(output).to include('95th Percentile')
        expect(output).to include('12.3')
        expect(output).to include('9.1')
        expect(output).to include('25.7')
      end
    end
  end

  describe '#print_throughput' do
    subject(:print_throughput) { formatter.print_throughput }

    # Setup
    let(:metrics_param) { metrics }
    let(:team_metrics_param) { nil }
    let(:issues_param) { nil }

    it 'prints throughput without errors' do
      # Execute & Verify
      expect { print_throughput }.not_to raise_error
    end

    it 'outputs the throughput section header' do
      # Execute & Verify
      expect { print_throughput }.to output(/🚀 THROUGHPUT/).to_stdout
    end

    it 'includes throughput metrics' do
      # Execute
      output = capture_stdout { print_throughput }

      # Verify
      aggregate_failures 'throughput metrics content' do
        expect(output).to include('15.2')
        expect(output).to include('60')
      end
    end
  end

  describe '#print_team_metrics' do
    subject(:print_team_metrics) { formatter.print_team_metrics }

    context 'with team metrics available' do
      # Setup
      let(:metrics_param) { metrics }
      let(:team_metrics_param) { team_metrics }
      let(:issues_param) { nil }

      it 'prints team metrics without errors' do
        # Execute & Verify
        expect { print_team_metrics }.not_to raise_error
      end

      it 'includes team names' do
        # Execute
        output = capture_stdout { print_team_metrics }

        # Verify
        aggregate_failures 'team names content' do
          expect(output).to include('Backend Team')
          expect(output).to include('Frontend Team')
        end
      end
    end

    context 'without team metrics' do
      # Setup
      let(:metrics_param) { metrics }
      let(:team_metrics_param) { nil }
      let(:issues_param) { nil }

      it 'does not print anything when team metrics not available' do
        # Execute
        output = capture_stdout { print_team_metrics }

        # Verify
        expect(output).to be_empty
      end
    end
  end

  describe '#print_kpi_definitions' do
    subject(:print_kpi_definitions) { formatter.print_kpi_definitions }

    # Setup
    let(:metrics_param) { metrics }
    let(:team_metrics_param) { nil }
    let(:issues_param) { nil }

    it 'prints KPI definitions without errors' do
      # Execute & Verify
      expect { print_kpi_definitions }.not_to raise_error
    end

    it 'outputs the definitions section header' do
      # Execute & Verify
      expect { print_kpi_definitions }.to output(/📚 KPI DEFINITIONS/).to_stdout
    end

    it 'includes KPI descriptions' do
      # Execute
      output = capture_stdout { print_kpi_definitions }

      # Verify
      aggregate_failures 'KPI definitions content' do
        expect(output).to include('Cycle Time')
        expect(output).to include('Lead Time')
        expect(output).to include('Flow Efficiency')
        expect(output).to include('How efficient your team is at executing work')
        expect(output).to include('How much waste exists in your process')
      end
    end
  end

  describe '#print_individual_tickets' do
    subject(:print_individual_tickets) { formatter.print_individual_tickets }

    context 'with issues available' do
      # Setup
      let(:metrics_param) { metrics }
      let(:team_metrics_param) { nil }
      let(:issues_param) { sample_issues }

      it 'prints individual tickets without errors' do
        # Execute & Verify
        expect { print_individual_tickets }.not_to raise_error
      end

      it 'outputs the individual tickets section header' do
        # Execute & Verify
        expect { print_individual_tickets }.to output(/🎫 INDIVIDUAL TICKET DETAILS/).to_stdout
      end

      it 'includes ticket information' do
        # Execute
        output = capture_stdout { print_individual_tickets }

        # Verify
        aggregate_failures 'individual tickets content' do
          expect(output).to include('PROJ-123')
          expect(output).to include('PROJ-124')
          expect(output).to include('Implement user authenticati') # Truncated title
          expect(output).to include('Backend Team')
          expect(output).to include('Frontend Team')
          expect(output).to include('Done')
          expect(output).to include('In Progress')
        end
      end
    end

    context 'without issues' do
      # Setup
      let(:metrics_param) { metrics }
      let(:team_metrics_param) { nil }
      let(:issues_param) { nil }

      it 'does not print anything when no issues available' do
        # Execute
        output = capture_stdout { print_individual_tickets }

        # Verify
        expect(output).to be_empty
      end
    end
  end

  describe 'throughput formatting bug fix' do
    let(:metrics_param) { metrics }
    let(:team_metrics_param) do
      {
        'Engineering Managers' => {
          total_issues: 35,
          completed_issues: 0,
          in_progress_issues: 0,
          backlog_issues: 35,
          cycle_time: { average: 0.0, median: 0.0 },
          lead_time: { average: 0.0, median: 0.0 },
          throughput: { weekly_avg: 0.0, total_completed: 0 } # Hash format instead of number
        }
      }
    end
    let(:issues_param) { nil }

    it 'properly formats hash-based throughput values instead of displaying raw JSON' do
      # Execute
      output = capture_stdout { formatter.print_team_metrics }

      # Verify - should show "0 completed" instead of the raw hash
      aggregate_failures 'throughput formatting' do
        expect(output).to include('0 completed')
        expect(output).not_to include('{:weekly_avg=>0.0, :total_completed=>0}')
        expect(output).not_to include('weekly_avg')
        expect(output).not_to include('total_completed')
      end
    end
  end

  describe 'error handling' do
    let(:metrics_param) { metrics }
    let(:team_metrics_param) { nil }
    let(:issues_param) { nil }

    context 'with invalid metrics data' do
      let(:metrics_param) { nil }

      it 'raises ArgumentError on initialization' do
        # Execute & Verify
        expect { formatter }.to raise_error(ArgumentError, 'Metrics must be a non-empty Hash')
      end
    end

    context 'with empty metrics data' do
      let(:metrics_param) { {} }

      it 'raises ArgumentError on initialization' do
        # Execute & Verify
        expect { formatter }.to raise_error(ArgumentError, 'Metrics must be a non-empty Hash')
      end
    end

    context 'with missing nested data' do
      let(:metrics_param) do
        {
          total_issues: 10
          # Missing cycle_time, lead_time, throughput, etc.
        }
      end

      it 'handles missing data gracefully in summary' do
        # Execute
        output = capture_stdout { formatter.print_summary }

        # Verify - should still work but show N/A for missing values
        expect(output).to include('📈 SUMMARY')
        expect(output).to include('10') # total_issues
      end

      it 'handles missing data gracefully in cycle time' do
        # Execute & Verify - should not raise error
        expect { formatter.print_cycle_time }.not_to raise_error
      end

      it 'handles missing data gracefully in lead time' do
        # Execute & Verify - should not raise error
        expect { formatter.print_lead_time }.not_to raise_error
      end

      it 'handles missing data gracefully in throughput' do
        # Execute & Verify - should not raise error
        expect { formatter.print_throughput }.not_to raise_error
      end
    end
  end
end
