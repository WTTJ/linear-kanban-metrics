# frozen_string_literal: true

require 'spec_helper'

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

  describe 'Individual Tickets Export' do
    let(:issues) do
      [
        {
          'id' => 'issue-1',
          'identifier' => 'PROJ-123',
          'title' => 'Implement user authentication',
          'state' => { 'name' => 'Done', 'type' => 'completed' },
          'team' => { 'name' => 'Backend Team' },
          'assignee' => { 'name' => 'John Doe' },
          'priority' => 1,
          'estimate' => 3,
          'createdAt' => '2024-01-01T09:00:00Z',
          'updatedAt' => '2024-01-05T17:00:00Z',
          'startedAt' => '2024-01-02T10:00:00Z',
          'completedAt' => '2024-01-05T16:00:00Z',
          'archivedAt' => nil
        },
        {
          'id' => 'issue-2',
          'identifier' => 'PROJ-124',
          'title' => 'Fix login bug',
          'state' => { 'name' => 'In Progress', 'type' => 'started' },
          'team' => { 'name' => 'Frontend Team' },
          'assignee' => { 'name' => 'Jane Smith' },
          'priority' => 0,
          'estimate' => 1,
          'createdAt' => '2024-01-03T14:00:00Z',
          'updatedAt' => '2024-01-06T11:00:00Z',
          'startedAt' => '2024-01-04T09:00:00Z',
          'completedAt' => nil,
          'archivedAt' => nil
        },
        {
          'id' => 'issue-3',
          'identifier' => 'PROJ-125',
          'title' => 'Add new dashboard widget',
          'state' => { 'name' => 'Backlog', 'type' => 'unstarted' },
          'team' => { 'name' => 'Frontend Team' },
          'assignee' => nil,
          'priority' => 2,
          'estimate' => 5,
          'createdAt' => '2024-01-06T10:00:00Z',
          'updatedAt' => '2024-01-06T10:00:00Z',
          'startedAt' => nil,
          'completedAt' => nil,
          'archivedAt' => nil
        }
      ]
    end

    context 'with individual tickets provided' do
      subject(:formatter) { described_class.new(metrics, nil, nil, issues) }

      it 'includes individual tickets section in CSV output' do
        result = formatter.generate

        expect(result).to include('INDIVIDUAL TICKETS')
        expect(result).to include('ID,Identifier,Title,State,State Type,Team,Assignee,Priority,Estimate,Created At,Updated At,Started At,Completed At,Archived At,Cycle Time (days),Lead Time (days)')
      end

      it 'exports each ticket with all fields' do
        result = formatter.generate

        # Check first issue (completed)
        expect(result).to include('issue-1,PROJ-123,Implement user authentication,Done,completed,Backend Team,John Doe,1,3,2024-01-01T09:00:00Z,2024-01-05T17:00:00Z,2024-01-02T10:00:00Z,2024-01-05T16:00:00Z,,3.25,4.29')

        # Check second issue (in progress - no completion time)
        expect(result).to include('issue-2,PROJ-124,Fix login bug,In Progress,started,Frontend Team,Jane Smith,0,1,2024-01-03T14:00:00Z,2024-01-06T11:00:00Z,2024-01-04T09:00:00Z,,,')

        # Check third issue (backlog - no start or completion time)
        expect(result).to include('issue-3,PROJ-125,Add new dashboard widget,Backlog,unstarted,Frontend Team,,2,5,2024-01-06T10:00:00Z,2024-01-06T10:00:00Z,,,,,')
      end

      it 'calculates cycle time correctly for completed issues' do
        result = formatter.generate

        # Issue 1: started 2024-01-02T10:00:00Z, completed 2024-01-05T16:00:00Z
        # Should be ~3.25 days
        expect(result).to include('3.25')
      end

      it 'calculates lead time correctly for completed issues' do
        result = formatter.generate

        # Issue 1: created 2024-01-01T09:00:00Z, completed 2024-01-05T16:00:00Z
        # Should be ~4.29 days
        expect(result).to include('4.29')
      end

      it 'handles nil values gracefully' do
        result = formatter.generate

        # Issue 3 has nil assignee, startedAt, completedAt, archivedAt
        expect(result).to include('Frontend Team,,2,5')
      end

      it 'does not calculate times for incomplete issues' do
        result = formatter.generate

        # Issue 2 (in progress) should have empty cycle time since no completedAt
        # Issue 3 (backlog) should have empty cycle and lead time
        lines = result.split("\n")
        issue_2_line = lines.find { |line| line.include?('issue-2') }
        issue_3_line = lines.find { |line| line.include?('issue-3') }

        expect(issue_2_line).to end_with(',,')  # No cycle or lead time
        expect(issue_3_line).to end_with(',,')  # No cycle or lead time
      end
    end

    context 'without individual tickets' do
      subject(:formatter) { described_class.new(metrics, nil, nil, nil) }

      it 'does not include individual tickets section' do
        result = formatter.generate

        expect(result).not_to include('INDIVIDUAL TICKETS')
      end
    end

    context 'with empty issues array' do
      subject(:formatter) { described_class.new(metrics, nil, nil, []) }

      it 'does not include individual tickets section' do
        result = formatter.generate

        expect(result).not_to include('INDIVIDUAL TICKETS')
      end
    end
  end
end
