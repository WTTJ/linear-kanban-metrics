# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../../lib/kanban_metrics/formatters/table_formatter'

RSpec.describe KanbanMetrics::Formatters::TableFormatter do
  # Test Data Setup
  subject(:formatter) { described_class.new(metrics_param, team_metrics_param) }

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

  describe '#initialize' do
    context 'with metrics only' do
      # Setup
      let(:metrics_param) { metrics }
      let(:team_metrics_param) { nil }

      it 'creates formatter instance with metrics only' do
        # Execute & Verify
        expect(formatter).to be_a(described_class)
      end
    end

    context 'with metrics and team_metrics' do
      # Setup
      let(:metrics_param) { metrics }
      let(:team_metrics_param) { team_metrics }

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

  describe 'private methods' do
    # Setup
    let(:metrics_param) { metrics }
    let(:team_metrics_param) { team_metrics }

    describe '#build_summary_table' do
      subject(:build_summary_table) { formatter.send(:build_summary_table) }

      it 'creates a Terminal::Table instance' do
        # Execute
        result = build_summary_table

        # Verify
        expect(result).to be_a(Terminal::Table)
      end

      it 'includes correct headings' do
        # Execute
        result = build_summary_table
        headings = result.headings.first.cells.map(&:value)

        # Verify
        expect(headings).to eq(%w[Metric Value Description])
      end
    end

    describe '#build_cycle_time_table' do
      subject(:build_cycle_time_table) { formatter.send(:build_cycle_time_table) }

      it 'creates a Terminal::Table instance' do
        # Execute
        result = build_cycle_time_table

        # Verify
        expect(result).to be_a(Terminal::Table)
      end

      it 'includes correct headings' do
        # Execute
        result = build_cycle_time_table
        headings = result.headings.first.cells.map(&:value)

        # Verify
        expect(headings).to eq(%w[Metric Days Description])
      end
    end

    describe '#build_lead_time_table' do
      subject(:build_lead_time_table) { formatter.send(:build_lead_time_table) }

      it 'creates a Terminal::Table instance' do
        # Execute
        result = build_lead_time_table

        # Verify
        expect(result).to be_a(Terminal::Table)
      end

      it 'includes correct headings' do
        # Execute
        result = build_lead_time_table
        headings = result.headings.first.cells.map(&:value)

        # Verify
        expect(headings).to eq(%w[Metric Days Description])
      end
    end

    describe '#team_metrics_available?' do
      subject(:team_metrics_available) { formatter.send(:team_metrics_available?) }

      context 'with team metrics' do
        # Setup
        let(:team_metrics_param) { team_metrics }

        it 'returns true when team metrics are present' do
          # Execute & Verify
          expect(team_metrics_available).to be true
        end
      end

      context 'without team metrics' do
        # Setup
        let(:team_metrics_param) { nil }

        it 'returns false when team metrics are nil' do
          # Execute & Verify
          expect(team_metrics_available).to be false
        end
      end
    end
  end
end
