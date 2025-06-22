# frozen_string_literal: true

module KanbanMetrics
  module Calculators
    # Main metrics calculator that orchestrates all calculations
    #
    # This class serves as the main entry point for calculating kanban metrics
    # from a collection of issues. It handles both overall metrics and per-team breakdowns.
    class KanbanMetricsCalculator
      # Default team name for issues without team information
      DEFAULT_TEAM_NAME = 'Unknown Team'

      # Initialize calculator with issue data
      #
      # @param issues [Array] Collection of issue data (raw hashes or Domain::Issue objects)
      def initialize(issues)
        @issues = convert_to_domain_issues(Array(issues))
      end

      # Calculate overall metrics across all issues
      #
      # @return [Hash] Complete metrics including counts, cycle time, lead time, throughput, and flow efficiency
      def overall_metrics
        return empty_metrics if @issues.empty?

        calculate_metrics_for_issues(@issues, include_full_throughput: true)
      end

      # Calculate metrics grouped by team
      #
      # @return [Hash] Team names as keys, metrics as values
      def team_metrics
        return {} if @issues.empty?

        team_groups = group_issues_by_team
        team_groups.transform_values { |team_issues| calculate_metrics_for_issues(team_issues) }
      end

      private

      # Convert input to Domain::Issue objects
      #
      # @param issues [Array] Raw issue data
      # @return [Array<Domain::Issue>] Normalized issue objects
      def convert_to_domain_issues(issues)
        issues.map do |issue|
          issue.is_a?(Domain::Issue) ? issue : Domain::Issue.new(issue)
        end
      end

      # Group issues by team name
      #
      # @return [Hash] Team names as keys, arrays of issues as values
      def group_issues_by_team
        @issues.group_by { |issue| issue.team_name || DEFAULT_TEAM_NAME }
      end

      # Calculate metrics for a collection of issues
      #
      # @param issues [Array<Domain::Issue>] Issues to calculate metrics for
      # @param include_full_throughput [Boolean] Whether to include full throughput stats or just count
      # @return [Hash] Calculated metrics
      def calculate_metrics_for_issues(issues, include_full_throughput: false)
        partitioned = IssuePartitioner.partition(issues)
        completed, in_progress, backlog = partitioned

        metrics = build_base_metrics(issues, completed, in_progress, backlog)

        if completed.any?
          metrics.merge!(calculate_time_based_metrics(completed))
          metrics[:throughput] = calculate_throughput_metrics(completed, include_full_throughput)
          metrics[:flow_efficiency] = FlowEfficiencyCalculator.new(completed).calculate
        else
          metrics.merge!(empty_time_based_metrics)
        end

        metrics
      end

      # Build base count metrics
      #
      # @param issues [Array] All issues
      # @param completed [Array] Completed issues
      # @param in_progress [Array] In progress issues
      # @param backlog [Array] Backlog issues
      # @return [Hash] Base metrics
      def build_base_metrics(issues, completed, in_progress, backlog)
        {
          total_issues: issues.size,
          completed_issues: completed.size,
          in_progress_issues: in_progress.size,
          backlog_issues: backlog.size
        }
      end

      # Calculate time-based metrics for completed issues
      #
      # @param completed_issues [Array<Domain::Issue>] Completed issues
      # @return [Hash] Time metrics
      def calculate_time_based_metrics(completed_issues)
        time_calculator = TimeMetricsCalculator.new(completed_issues)
        {
          cycle_time: time_calculator.cycle_time_stats,
          lead_time: time_calculator.lead_time_stats
        }
      end

      # Calculate throughput metrics
      #
      # @param completed_issues [Array<Domain::Issue>] Completed issues
      # @param include_full_stats [Boolean] Whether to return full stats or just total
      # @return [Hash, Integer] Throughput data
      def calculate_throughput_metrics(completed_issues, include_full_stats)
        throughput_stats = ThroughputCalculator.new(completed_issues).stats
        include_full_stats ? throughput_stats : throughput_stats[:total_completed]
      end

      # Return empty metrics structure
      #
      # @return [Hash] Empty metrics with zero values
      def empty_metrics
        {
          total_issues: 0,
          completed_issues: 0,
          in_progress_issues: 0,
          backlog_issues: 0
        }.merge(empty_time_based_metrics)
      end

      # Return empty time-based metrics
      #
      # @return [Hash] Empty time metrics
      def empty_time_based_metrics
        {
          cycle_time: { average: 0.0, median: 0.0, percentile_95: 0.0 },
          lead_time: { average: 0.0, median: 0.0, percentile_95: 0.0 },
          throughput: { weekly_avg: 0.0, total_completed: 0 },
          flow_efficiency: 0.0
        }
      end
    end
  end
end
