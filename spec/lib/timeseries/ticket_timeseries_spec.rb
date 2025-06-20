# frozen_string_literal: true

require 'spec_helper'

RSpec.describe KanbanMetrics::Timeseries::TicketTimeseries do
  subject(:timeseries) { described_class.new(issues) }

  # Shared test data
  let(:sample_issues) do
    [
      {
        'id' => 'issue-1',
        'title' => 'Test Issue 1',
        'team' => { 'name' => 'Backend Team' },
        'history' => {
          'nodes' => [
            {
              'createdAt' => '2024-01-01T10:00:00Z',
              'toState' => { 'name' => 'Backlog', 'type' => 'backlog' }
            },
            {
              'createdAt' => '2024-01-02T10:00:00Z',
              'toState' => { 'name' => 'In Progress', 'type' => 'started' }
            },
            {
              'createdAt' => '2024-01-05T10:00:00Z',
              'toState' => { 'name' => 'Done', 'type' => 'completed' }
            }
          ]
        }
      },
      {
        'id' => 'issue-2',
        'title' => 'Test Issue 2',
        'team' => { 'name' => 'Frontend Team' },
        'history' => {
          'nodes' => [
            {
              'createdAt' => '2024-01-01T12:00:00Z',
              'toState' => { 'name' => 'Backlog', 'type' => 'backlog' }
            },
            {
              'createdAt' => '2024-01-03T10:00:00Z',
              'toState' => { 'name' => 'In Progress', 'type' => 'started' }
            }
          ]
        }
      }
    ]
  end

  let(:empty_issues) { [] }

  let(:malformed_issues) do
    [
      { 'id' => 'issue-1' }, # Missing history
      { 'id' => 'issue-2', 'history' => {} }, # Empty history
      { 'id' => 'issue-3', 'history' => { 'nodes' => [] } } # Empty nodes
    ]
  end

  describe '#initialize' do
    context 'with valid issues array' do
      let(:issues) { sample_issues }

      it 'creates a timeseries instance with provided issues' do
        # Given: An array of valid issues
        # When: Creating a new timeseries instance
        # Then: Should create a valid timeseries object
        expect(timeseries).to be_a(described_class)
      end
    end

    context 'with empty issues array' do
      let(:issues) { empty_issues }

      it 'creates a timeseries instance with empty array' do
        # Given: An empty issues array
        # When: Creating a new timeseries instance
        # Then: Should create a valid timeseries object
        expect(timeseries).to be_a(described_class)
      end
    end
  end

  describe '#status_flow_analysis' do
    context 'with valid issues containing status transitions' do
      let(:issues) { sample_issues }

      it 'returns hash of status transitions with counts' do
        # Given: Issues with status transition history
        # When: Analyzing status flow
        result = timeseries.status_flow_analysis

        # Then: Should return hash with transition counts
        aggregate_failures do
          expect(result).to be_a(Hash)
          expect(result).to include('Backlog → In Progress')
          expect(result['Backlog → In Progress']).to eq(2)
        end
      end

      it 'sorts transitions by count in descending order' do
        # Given: Issues with various transitions
        # When: Analyzing status flow
        result = timeseries.status_flow_analysis
        transition_counts = result.values

        # Then: Should sort counts in descending order
        expect(transition_counts).to eq(transition_counts.sort.reverse)
      end
    end

    context 'with empty issues array' do
      let(:issues) { empty_issues }

      it 'returns empty hash when no issues provided' do
        # Given: Empty issues array
        # When: Analyzing status flow
        result = timeseries.status_flow_analysis

        # Then: Should return empty hash
        expect(result).to be_empty
      end
    end
  end

  describe '#average_time_in_status' do
    context 'with valid issues containing time data' do
      let(:issues) { sample_issues }

      it 'returns hash of status names with average duration in days' do
        # Given: Issues with time-based status transitions
        # When: Calculating average time in status
        result = timeseries.average_time_in_status

        # Then: Should return hash with status names and numeric averages
        aggregate_failures do
          expect(result).to be_a(Hash)
          expect(result).to have_key('Backlog')
          expect(result).to have_key('In Progress')
          expect(result.values).to all(be_a(Float))
        end
      end

      it 'calculates meaningful positive averages for status durations' do
        # Given: Issues with time spent in various statuses
        # When: Calculating average time in status
        result = timeseries.average_time_in_status

        # Then: Should calculate positive durations
        expect(result['Backlog']).to be > 0
        expect(result['In Progress']).to be > 0
      end
    end

    context 'with empty issues array' do
      let(:issues) { empty_issues }

      it 'returns empty hash when no issues provided' do
        # Given: Empty issues array
        # When: Calculating average time in status
        result = timeseries.average_time_in_status

        # Then: Should return empty hash
        expect(result).to be_empty
      end
    end
  end

  describe '#daily_status_counts' do
    context 'with valid issues containing dated events' do
      let(:issues) { sample_issues }

      it 'returns hash of dates with status change counts' do
        # Given: Issues with dated status changes
        # When: Analyzing daily status counts
        result = timeseries.daily_status_counts

        # Then: Should return hash with Date keys and hash values
        aggregate_failures do
          expect(result).to be_a(Hash)
          expect(result.keys).to all(be_a(Date))
          expect(result.values).to all(be_a(Hash))
        end
      end

      it 'includes status changes for specific dates' do
        # Given: Issues with known status change dates
        # When: Analyzing daily status counts
        result = timeseries.daily_status_counts

        # Then: Should include expected dates
        jan_1 = Date.new(2024, 1, 1)
        jan_2 = Date.new(2024, 1, 2)

        expect(result).to have_key(jan_1)
        expect(result).to have_key(jan_2)
        expect(result[jan_1]).to be_a(Hash)
      end
    end

    context 'with empty issues array' do
      let(:issues) { empty_issues }

      it 'returns empty hash when no issues provided' do
        # Given: Empty issues array
        # When: Analyzing daily status counts
        result = timeseries.daily_status_counts

        # Then: Should return empty hash
        expect(result).to be_empty
      end
    end
  end

  describe '#generate_timeseries' do
    context 'with valid issues containing complete data' do
      let(:issues) { sample_issues }

      it 'returns array of issue timelines with correct structure' do
        # Given: Valid issues with history data
        # When: Generating timeseries data
        result = timeseries.generate_timeseries

        # Then: Should return array with correct structure
        aggregate_failures do
          expect(result).to be_an(Array)
          expect(result.length).to eq(2)

          # Each issue should have required timeline structure
          first_issue = result.first
          expect(first_issue).to have_key(:id)
          expect(first_issue).to have_key(:title)
          expect(first_issue).to have_key(:team)
          expect(first_issue).to have_key(:timeline)
        end
      end

      it 'includes complete timeline data for each issue' do
        # Given: Valid issues with known data
        # When: Generating timeseries data
        result = timeseries.generate_timeseries
        first_issue = result.first

        # Then: Should include correct issue metadata and timeline events
        aggregate_failures do
          expect(first_issue[:id]).to eq('issue-1')
          expect(first_issue[:title]).to eq('Test Issue 1')
          expect(first_issue[:team]).to eq('Backend Team')
          expect(first_issue[:timeline]).to be_an(Array)
          expect(first_issue[:timeline]).not_to be_empty
        end
      end

      it 'formats timeline events with required fields' do
        # Given: Valid issues with event history
        # When: Generating timeseries data
        result = timeseries.generate_timeseries
        first_timeline_event = result.first[:timeline].first

        # Then: Each timeline event should have required fields
        expect(first_timeline_event).to have_key(:date)
        expect(first_timeline_event).to have_key(:from_state)
        expect(first_timeline_event).to have_key(:to_state)
      end
    end

    context 'with empty issues array' do
      let(:issues) { empty_issues }

      it 'returns empty array when no issues provided' do
        # Given: Empty issues array
        # When: Generating timeseries data
        result = timeseries.generate_timeseries

        # Then: Should return empty array
        expect(result).to eq([])
      end
    end
  end

  describe 'TimelineBuilder integration' do
    let(:issues) { sample_issues }

    it 'uses TimelineBuilder for generating timeline data' do
      # Given: A timeseries instance and mocked TimelineBuilder
      mock_timeline_builder = instance_double(KanbanMetrics::Timeseries::TimelineBuilder)
      allow(KanbanMetrics::Timeseries::TimelineBuilder).to receive(:new).and_return(mock_timeline_builder)
      allow(mock_timeline_builder).to receive(:build_timeline).and_return([])

      # When: Performing status flow analysis
      timeseries.status_flow_analysis

      # Then: Should use TimelineBuilder to build timelines
      expect(mock_timeline_builder).to have_received(:build_timeline).at_least(:once)
    end
  end

  describe 'error handling and edge cases' do
    context 'with malformed issues data' do
      let(:issues) { malformed_issues }

      it 'handles issues without history gracefully without raising errors', :aggregate_failures do
        # Given: Issues with missing or malformed history data
        # When: Calling various analysis methods
        # Then: Should not raise errors
        expect { timeseries.status_flow_analysis }.not_to raise_error
        expect { timeseries.average_time_in_status }.not_to raise_error
        expect { timeseries.daily_status_counts }.not_to raise_error
        expect { timeseries.generate_timeseries }.not_to raise_error
      end

      it 'returns appropriate default structures for malformed data', :aggregate_failures do
        # Given: Issues with malformed data
        # When: Calling analysis methods
        # Then: Should return appropriate data structures
        expect(timeseries.status_flow_analysis).to be_a(Hash)
        expect(timeseries.average_time_in_status).to be_a(Hash)
        expect(timeseries.daily_status_counts).to be_a(Hash)
        expect(timeseries.generate_timeseries).to be_an(Array)
      end
    end
  end
end
