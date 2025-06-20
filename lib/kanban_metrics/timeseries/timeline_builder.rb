# frozen_string_literal: true

require 'date'

module KanbanMetrics
  module Timeseries
    # Builds timeline events for issues
    class TimelineBuilder
      def build_timeline(issue)
        events = []
        events << create_creation_event(issue)
        events.concat(extract_history_events(issue))
        events.compact! # Remove nil events
        events.reject! { |event| event[:date].nil? } # Remove events with nil dates
        events.sort_by { |event| DateTime.parse(event[:date]) }
      end

      private

      def create_creation_event(issue)
        return nil unless issue['createdAt']

        {
          date: issue['createdAt'],
          from_state: nil,
          to_state: 'created',
          event_type: 'created'
        }
      end

      def extract_history_events(issue)
        history_nodes = issue.dig('history', 'nodes') || []

        history_nodes.filter_map do |event|
          next unless event['toState']

          {
            date: event['createdAt'],
            from_state: event.dig('fromState', 'name'),
            to_state: event.dig('toState', 'name'),
            event_type: 'status_change'
          }
        end
      end
    end
  end
end
