# frozen_string_literal: true

require 'date'

module KanbanMetrics
  module Timeseries
    # Analyzes timeseries data
    class TimeseriesAnalyzer
      def initialize(issues)
        @issues = issues
        @timeline_builder = TimelineBuilder.new
      end

      def status_flow_analysis
        transitions = collect_transitions
        transitions.sort_by { |_, count| -count }.to_h
      end

      def average_time_in_status
        status_durations = collect_status_durations
        status_durations.transform_values { |durations| calculate_average(durations) }
      end

      def daily_status_counts
        events = collect_all_events
        events_by_date = group_events_by_date(events)
        events_by_date.transform_values { |daily_events| count_by_status(daily_events) }
      end

      private

      def collect_transitions
        transitions = Hash.new(0)

        @issues.each do |issue|
          timeline = @timeline_builder.build_timeline(issue)
          timeline.each_cons(2) do |from_event, to_event|
            transition_key = "#{from_event[:to_state]} → #{to_event[:to_state]}"
            transitions[transition_key] += 1
          end
        end

        transitions
      end

      def collect_status_durations
        status_durations = Hash.new { |h, k| h[k] = [] }

        @issues.each do |issue|
          timeline = @timeline_builder.build_timeline(issue)
          timeline.each_cons(2) do |current, next_event|
            duration = calculate_days_between(current[:date], next_event[:date])
            status_durations[current[:to_state]] << duration
          end
        end

        status_durations
      end

      def collect_all_events
        events = []

        @issues.each do |issue|
          timeline = @timeline_builder.build_timeline(issue)
          timeline.each do |event|
            events << {
              issue_id: issue['identifier'],
              date: event[:date],
              to_state: event[:to_state],
              event_type: event[:event_type]
            }
          end
        end

        events.sort_by { |event| DateTime.parse(event[:date]) }
      end

      def group_events_by_date(events)
        events.group_by { |event| Date.parse(event[:date]) }.sort.to_h
      end

      def count_by_status(events)
        events.group_by { |event| event[:to_state] }.transform_values(&:count)
      end

      def calculate_days_between(start_date, end_date)
        (Date.parse(end_date) - Date.parse(start_date)).to_f
      end

      def calculate_average(durations)
        return 0 if durations.empty?

        (durations.sum / durations.size).round(2)
      end
    end

    # Main timeseries class
    class TicketTimeseries < TimeseriesAnalyzer
      def generate_timeseries
        @issues.map do |issue|
          {
            id: issue['identifier'],
            title: issue['title'],
            team: issue.dig('team', 'name'),
            timeline: @timeline_builder.build_timeline(issue)
          }
        end
      end
    end
  end
end
