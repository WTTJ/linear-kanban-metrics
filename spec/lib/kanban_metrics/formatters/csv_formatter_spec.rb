# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../../lib/kanban_metrics/formatters/csv_formatter'

RSpec.describe KanbanMetrics::Formatters::CsvFormatter do
  # Test Data Setup
  subject(:formatter) { described_class.new(metrics_param, team_metrics_param, timeseries_param) }

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

  let(:timeseries) do
    double('timeseries',
           status_flow_analysis: {
             'Backlog → In Progress' => 45,
             'In Progress → Done' => 40,
             'Done → Backlog' => 5
           },
           average_time_in_status: {
             'Backlog' => 2.5,
             'In Progress' => 5.8,
             'Done' => 0.0
           })
  end

  describe '#initialize' do
    context 'with metrics only' do
      # Setup
      let(:metrics_param) { metrics }
      let(:team_metrics_param) { nil }
      let(:timeseries_param) { nil }

      it 'creates formatter instance with metrics only' do
        # Execute & Verify
        expect(formatter).to be_a(described_class)
      end
    end

    context 'with metrics and team_metrics' do
      # Setup
      let(:metrics_param) { metrics }
      let(:team_metrics_param) { team_metrics }
      let(:timeseries_param) { nil }

      it 'creates formatter instance with team metrics' do
        # Execute & Verify
        expect(formatter).to be_a(described_class)
      end
    end

    context 'with metrics and timeseries' do
      # Setup
      let(:metrics_param) { metrics }
      let(:team_metrics_param) { nil }
      let(:timeseries_param) { timeseries }

      it 'creates formatter instance with timeseries' do
        # Execute & Verify
        expect(formatter).to be_a(described_class)
      end
    end

    context 'with all parameters' do
      # Setup
      let(:metrics_param) { metrics }
      let(:team_metrics_param) { team_metrics }
      let(:timeseries_param) { timeseries }

      it 'creates formatter instance with all parameters' do
        # Execute & Verify
        expect(formatter).to be_a(described_class)
      end
    end
  end

  describe '#generate' do
    subject(:generate_csv) { formatter.generate }

    context 'with basic metrics only' do
      # Setup
      let(:metrics_param) { metrics }
      let(:team_metrics_param) { nil }
      let(:timeseries_param) { nil }

      it 'generates CSV string with headers' do
        # Execute
        result = generate_csv

        # Verify
        aggregate_failures 'CSV string generation' do
          expect(result).to be_a(String)
          expect(result).to include('Metric,Value,Unit')
        end
      end

      it 'includes all overall metrics' do
        # Execute
        result = generate_csv

        # Verify
        aggregate_failures 'overall metrics content' do
          expect(result).to include('Total Issues,100,count')
          expect(result).to include('Completed Issues,60,count')
          expect(result).to include('In Progress Issues,25,count')
          expect(result).to include('Backlog Issues,15,count')
          expect(result).to include('Average Cycle Time,8.5,days')
          expect(result).to include('Median Cycle Time,6.0,days')
          expect(result).to include('95th Percentile Cycle Time,18.2,days')
          expect(result).to include('Average Lead Time,12.3,days')
          expect(result).to include('Median Lead Time,9.1,days')
          expect(result).to include('95th Percentile Lead Time,25.7,days')
          expect(result).to include('Weekly Throughput Average,15.2,issues/week')
          expect(result).to include('Total Completed,60,count')
          expect(result).to include('Flow Efficiency,65.5,percentage')
        end
      end

      it 'generates valid CSV format' do
        # Execute
        result = generate_csv

        # Verify
        aggregate_failures 'CSV format validation' do
          expect { CSV.parse(result) }.not_to raise_error
          parsed_csv = CSV.parse(result)
          expect(parsed_csv).to be_an(Array)
          expect(parsed_csv.first).to eq(%w[Metric Value Unit])
        end
      end
    end

    context 'with team metrics' do
      # Setup
      let(:metrics_param) { metrics }
      let(:team_metrics_param) { team_metrics }
      let(:timeseries_param) { nil }

      it 'includes team metrics section' do
        # Execute
        result = generate_csv

        # Verify
        aggregate_failures 'team metrics section' do
          expect(result).to include('TEAM METRICS')
          expect(result).to include('Backend Team')
          expect(result).to include('Frontend Team')
        end
      end

      it 'includes team metrics headers' do
        # Execute
        result = generate_csv

        # Verify
        expect(result).to include('Team,Total Issues,Completed Issues,In Progress Issues,Backlog Issues')
      end

      it 'includes team-specific data' do
        # Execute
        result = generate_csv

        # Verify
        aggregate_failures 'team data content' do
          expect(result).to include('Backend Team,60,40,15,5')
          expect(result).to include('Frontend Team,40,20,10,10')
        end
      end

      it 'sorts teams alphabetically' do
        # Execute
        result = generate_csv
        lines = result.split("\n")

        # Verify
        backend_line_index = lines.find_index { |line| line.include?('Backend Team') }
        frontend_line_index = lines.find_index { |line| line.include?('Frontend Team') }

        expect(backend_line_index).to be < frontend_line_index
      end
    end

    context 'with timeseries data' do
      let(:formatter) { described_class.new(metrics, nil, timeseries) }

      it 'includes timeseries analysis section' do
        csv_output = formatter.generate

        expect(csv_output).to include('TIMESERIES ANALYSIS')
        expect(csv_output).to include('STATUS TRANSITIONS')
        expect(csv_output).to include('AVERAGE TIME IN STATUS')
      end

      it 'includes status transitions data' do
        csv_output = formatter.generate

        expect(csv_output).to include('Transition,Count')
        expect(csv_output).to include('Backlog → In Progress,45')
        expect(csv_output).to include('In Progress → Done,40')
        expect(csv_output).to include('Done → Backlog,5')
      end

      it 'includes time in status data' do
        csv_output = formatter.generate

        expect(csv_output).to include('Status,Average Days')
        expect(csv_output).to include('Backlog,2.5')
        expect(csv_output).to include('In Progress,5.8')
        expect(csv_output).to include('Done,0.0')
      end
    end

    context 'with all data types' do
      # Setup
      let(:metrics_param) { metrics }
      let(:team_metrics_param) { team_metrics }
      let(:timeseries_param) { timeseries }

      it 'includes all sections' do
        # Execute
        result = generate_csv

        # Verify
        aggregate_failures 'all sections present' do
          expect(result).to include('Metric,Value,Unit')
          expect(result).to include('TEAM METRICS')
          expect(result).to include('TIMESERIES ANALYSIS')
        end
      end

      it 'maintains proper section separation' do
        # Execute
        result = generate_csv
        lines = result.split("\n")

        # Verify
        # Check that empty lines separate sections
        expect(lines).to include('')
      end

      it 'generates valid CSV with all sections' do
        # Execute
        result = generate_csv

        # Verify
        aggregate_failures 'comprehensive CSV validation' do
          expect { CSV.parse(result) }.not_to raise_error
          parsed_csv = CSV.parse(result)
          expect(parsed_csv.length).to be > 20 # Should have many rows with all data
        end
      end
    end
  end

  describe 'CSV structure' do
    subject(:csv_structure) { CSV.parse(formatter.generate) }

    # Setup
    let(:metrics_param) { metrics }
    let(:team_metrics_param) { team_metrics }
    let(:timeseries_param) { timeseries }

    it 'produces parseable CSV' do
      # Execute
      result = csv_structure

      # Verify
      aggregate_failures 'CSV parsing' do
        expect(result).to be_an(Array)
        expect(result).to all(be_an(Array))
      end
    end

    it 'maintains consistent column structure in sections' do
      # Execute
      result = csv_structure

      # Verify
      aggregate_failures 'CSV structure consistency' do
        # First row should be the overall metrics header
        expect(result.first).to eq(%w[Metric Value Unit])

        # Find team metrics section
        team_header_index = result.find_index { |row| row.first == 'Team' }
        expect(team_header_index).not_to be_nil
        expect(result[team_header_index].length).to eq(10) # 10 columns for team metrics
      end
    end
  end
end
