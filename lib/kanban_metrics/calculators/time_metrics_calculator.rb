# frozen_string_literal: true

require 'date'

module KanbanMetrics
  module Calculators
    # Calculates time-based metrics
    class TimeMetricsCalculator
      def initialize(issues)
        @issues = issues.is_a?(Array) ? convert_to_domain_issues(issues) : issues
      end

      def cycle_time_stats
        times = @issues.filter_map(&:cycle_time_days).compact
        build_time_stats(times)
      end

      def lead_time_stats
        times = @issues.filter_map(&:lead_time_days).compact
        build_time_stats(times)
      end

      # Calculate cycle time for a single issue
      def cycle_time_for_issue(issue_data)
        issue = ensure_domain_issue(issue_data)
        issue.cycle_time_days
      end

      # Calculate lead time for a single issue
      def lead_time_for_issue(issue_data)
        issue = ensure_domain_issue(issue_data)
        issue.lead_time_days
      end

      private

      def convert_to_domain_issues(raw_issues)
        raw_issues.map { |issue_data| Domain::Issue.new(issue_data) }
      end

      def ensure_domain_issue(issue_data)
        return issue_data if issue_data.is_a?(Domain::Issue)

        Domain::Issue.new(issue_data)
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
