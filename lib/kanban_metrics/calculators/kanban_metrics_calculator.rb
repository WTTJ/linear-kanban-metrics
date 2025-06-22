# frozen_string_literal: true

module KanbanMetrics
  module Calculators
    # Main metrics calculator that orchestrates all calculations
    class KanbanMetricsCalculator
      def initialize(issues)
        @issues = convert_to_domain_issues(issues)
      end

      def overall_metrics
        completed, in_progress, backlog = IssuePartitioner.partition(@issues)
        time_calculator = TimeMetricsCalculator.new(completed)

        {
          total_issues: @issues.size,
          completed_issues: completed.size,
          in_progress_issues: in_progress.size,
          backlog_issues: backlog.size,
          cycle_time: time_calculator.cycle_time_stats,
          lead_time: time_calculator.lead_time_stats,
          throughput: ThroughputCalculator.new(completed).stats,
          flow_efficiency: FlowEfficiencyCalculator.new(completed).calculate
        }
      end

      def team_metrics
        team_groups = group_issues_by_team
        team_groups.transform_values { |issues| calculate_team_stats(issues) }
      end

      private

      def convert_to_domain_issues(issues)
        issues.map do |issue|
          issue.is_a?(Domain::Issue) ? issue : Domain::Issue.new(issue)
        end
      end

      def group_issues_by_team
        @issues.group_by { |issue| issue.team_name || 'Unknown Team' }
      end

      def calculate_team_stats(team_issues)
        completed, in_progress, backlog = IssuePartitioner.partition(team_issues)
        time_calculator = TimeMetricsCalculator.new(completed)

        {
          total_issues: team_issues.size,
          completed_issues: completed.size,
          in_progress_issues: in_progress.size,
          backlog_issues: backlog.size,
          cycle_time: time_calculator.cycle_time_stats,
          lead_time: time_calculator.lead_time_stats,
          throughput: ThroughputCalculator.new(completed).stats[:total_completed]
        }
      end
    end
  end
end
