# frozen_string_literal: true

require 'spec_helper'

RSpec.describe KanbanMetrics::Reports::TimelineDisplay do
  subject(:timeline_display) { described_class.new(issues) }

  # Shared test data
  let(:sample_issues) do
    [
      {
        'id' => 'issue-1',
        'title' => 'Test Issue 1',
        'team' => { 'name' => 'Backend Team' }
      },
      {
        'id' => 'issue-2',
        'title' => 'Test Issue 2',
        'team' => { 'name' => 'Frontend Team' }
      }
    ]
  end

  let(:sample_timeline_data) do
    [
      {
        id: 'issue-1',
        title: 'Test Issue 1',
        team: 'Backend Team',
        timeline: [
          {
            date: '2024-01-01T10:00:00Z',
            from_state: nil,
            to_state: 'Backlog'
          },
          {
            date: '2024-01-02T10:00:00Z',
            from_state: 'Backlog',
            to_state: 'In Progress'
          },
          {
            date: '2024-01-05T10:00:00Z',
            from_state: 'In Progress',
            to_state: 'Done'
          }
        ]
      }
    ]
  end

  describe '#initialize' do
    context 'with an array of issues' do
      let(:issues) { sample_issues }

      it 'creates a timeline display instance' do
        # Given: An array of issues
        # When: Creating a timeline display
        # Then: Should create a valid instance
        expect(timeline_display).to be_a(described_class)
      end
    end

    context 'with empty array' do
      let(:issues) { [] }

      it 'creates a timeline display instance with empty issues' do
        # Given: An empty array of issues
        # When: Creating a timeline display
        # Then: Should create a valid instance
        expect(timeline_display).to be_a(described_class)
      end
    end
  end

  describe '#show_timeline' do
    let(:issues) { sample_issues }
    let(:mock_timeseries) { instance_double(KanbanMetrics::Timeseries::TicketTimeseries) }

    before do
      setup_timeseries_mock
    end

    context 'when issue exists with timeline data' do
      let(:timeline_data) { sample_timeline_data }

      it 'displays complete timeline with all events and formatting' do
        # Given: An existing issue with timeline data
        allow(mock_timeseries).to receive(:generate_timeseries).and_return(timeline_data)

        # When: Showing timeline for the issue
        output = capture_stdout { timeline_display.show_timeline('issue-1') }

        # Then: Should display formatted timeline header and events
        aggregate_failures do
          expect(output).to include('📈 TIMELINE FOR issue-1: Test Issue 1')
          expect(output).to include('Team: Backend Team')
          expect(output).to include('=' * 80)

          # And: Should display all timeline events
          expect(output).to include('2024-01-01 10:00 | Created → Backlog')
          expect(output).to include('2024-01-02 10:00 | Backlog → In Progress')
          expect(output).to include('2024-01-05 10:00 | In Progress → Done')
        end
      end

      it 'uses TicketTimeseries to generate timeline data correctly' do
        # Given: An existing issue
        allow(mock_timeseries).to receive(:generate_timeseries).and_return(timeline_data)

        # When: Showing timeline for the issue
        timeline_display.show_timeline('issue-1')

        # Then: Should create TicketTimeseries and generate data
        aggregate_failures do
          expect(KanbanMetrics::Timeseries::TicketTimeseries).to have_received(:new).with(sample_issues)
          expect(mock_timeseries).to have_received(:generate_timeseries)
        end
      end
    end

    context 'when issue does not exist' do
      it 'displays not found message with error indicator' do
        # Given: No matching timeline data
        allow(mock_timeseries).to receive(:generate_timeseries).and_return([])

        # When: Showing timeline for non-existent issue
        output = capture_stdout { timeline_display.show_timeline('non-existent') }

        # Then: Should display error message
        expect(output).to include('❌ Issue non-existent not found')
      end

      it 'does not display timeline formatting when issue not found' do
        # Given: No matching timeline data
        allow(mock_timeseries).to receive(:generate_timeseries).and_return([])

        # When: Showing timeline for non-existent issue
        output = capture_stdout { timeline_display.show_timeline('non-existent') }

        # Then: Should not display timeline elements
        aggregate_failures do
          expect(output).not_to include('TIMELINE FOR')
          expect(output).not_to include('Team:')
          expect(output).not_to include('=' * 80)
        end
      end
    end

    context 'when issue exists but has empty timeline' do
      let(:empty_timeline_data) do
        [
          {
            id: 'issue-1',
            title: 'Test Issue 1',
            team: 'Backend Team',
            timeline: []
          }
        ]
      end

      it 'displays issue header without timeline events' do
        # Given: Issue with empty timeline
        allow(mock_timeseries).to receive(:generate_timeseries).and_return(empty_timeline_data)

        # When: Showing timeline for the issue
        output = capture_stdout { timeline_display.show_timeline('issue-1') }

        # Then: Should display header but not events
        aggregate_failures do
          expect(output).to include('📈 TIMELINE FOR issue-1: Test Issue 1')
          expect(output).to include('Team: Backend Team')

          # But: Should not display any timeline events
          expect(output).not_to include('Created →')
          expect(output).not_to include('→ Backlog')
        end
      end
    end

    context 'when issue has complex timeline with multiple transitions' do
      let(:complex_timeline_data) do
        [
          {
            id: 'issue-1',
            title: 'Complex Issue',
            team: 'Complex Team',
            timeline: [
              {
                date: '2024-01-01T10:00:00Z',
                from_state: nil,
                to_state: 'Backlog'
              },
              {
                date: '2024-01-02T14:30:00Z',
                from_state: 'Backlog',
                to_state: 'In Progress'
              },
              {
                date: '2024-01-03T09:15:00Z',
                from_state: 'In Progress',
                to_state: 'In Review'
              },
              {
                date: '2024-01-04T16:45:00Z',
                from_state: 'In Review',
                to_state: 'Done'
              }
            ]
          }
        ]
      end

      it 'displays all timeline events with correct formatting' do
        # Given: Issue with complex timeline
        allow(mock_timeseries).to receive(:generate_timeseries).and_return(complex_timeline_data)

        # When: Showing timeline for the issue
        output = capture_stdout { timeline_display.show_timeline('issue-1') }

        # Then: Should display all events in correct format
        aggregate_failures do
          expect(output).to include('2024-01-01 10:00 | Created → Backlog')
          expect(output).to include('2024-01-02 14:30 | Backlog → In Progress')
          expect(output).to include('2024-01-03 09:15 | In Progress → In Review')
          expect(output).to include('2024-01-04 16:45 | In Review → Done')
        end
      end

      it 'maintains chronological order of events' do
        # Given: Issue with multiple timeline events
        allow(mock_timeseries).to receive(:generate_timeseries).and_return(complex_timeline_data)

        # When: Showing timeline for the issue
        output = capture_stdout { timeline_display.show_timeline('issue-1') }
        output_lines = output.split("\n")

        # Then: Should maintain chronological order
        aggregate_failures do
          jan_1_line = output_lines.find { |line| line.include?('2024-01-01') }
          jan_4_line = output_lines.find { |line| line.include?('2024-01-04') }

          expect(jan_1_line).not_to be_nil
          expect(jan_4_line).not_to be_nil
          expect(output_lines.index(jan_1_line)).to be < output_lines.index(jan_4_line)
        end
      end
    end

    private

    def setup_timeseries_mock
      allow(KanbanMetrics::Timeseries::TicketTimeseries).to receive(:new)
        .with(sample_issues)
        .and_return(mock_timeseries)
    end
  end

  describe 'private methods' do
    let(:issues) { sample_issues }
    let(:mock_timeseries) { instance_double(KanbanMetrics::Timeseries::TicketTimeseries) }

    before do
      setup_timeseries_mock
    end

    describe '#find_timeline_data' do
      let(:timeline_data) do
        [
          { id: 'issue-1', title: 'Test Issue 1' },
          { id: 'issue-2', title: 'Test Issue 2' }
        ]
      end

      it 'finds timeline data by issue ID when exists' do
        # Given: Timeline data with multiple issues
        allow(mock_timeseries).to receive(:generate_timeseries).and_return(timeline_data)

        # When: Finding timeline data for existing issue
        result = timeline_display.send(:find_timeline_data, 'issue-1')

        # Then: Should return the correct issue data and use TicketTimeseries
        aggregate_failures do
          expect(result).to eq({ id: 'issue-1', title: 'Test Issue 1' })
          expect(KanbanMetrics::Timeseries::TicketTimeseries).to have_received(:new).with(sample_issues)
          expect(mock_timeseries).to have_received(:generate_timeseries)
        end
      end

      it 'returns nil when issue ID does not exist' do
        # Given: Timeline data without the requested issue
        allow(mock_timeseries).to receive(:generate_timeseries).and_return(timeline_data)

        # When: Finding timeline data for non-existent issue
        result = timeline_display.send(:find_timeline_data, 'non-existent')

        # Then: Should return nil
        expect(result).to be_nil
      end

      it 'handles empty timeline data gracefully' do
        # Given: Empty timeline data
        allow(mock_timeseries).to receive(:generate_timeseries).and_return([])

        # When: Finding timeline data for any issue
        result = timeline_display.send(:find_timeline_data, 'any-issue')

        # Then: Should return nil
        expect(result).to be_nil
      end
    end

    describe '#print_timeline' do
      let(:test_timeline_data) do
        {
          id: 'test-issue',
          title: 'Test Issue Title',
          team: 'Test Team',
          timeline: [
            {
              date: '2024-01-01T10:00:00Z',
              from_state: nil,
              to_state: 'Backlog'
            },
            {
              date: '2024-01-02T14:30:00Z',
              from_state: 'Backlog',
              to_state: 'Done'
            }
          ]
        }
      end

      it 'prints formatted timeline with header and events' do
        # Given: Timeline data with header info and events
        # When: Printing the timeline
        output = capture_stdout { timeline_display.send(:print_timeline, test_timeline_data) }

        # Then: Should display formatted header and events
        aggregate_failures do
          expect(output).to include('📈 TIMELINE FOR test-issue: Test Issue Title')
          expect(output).to include('Team: Test Team')
          expect(output).to include('=' * 80)

          # And: Should display timeline events
          expect(output).to include('2024-01-01 10:00 | Created → Backlog')
          expect(output).to include('2024-01-02 14:30 | Backlog → Done')
        end
      end

      it 'handles creation event correctly when from_state is nil' do
        # Given: Timeline data with creation event
        # When: Printing the timeline
        output = capture_stdout { timeline_display.send(:print_timeline, test_timeline_data) }

        # Then: Should show "Created" for initial transition
        expect(output).to include('Created → Backlog')
      end

      it 'handles state transitions correctly when from_state exists' do
        # Given: Timeline data with state transitions
        # When: Printing the timeline
        output = capture_stdout { timeline_display.send(:print_timeline, test_timeline_data) }

        # Then: Should show proper state transition
        expect(output).to include('Backlog → Done')
      end

      it 'formats dates correctly in local time format' do
        # Given: Timeline data with ISO timestamps
        # When: Printing the timeline
        output = capture_stdout { timeline_display.send(:print_timeline, test_timeline_data) }

        # Then: Should format dates in readable format
        expect(output).to include('2024-01-01 10:00')
        expect(output).to include('2024-01-02 14:30')
      end

      it 'handles empty timeline array gracefully' do
        # Given: Timeline data with empty timeline array
        empty_timeline = {
          id: 'test-issue',
          title: 'Test Issue Title',
          team: 'Test Team',
          timeline: []
        }

        # When: Printing the timeline
        output = capture_stdout { timeline_display.send(:print_timeline, empty_timeline) }

        # Then: Should display header but no timeline events
        aggregate_failures do
          expect(output).to include('📈 TIMELINE FOR test-issue')
          expect(output).to include('Team: Test Team')
          expect(output).not_to include('|')
        end
      end
    end

    private

    def setup_timeseries_mock
      allow(KanbanMetrics::Timeseries::TicketTimeseries).to receive(:new)
        .with(sample_issues)
        .and_return(mock_timeseries)
    end
  end
end
