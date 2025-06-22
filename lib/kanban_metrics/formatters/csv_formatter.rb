# frozen_string_literal: true

require 'csv'

module KanbanMetrics
  module Formatters
    # Handles CSV formatting
    class CsvFormatter
      def initialize(metrics, team_metrics = nil, timeseries = nil, issues = nil)
        @metrics = metrics
        @team_metrics = team_metrics
        @timeseries = timeseries
        @issues = issues
      end

      def generate
        CSV.generate do |csv|
          add_overall_metrics(csv)
          add_team_metrics(csv) if @team_metrics
          add_timeseries_data(csv) if @timeseries
          add_individual_tickets(csv) if @issues && !@issues.empty?
        end
      end

      private

      def add_overall_metrics(csv)
        csv << %w[Metric Value Unit]
        csv << ['Total Issues', @metrics[:total_issues], 'count']
        csv << ['Completed Issues', @metrics[:completed_issues], 'count']
        csv << ['In Progress Issues', @metrics[:in_progress_issues], 'count']
        csv << ['Backlog Issues', @metrics[:backlog_issues], 'count']
        csv << ['Average Cycle Time', @metrics[:cycle_time][:average], 'days']
        csv << ['Median Cycle Time', @metrics[:cycle_time][:median], 'days']
        csv << ['95th Percentile Cycle Time', @metrics[:cycle_time][:p95], 'days']
        csv << ['Average Lead Time', @metrics[:lead_time][:average], 'days']
        csv << ['Median Lead Time', @metrics[:lead_time][:median], 'days']
        csv << ['95th Percentile Lead Time', @metrics[:lead_time][:p95], 'days']
        csv << ['Weekly Throughput Average', @metrics[:throughput][:weekly_avg], 'issues/week']
        csv << ['Total Completed', @metrics[:throughput][:total_completed], 'count']
        csv << ['Flow Efficiency', @metrics[:flow_efficiency], 'percentage']
      end

      def add_team_metrics(csv)
        csv << []
        csv << ['TEAM METRICS']
        csv << ['Team', 'Total Issues', 'Completed Issues', 'In Progress Issues', 'Backlog Issues', 'Avg Cycle Time',
                'Median Cycle Time', 'Avg Lead Time', 'Median Lead Time', 'Throughput']

        @team_metrics.sort.each do |team, stats|
          csv << [
            team,
            stats[:total_issues],
            stats[:completed_issues],
            stats[:in_progress_issues],
            stats[:backlog_issues],
            stats[:cycle_time][:average],
            stats[:cycle_time][:median],
            stats[:lead_time][:average],
            stats[:lead_time][:median],
            stats[:throughput]
          ]
        end
      end

      def add_timeseries_data(csv)
        csv << []
        csv << ['TIMESERIES ANALYSIS']
        add_status_transitions(csv)
        add_time_in_status(csv)
      end

      def add_status_transitions(csv)
        csv << []
        csv << ['STATUS TRANSITIONS']
        csv << %w[Transition Count]
        @timeseries.status_flow_analysis.each do |transition, count|
          csv << [transition, count]
        end
      end

      def add_time_in_status(csv)
        csv << []
        csv << ['AVERAGE TIME IN STATUS']
        csv << ['Status', 'Average Days']
        @timeseries.average_time_in_status.each do |status, days|
          csv << [status, days]
        end
      end

      def add_individual_tickets(csv)
        csv << []
        csv << ['INDIVIDUAL TICKETS']
        csv << ['ID', 'Identifier', 'Title', 'State', 'State Type', 'Team', 'Assignee', 'Priority', 'Estimate',
                'Created At', 'Updated At', 'Started At', 'Completed At', 'Archived At', 'Cycle Time (days)', 'Lead Time (days)']

        @issues.each do |issue_data|
          issue = ensure_domain_issue(issue_data)
          csv << [
            issue.id,
            issue.identifier,
            issue.title,
            issue.state_name,
            issue.state_type,
            issue.team_name,
            issue.assignee_name,
            issue.priority,
            issue.estimate,
            Utils::TimestampFormatter.to_iso(issue.created_at),
            Utils::TimestampFormatter.to_iso(issue.updated_at),
            Utils::TimestampFormatter.to_iso(issue.started_at),
            Utils::TimestampFormatter.to_iso(issue.completed_at),
            Utils::TimestampFormatter.to_iso(issue.archived_at),
            issue.cycle_time_days,
            issue.lead_time_days
          ]
        end
      end

      def ensure_domain_issue(issue_data)
        return issue_data if issue_data.is_a?(Domain::Issue)

        Domain::Issue.new(issue_data)
      end
    end
  end
end
