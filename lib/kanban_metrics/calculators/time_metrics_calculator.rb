# frozen_string_literal: true

require 'date'

module KanbanMetrics
  module Calculators
    # Calculates time-based metrics
    class TimeMetricsCalculator
      def initialize(issues)
        @issues = issues
      end

      def cycle_time_stats
        times = calculate_cycle_times
        build_time_stats(times)
      end

      def lead_time_stats
        times = calculate_lead_times
        build_time_stats(times)
      end

      private

      def calculate_cycle_times
        @issues.filter_map do |issue|
          started_at = find_start_time(issue)
          completed_at = issue['completedAt']
          next unless started_at && completed_at

          calculate_time_difference(started_at, completed_at)
        end
      end

      def calculate_lead_times
        @issues.filter_map do |issue|
          created_at = issue['createdAt']
          completed_at = issue['completedAt']
          next unless created_at && completed_at

          calculate_time_difference(created_at, completed_at)
        end
      end

      def find_start_time(issue)
        issue['startedAt'] || find_history_time(issue, 'started')
      end

      def find_history_time(issue, state_type)
        event = issue.dig('history', 'nodes')&.find do |e|
          e.dig('toState', 'type') == state_type
        end
        event&.dig('createdAt')
      end

      def calculate_time_difference(start_time, end_time)
        (DateTime.parse(end_time) - DateTime.parse(start_time)).to_f
      end

      def build_time_stats(times)
        {
          average: calculate_average(times),
          median: calculate_median(times),
          p95: calculate_percentile(times, 95)
        }
      end

      def calculate_average(arr)
        return 0 if arr.empty?

        (arr.sum.to_f / arr.size).round(2)
      end

      def calculate_median(arr)
        return 0 if arr.empty?

        sorted = arr.sort
        len = sorted.size
        if len.odd?
          sorted[len / 2].round(2)
        else
          ((sorted[(len / 2) - 1] + sorted[len / 2]) / 2.0).round(2)
        end
      end

      def calculate_percentile(arr, percentile)
        return 0 if arr.empty?

        sorted = arr.sort
        idx = (percentile / 100.0 * (sorted.size - 1)).round
        sorted[idx].round(2)
      end
    end
  end
end
