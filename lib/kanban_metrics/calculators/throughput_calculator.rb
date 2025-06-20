# frozen_string_literal: true

require 'date'

module KanbanMetrics
  module Calculators
    # Calculates throughput metrics
    class ThroughputCalculator
      def initialize(completed_issues)
        @completed_issues = completed_issues
      end

      def stats
        return default_stats if @completed_issues.empty?

        weekly_counts = calculate_weekly_counts
        {
          weekly_avg: calculate_average(weekly_counts),
          total_completed: @completed_issues.size
        }
      end

      private

      def default_stats
        { weekly_avg: 0, total_completed: 0 }
      end

      def calculate_weekly_counts
        weeks = group_by_week
        weeks.values.map(&:size)
      end

      def group_by_week
        @completed_issues.group_by do |issue|
          Date.parse(issue['completedAt']).strftime('%Y-W%U')
        end
      end

      def calculate_average(arr)
        return 0 if arr.empty?

        (arr.sum.to_f / arr.size).round(2)
      end
    end
  end
end
