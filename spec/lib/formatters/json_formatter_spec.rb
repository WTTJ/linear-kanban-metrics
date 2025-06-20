# frozen_string_literal: true

require 'spec_helper'

RSpec.describe KanbanMetrics::Formatters::JsonFormatter do
  # === TEST DATA ===
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
    double('TimeSeriesCalculator',
           status_flow_analysis: { 'Todo → In Progress' => 15, 'In Progress → Done' => 12 },
           average_time_in_status: { 'Todo' => 3.2, 'In Progress' => 5.8, 'Done' => 0.1 },
           daily_status_counts: { Date.today => { 'completed' => 3, 'started' => 2 } })
  end

  describe '#initialize' do
    context 'when initializing with metrics and team metrics' do
      it 'stores the provided data correctly' do
        # Arrange
        # (data setup in let blocks)

        # Act
        formatter = described_class.new(metrics, team_metrics)

        # Assert
        aggregate_failures 'initialization with metrics and team metrics' do
          expect(formatter.instance_variable_get(:@metrics)).to eq(metrics)
          expect(formatter.instance_variable_get(:@team_metrics)).to eq(team_metrics)
          expect(formatter.instance_variable_get(:@timeseries)).to be_nil
        end

        # Cleanup
        # (automatic with let blocks)
      end
    end

    context 'when initializing with timeseries data' do
      it 'stores all provided data including timeseries' do
        # Arrange
        # (data setup in let blocks)

        # Act
        formatter = described_class.new(metrics, team_metrics, timeseries)

        # Assert
        aggregate_failures 'initialization with timeseries data' do
          expect(formatter.instance_variable_get(:@metrics)).to eq(metrics)
          expect(formatter.instance_variable_get(:@team_metrics)).to eq(team_metrics)
          expect(formatter.instance_variable_get(:@timeseries)).to eq(timeseries)
        end

        # Cleanup
        # (automatic with let blocks)
      end
    end
  end

  describe '#generate' do
    context 'when generating JSON with only metrics' do
      it 'produces valid JSON output with overall metrics' do
        # Arrange
        formatter = described_class.new(metrics)

        # Act
        json_output = formatter.generate

        # Assert
        parsed = JSON.parse(json_output)
        aggregate_failures 'JSON output with only metrics' do
          expect(parsed).to have_key('overall_metrics')
          expect(parsed['overall_metrics']).to eq(metrics.deep_stringify_keys)
          expect(parsed).not_to have_key('team_metrics')
          expect(parsed).not_to have_key('timeseries')
        end

        # Cleanup
        # (automatic with let blocks)
      end
    end

    context 'when generating JSON with metrics and team metrics' do
      it 'includes team metrics in the output' do
        # Arrange
        formatter = described_class.new(metrics, team_metrics)

        # Act
        json_output = formatter.generate

        # Assert
        parsed = JSON.parse(json_output)
        aggregate_failures 'JSON output with team metrics' do
          expect(parsed).to have_key('overall_metrics')
          expect(parsed).to have_key('team_metrics')
          expect(parsed['overall_metrics']).to eq(metrics.deep_stringify_keys)
          expect(parsed['team_metrics']).to eq(team_metrics.deep_stringify_keys)
        end

        # Cleanup
        # (automatic with let blocks)
      end
    end

    context 'when generating JSON with timeseries data' do
      it 'includes timeseries data in the output' do
        # Arrange
        formatter = described_class.new(metrics, team_metrics, timeseries)

        # Act
        json_output = formatter.generate

        # Assert
        parsed = JSON.parse(json_output)
        aggregate_failures 'JSON output with timeseries data' do
          expect(parsed).to have_key('timeseries')
          expect(parsed['timeseries']).to have_key('status_flow_analysis')
          expect(parsed['timeseries']).to have_key('average_time_in_status')
          expect(parsed['timeseries']).to have_key('daily_status_counts')
          expect(parsed['timeseries']['status_flow_analysis']).to eq(
            timeseries.status_flow_analysis.deep_stringify_keys
          )
        end

        # Cleanup
        # (automatic with let blocks)
      end
    end

    context 'when generating pretty-formatted JSON' do
      it 'produces nicely formatted output' do
        # Arrange
        formatter = described_class.new(metrics)

        # Act
        json_output = formatter.generate

        # Assert
        aggregate_failures 'JSON formatting' do
          expect(json_output).to include("\n")
          expect(json_output).to include('  ')
          expect { JSON.parse(json_output) }.not_to raise_error
        end

        # Cleanup
        # (automatic with let blocks)
      end
    end
  end

  describe '#build_timeseries_data' do
    context 'when no timeseries data is provided' do
      it 'returns an empty hash' do
        # Arrange
        formatter = described_class.new(metrics)

        # Act
        result = formatter.send(:build_timeseries_data)

        # Assert
        expect(result).to eq({})

        # Cleanup
        # (automatic with let blocks)
      end
    end

    context 'when timeseries data is provided' do
      it 'builds a comprehensive timeseries data hash' do
        # Arrange
        formatter = described_class.new(metrics, team_metrics, timeseries)

        # Act
        result = formatter.send(:build_timeseries_data)

        # Assert
        aggregate_failures 'timeseries data structure' do
          expect(result).to have_key(:status_flow_analysis)
          expect(result).to have_key(:average_time_in_status)
          expect(result).to have_key(:daily_status_counts)
          expect(result[:status_flow_analysis]).to eq(timeseries.status_flow_analysis)
          expect(result[:average_time_in_status]).to eq(timeseries.average_time_in_status)
          expect(result[:daily_status_counts]).to eq(timeseries.daily_status_counts)
        end

        # Cleanup
        # (automatic with let blocks)
      end
    end
  end
end
