# frozen_string_literal: true

require 'spec_helper'

RSpec.describe KanbanMetrics::Formatters::JsonFormatter do
  # === TEST DATA SETUP ===
  # Named Subject
  subject(:formatter) { described_class.new(metrics, team_metrics, timeseries_data, issues_data) }

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
    instance_double(KanbanMetrics::Timeseries::TicketTimeseries,
                    status_flow_analysis: { 'Todo → In Progress' => 15, 'In Progress → Done' => 12 },
                    average_time_in_status: { 'Todo' => 3.2, 'In Progress' => 5.8, 'Done' => 0.1 },
                    daily_status_counts: { Date.today => { 'completed' => 3, 'started' => 2 } })
  end

  let(:sample_issues) do
    [
      {
        'identifier' => 'PROJ-123',
        'title' => 'Implement user authentication',
        'state' => { 'name' => 'Done' },
        'createdAt' => '2024-01-01T10:00:00Z',
        'startedAt' => '2024-01-02T14:00:00Z',
        'completedAt' => '2024-01-05T16:00:00Z',
        'team' => { 'name' => 'Backend Team' }
      },
      {
        'identifier' => 'PROJ-124',
        'title' => 'Fix login page styling issues',
        'state' => { 'name' => 'In Progress' },
        'createdAt' => '2024-01-03T09:00:00Z',
        'startedAt' => '2024-01-04T11:00:00Z',
        'completedAt' => nil,
        'team' => { 'name' => 'Frontend Team' }
      }
    ]
  end

  describe '#initialize' do
    context 'with metrics and team metrics only' do
      # Setup
      let(:timeseries_data) { nil }
      let(:issues_data) { nil }

      it 'stores the provided data correctly' do
        # Verify
        aggregate_failures 'initialization data storage' do
          expect(formatter.instance_variable_get(:@metrics)).to eq(metrics)
          expect(formatter.instance_variable_get(:@team_metrics)).to eq(team_metrics)
          expect(formatter.instance_variable_get(:@timeseries)).to be_nil
        end
      end
    end

    context 'with metrics only' do
      # Setup
      let(:team_metrics) { nil }
      let(:timeseries_data) { nil }
      let(:issues_data) { nil }

      it 'stores metrics data correctly' do
        # Verify
        aggregate_failures 'metrics-only initialization' do
          expect(formatter.instance_variable_get(:@metrics)).to eq(metrics)
          expect(formatter.instance_variable_get(:@team_metrics)).to be_nil
          expect(formatter.instance_variable_get(:@timeseries)).to be_nil
        end
      end
    end

    context 'with all data types' do
      # Setup
      let(:timeseries_data) { timeseries }
      let(:issues_data) { nil }

      it 'stores all provided data including timeseries' do
        # Verify
        aggregate_failures 'complete data initialization' do
          expect(formatter.instance_variable_get(:@metrics)).to eq(metrics)
          expect(formatter.instance_variable_get(:@team_metrics)).to eq(team_metrics)
          expect(formatter.instance_variable_get(:@timeseries)).to eq(timeseries)
        end
      end
    end

    describe '#generate' do
      # Execute
      subject(:parsed_json) { JSON.parse(json_output) }

      let(:json_output) { formatter.generate }

      context 'with only metrics' do
        # Setup
        let(:team_metrics) { nil }
        let(:timeseries_data) { nil }
        let(:issues_data) { nil }

        it 'produces valid JSON output with overall metrics' do
          # Verify
          aggregate_failures 'JSON output structure' do
            expect(parsed_json).to have_key('overall_metrics')
            expect(parsed_json['overall_metrics']).to eq(metrics.deep_stringify_keys)
            expect(parsed_json).not_to have_key('team_metrics')
            expect(parsed_json).not_to have_key('timeseries')
          end
        end

        it 'generates valid JSON format' do
          expect { JSON.parse(json_output) }.not_to raise_error
        end
      end

      context 'with metrics and team metrics' do
        # Setup
        let(:timeseries_data) { nil }
        let(:issues_data) { nil }

        it 'includes team metrics in the output' do
          # Verify
          aggregate_failures 'team metrics inclusion' do
            expect(parsed_json).to have_key('overall_metrics')
            expect(parsed_json).to have_key('team_metrics')
            expect(parsed_json['overall_metrics']).to eq(metrics.deep_stringify_keys)
            expect(parsed_json['team_metrics']).to eq(team_metrics.deep_stringify_keys)
          end
        end
      end

      context 'with timeseries data' do
        # Setup
        let(:timeseries_data) { timeseries }
        let(:issues_data) { nil }

        it 'includes timeseries data in the output' do
          # Verify
          aggregate_failures 'timeseries data inclusion' do
            expect(parsed_json).to have_key('overall_metrics')
            expect(parsed_json).to have_key('team_metrics')
            expect(parsed_json).to have_key('timeseries')
            expect(parsed_json['timeseries']).to be_a(Hash)
          end
        end

        it 'formats timeseries data correctly' do
          # Verify specific timeseries structure
          timeseries_data = parsed_json['timeseries']
          aggregate_failures 'timeseries structure' do
            expect(timeseries_data).to have_key('status_flow_analysis')
            expect(timeseries_data).to have_key('average_time_in_status')
            expect(timeseries_data).to have_key('daily_status_counts')
          end
        end
      end

      context 'with individual tickets data' do
        # Setup
        let(:team_metrics) { nil }
        let(:timeseries_data) { nil }
        let(:issues_data) { sample_issues }

        it 'includes individual tickets in the output' do
          # Verify
          aggregate_failures 'individual tickets inclusion' do
            expect(parsed_json).to have_key('overall_metrics')
            expect(parsed_json).to have_key('individual_tickets')
            expect(parsed_json['individual_tickets']).to be_an(Array)
            expect(parsed_json['individual_tickets'].length).to eq(2)
          end
        end

        it 'includes calculated metrics for each ticket' do
          # Verify
          ticket = parsed_json['individual_tickets'].first
          aggregate_failures 'ticket metrics calculation' do
            expect(ticket).to have_key('identifier')
            expect(ticket).to have_key('title')
            expect(ticket).to have_key('cycle_time_days')
            expect(ticket).to have_key('lead_time_days')
            expect(ticket['cycle_time_days']).to eq(3.08) # From 2024-01-02 14:00 to 2024-01-05 16:00
            expect(ticket['lead_time_days']).to eq(4.25) # From 2024-01-01 10:00 to 2024-01-05 16:00
          end
        end

        it 'handles incomplete tickets correctly' do
          # Verify
          incomplete_ticket = parsed_json['individual_tickets'].last
          aggregate_failures 'incomplete ticket handling' do
            expect(incomplete_ticket['completedAt']).to be_nil
            expect(incomplete_ticket['cycle_time_days']).to be_nil
            expect(incomplete_ticket['lead_time_days']).to be_nil
          end
        end
      end

      context 'without individual tickets data' do
        # Setup
        let(:team_metrics) { nil }
        let(:timeseries_data) { nil }
        let(:issues_data) { nil }

        it 'does not include individual tickets section' do
          # Verify
          aggregate_failures 'no individual tickets' do
            expect(parsed_json).to have_key('overall_metrics')
            expect(parsed_json).not_to have_key('individual_tickets')
          end
        end
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
