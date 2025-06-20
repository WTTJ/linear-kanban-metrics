# frozen_string_literal: true

require 'spec_helper'

RSpec.describe KanbanMetrics::Timeseries::TimelineBuilder do
  subject(:timeline_builder) { described_class.new }

  describe '#build_timeline' do
    let(:issue_with_history) do
      {
        'id' => 'issue-1',
        'createdAt' => '2024-01-01T10:00:00Z',
        'history' => {
          'nodes' => [
            {
              'createdAt' => '2024-01-02T10:00:00Z',
              'fromState' => { 'name' => 'Backlog' },
              'toState' => { 'name' => 'In Progress' }
            },
            {
              'createdAt' => '2024-01-05T10:00:00Z',
              'fromState' => { 'name' => 'In Progress' },
              'toState' => { 'name' => 'Done' }
            }
          ]
        }
      }
    end

    let(:issue_without_history) do
      {
        'id' => 'issue-2',
        'createdAt' => '2024-01-01T10:00:00Z'
      }
    end

    let(:issue_with_empty_history) do
      {
        'id' => 'issue-3',
        'createdAt' => '2024-01-01T10:00:00Z',
        'history' => { 'nodes' => [] }
      }
    end

    context 'with issue containing history' do
      it 'returns array of timeline events with correct length' do
        # Given: An issue with creation date and history events
        # When: Building the timeline
        timeline = timeline_builder.build_timeline(issue_with_history)

        # Then: Should return array with creation event plus history events
        aggregate_failures 'timeline structure and length' do
          expect(timeline).to be_an(Array)
          expect(timeline.length).to eq(3) # creation + 2 history events
        end
      end

      it 'includes creation event with correct properties' do
        # Given: An issue with creation date
        # When: Building the timeline
        timeline = timeline_builder.build_timeline(issue_with_history)
        creation_event = timeline.first

        # Then: Should include properly formatted creation event
        aggregate_failures 'creation event properties' do
          expect(creation_event[:date]).to eq('2024-01-01T10:00:00Z')
          expect(creation_event[:from_state]).to be_nil
          expect(creation_event[:to_state]).to eq('created')
          expect(creation_event[:event_type]).to eq('created')
        end
      end

      it 'includes history events with correct state transitions' do
        # Given: An issue with history events
        # When: Building the timeline
        timeline = timeline_builder.build_timeline(issue_with_history)
        history_events = timeline[1..]

        # Then: Should include all history events with correct transitions
        aggregate_failures 'history events and state transitions' do
          expect(history_events.length).to eq(2)
          expect(history_events.first[:from_state]).to eq('Backlog')
          expect(history_events.first[:to_state]).to eq('In Progress')
          expect(history_events.last[:from_state]).to eq('In Progress')
          expect(history_events.last[:to_state]).to eq('Done')
        end
      end

      it 'sorts events chronologically' do
        # Given: An issue with events that may be out of order
        # When: Building the timeline
        timeline = timeline_builder.build_timeline(issue_with_history)
        dates = timeline.map { |event| DateTime.parse(event[:date]) }

        # Then: Should sort all events in chronological order
        expect(dates).to eq(dates.sort)
      end

      it 'includes correct event types for all events' do
        # Given: An issue with creation and history events
        # When: Building the timeline
        timeline = timeline_builder.build_timeline(issue_with_history)

        # Then: Should assign correct event types
        aggregate_failures 'event type assignments' do
          expect(timeline.first[:event_type]).to eq('created')
          expect(timeline[1][:event_type]).to eq('status_change')
          expect(timeline[2][:event_type]).to eq('status_change')
        end
      end
    end

    context 'with issue without history' do
      it 'returns only creation event' do
        # Given: An issue without any history data
        # When: Building the timeline
        timeline = timeline_builder.build_timeline(issue_without_history)

        # Then: Should return only the creation event
        aggregate_failures 'timeline with creation event only' do
          expect(timeline).to be_an(Array)
          expect(timeline.length).to eq(1)
          expect(timeline.first[:event_type]).to eq('created')
        end
      end
    end

    context 'with issue with empty history' do
      it 'returns only creation event' do
        # Given: An issue with empty history nodes
        # When: Building the timeline
        timeline = timeline_builder.build_timeline(issue_with_empty_history)

        # Then: Should return only the creation event
        aggregate_failures 'timeline with empty history handling' do
          expect(timeline).to be_an(Array)
          expect(timeline.length).to eq(1)
          expect(timeline.first[:event_type]).to eq('created')
        end
      end
    end

    context 'with malformed history events' do
      let(:issue_with_malformed_history) do
        {
          'id' => 'issue-4',
          'createdAt' => '2024-01-01T10:00:00Z',
          'history' => {
            'nodes' => [
              {
                'createdAt' => '2024-01-02T10:00:00Z',
                'fromState' => { 'name' => 'Backlog' },
                'toState' => { 'name' => 'In Progress' }
              },
              {
                'createdAt' => '2024-01-03T10:00:00Z',
                'fromState' => { 'name' => 'In Progress' }
                # Missing toState
              },
              {
                'createdAt' => '2024-01-04T10:00:00Z',
                'toState' => { 'name' => 'Done' }
              }
            ]
          }
        }
      end

      it 'filters out malformed events and keeps valid ones' do
        # Given: An issue with mixed valid and malformed history events
        # When: Building the timeline
        timeline = timeline_builder.build_timeline(issue_with_malformed_history)

        # Then: Should filter out malformed events and keep valid ones
        aggregate_failures 'malformed event filtering' do
          # Should have creation + 2 valid history events (skipping the malformed one)
          expect(timeline.length).to eq(3)
          expect(timeline.map { |e| e[:to_state] }).to eq(['created', 'In Progress', 'Done'])
        end
      end
    end

    context 'with out-of-order history events' do
      let(:issue_with_unordered_history) do
        {
          'id' => 'issue-5',
          'createdAt' => '2024-01-01T10:00:00Z',
          'history' => {
            'nodes' => [
              {
                'createdAt' => '2024-01-05T10:00:00Z',
                'fromState' => { 'name' => 'In Progress' },
                'toState' => { 'name' => 'Done' }
              },
              {
                'createdAt' => '2024-01-02T10:00:00Z',
                'fromState' => { 'name' => 'Backlog' },
                'toState' => { 'name' => 'In Progress' }
              }
            ]
          }
        }
      end

      it 'sorts events chronologically regardless of input order' do
        # Given: An issue with out-of-order history events
        # When: Building the timeline
        timeline = timeline_builder.build_timeline(issue_with_unordered_history)

        # Then: Should sort events chronologically and maintain correct sequence
        aggregate_failures 'chronological sorting and sequence validation' do
          dates = timeline.map { |event| DateTime.parse(event[:date]) }
          expect(dates).to eq(dates.sort)

          # Verify correct order of state transitions
          expect(timeline[0][:to_state]).to eq('created') # 2024-01-01
          expect(timeline[1][:to_state]).to eq('In Progress') # 2024-01-02
          expect(timeline[2][:to_state]).to eq('Done') # 2024-01-05
        end
      end
    end
  end

  describe 'private methods' do
    describe '#create_creation_event' do
      let(:issue) { { 'createdAt' => '2024-01-01T10:00:00Z' } }

      it 'creates properly formatted creation event' do
        # Given: An issue with creation timestamp
        # When: Creating a creation event
        event = timeline_builder.send(:create_creation_event, issue)

        # Then: Should return correctly formatted creation event
        expect(event).to eq({
                              date: '2024-01-01T10:00:00Z',
                              from_state: nil,
                              to_state: 'created',
                              event_type: 'created'
                            })
      end
    end

    describe '#extract_history_events' do
      let(:issue_with_history) do
        {
          'history' => {
            'nodes' => [
              {
                'createdAt' => '2024-01-02T10:00:00Z',
                'fromState' => { 'name' => 'Backlog' },
                'toState' => { 'name' => 'In Progress' }
              },
              {
                'createdAt' => '2024-01-03T10:00:00Z',
                'toState' => { 'name' => 'Done' }
              }
            ]
          }
        }
      end

      it 'extracts valid history events with correct properties' do
        # Given: An issue with valid history events
        # When: Extracting history events
        events = timeline_builder.send(:extract_history_events, issue_with_history)

        # Then: Should extract all valid events with correct state information
        aggregate_failures 'history event extraction and properties' do
          expect(events.length).to eq(2)
          expect(events.first[:from_state]).to eq('Backlog')
          expect(events.first[:to_state]).to eq('In Progress')
          expect(events.last[:from_state]).to be_nil
          expect(events.last[:to_state]).to eq('Done')
        end
      end

      it 'handles edge cases gracefully' do
        # Given: Various edge case scenarios
        # When: Extracting history events from different issue types
        # Then: Should handle all edge cases without errors
        aggregate_failures 'edge case handling' do
          # Issue without history
          events_no_history = timeline_builder.send(:extract_history_events, {})
          expect(events_no_history).to eq([])

          # Issue with empty history nodes
          issue_empty = { 'history' => { 'nodes' => [] } }
          events_empty = timeline_builder.send(:extract_history_events, issue_empty)
          expect(events_empty).to eq([])
        end
      end

      it 'filters out events without toState and sets correct event types' do
        # Given: An issue with mixed valid and invalid history events
        issue = {
          'history' => {
            'nodes' => [
              {
                'createdAt' => '2024-01-02T10:00:00Z',
                'fromState' => { 'name' => 'Backlog' }
                # Missing toState - should be filtered out
              },
              {
                'createdAt' => '2024-01-03T10:00:00Z',
                'toState' => { 'name' => 'Done' }
              }
            ]
          }
        }

        # When: Extracting history events
        events = timeline_builder.send(:extract_history_events, issue)

        # Then: Should filter invalid events and set correct properties for valid ones
        aggregate_failures 'event filtering and type assignment' do
          expect(events.length).to eq(1)
          expect(events.first[:to_state]).to eq('Done')

          # Verify all events have correct event type
          expect(events).to all(have_key(:event_type))
          expect(events.map { |e| e[:event_type] }).to all(eq('status_change'))
        end
      end
    end
  end

  describe 'error handling and edge cases' do
    it 'raises error when given nil issue' do
      # Given: A nil issue
      # When: Attempting to build timeline
      # Then: Should raise NoMethodError due to nil access
      expect { timeline_builder.build_timeline(nil) }.to raise_error(NoMethodError)
    end

    it 'handles issues with missing or nil createdAt gracefully' do
      # Given: Issues with missing or nil creation timestamps
      # When: Building timelines
      # Then: Should handle gracefully by returning empty timelines
      aggregate_failures 'missing createdAt handling' do
        # Issue without createdAt
        issue_no_created_at = { 'id' => 'test' }
        timeline_no_date = timeline_builder.build_timeline(issue_no_created_at)
        expect(timeline_no_date.length).to eq(0) # No events since createdAt is missing

        # Issue with nil createdAt
        issue_nil_created_at = { 'id' => 'test', 'createdAt' => nil }
        timeline_nil_date = timeline_builder.build_timeline(issue_nil_created_at)
        expect(timeline_nil_date.length).to eq(0) # No events since createdAt is nil
      end
    end
  end
end
