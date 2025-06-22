# frozen_string_literal: true

require 'json'

module KanbanMetrics
  module Formatters
    # Handles JSON formatting
    class JsonFormatter
      def initialize(metrics, team_metrics = nil, timeseries = nil, issues = nil)
        @metrics = metrics
        @team_metrics = team_metrics
        @timeseries = timeseries
        @issues = issues
      end

      def generate
        output = { overall_metrics: @metrics }
        output[:team_metrics] = @team_metrics if @team_metrics
        output[:timeseries] = build_timeseries_data if @timeseries
        output[:individual_tickets] = build_individual_tickets_data if @issues && !@issues.empty?
        JSON.pretty_generate(output)
      end

      private

      def build_timeseries_data
        return {} unless @timeseries

        {
          status_flow_analysis: @timeseries.status_flow_analysis,
          average_time_in_status: @timeseries.average_time_in_status,
          daily_status_counts: @timeseries.daily_status_counts
        }
      end

      def build_individual_tickets_data
        return [] unless @issues

        @issues.map do |issue_data|
          issue = ensure_domain_issue(issue_data)

          {
            id: issue.id,
            identifier: issue.identifier,
            title: issue.title,
            state: {
              name: issue.state_name,
              type: issue.state_type
            },
            team: issue.team_name,
            assignee: issue.assignee_name,
            priority: issue.priority,
            estimate: issue.estimate,
            createdAt: Utils::TimestampFormatter.to_iso(issue.created_at),
            updatedAt: Utils::TimestampFormatter.to_iso(issue.updated_at),
            startedAt: Utils::TimestampFormatter.to_iso(issue.started_at),
            completedAt: Utils::TimestampFormatter.to_iso(issue.completed_at),
            archivedAt: Utils::TimestampFormatter.to_iso(issue.archived_at),
            cycle_time_days: issue.cycle_time_days,
            lead_time_days: issue.lead_time_days
          }
        end
      end

      def ensure_domain_issue(issue_data)
        return issue_data if issue_data.is_a?(Domain::Issue)

        Domain::Issue.new(issue_data)
      end
    end
  end
end
