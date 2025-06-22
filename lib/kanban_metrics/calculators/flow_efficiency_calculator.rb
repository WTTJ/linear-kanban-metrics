# frozen_string_literal: true

require 'date'
require_relative '../domain/issue'
require_relative '../utils/timestamp_formatter'

module KanbanMetrics
  module Calculators
    # Calculates flow efficiency metrics
    #
    # Flow efficiency measures the percentage of time an issue spends in active work
    # states (started, unstarted) vs. total time in the system
    class FlowEfficiencyCalculator
      # State types considered as "active work"
      ACTIVE_STATE_TYPES = %w[started unstarted].freeze

      def initialize(issues)
        @issues = issues.map { |issue_data| ensure_domain_object(issue_data) }
      end

      def calculate
        return 0.0 if @issues.empty?

        total_efficiency = @issues.sum { |issue| calculate_issue_efficiency(issue) }
        ((total_efficiency / @issues.size) * 100).round(2)
      end

      private

      def ensure_domain_object(issue)
        issue.is_a?(Domain::Issue) ? issue : Domain::Issue.new(issue)
      end

      def calculate_issue_efficiency(issue)
        history_nodes = extract_history_nodes(issue)
        return 0.0 if history_nodes.empty?

        active_time, total_time = calculate_time_breakdown(history_nodes)
        return 0.0 if total_time.zero?

        active_time / total_time
      end

      def extract_history_nodes(issue)
        issue.raw_data.dig('history', 'nodes') || []
      end

      def calculate_time_breakdown(history_nodes)
        time_accumulator = TimeAccumulator.new

        history_nodes.each_cons(2) do |from_event, to_event|
          duration = calculate_event_duration(from_event, to_event)
          time_accumulator.add_duration(duration, active_state?(from_event))
        end

        time_accumulator.results
      end

      def calculate_event_duration(from_event, to_event)
        from_time = parse_timestamp(from_event['createdAt'])
        to_time = parse_timestamp(to_event['createdAt'])

        return 0.0 unless from_time && to_time

        (to_time - from_time).to_f
      end

      def parse_timestamp(timestamp_str)
        return nil unless timestamp_str

        DateTime.parse(timestamp_str)
      rescue StandardError
        nil
      end

      def active_state?(event)
        to_state_type = event.dig('toState', 'type')
        ACTIVE_STATE_TYPES.include?(to_state_type)
      end

      # Helper class to accumulate time calculations
      class TimeAccumulator
        attr_reader :active_time, :total_time

        def initialize
          @active_time = 0.0
          @total_time = 0.0
        end

        def add_duration(duration, is_active)
          @total_time += duration
          @active_time += duration if is_active
        end

        def results
          [@active_time, @total_time]
        end
      end
    end
  end
end
