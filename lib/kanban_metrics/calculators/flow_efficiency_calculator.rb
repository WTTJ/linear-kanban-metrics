# frozen_string_literal: true

require 'date'

module KanbanMetrics
  module Calculators
    # Calculates flow efficiency metrics
    class FlowEfficiencyCalculator
      def initialize(issues)
        @issues = issues
      end

      def calculate
        return 0.0 if @issues.empty?

        total_efficiency = @issues.sum { |issue| calculate_issue_efficiency(issue) }
        ((total_efficiency / @issues.size) * 100).round(2)
      end

      private

      def calculate_issue_efficiency(issue)
        history = issue.dig('history', 'nodes') || []
        return 0.0 if history.empty?

        active_time, total_time = calculate_times(history)
        total_time.zero? ? 0.0 : active_time / total_time
      end

      def calculate_times(history)
        active_time = 0
        total_time = 0

        history.each_cons(2) do |from_event, to_event|
          duration = calculate_duration(from_event, to_event)
          total_time += duration
          active_time += duration if active_state?(from_event)
        end

        [active_time, total_time]
      end

      def calculate_duration(from_event, to_event)
        from_time = DateTime.parse(from_event['createdAt'])
        to_time = DateTime.parse(to_event['createdAt'])
        (to_time - from_time).to_f
      end

      def active_state?(event)
        to_state_type = event.dig('toState', 'type')
        %w[started unstarted].include?(to_state_type)
      end
    end
  end
end
