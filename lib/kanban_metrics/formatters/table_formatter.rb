# frozen_string_literal: true

require 'terminal-table'

module KanbanMetrics
  module Formatters
    # Handles table formatting for console output
    class TableFormatter
      KPI_DESCRIPTIONS = {
        total_issues: 'Total number of issues in the dataset',
        completed_issues: 'Issues that have been finished/delivered',
        in_progress_issues: 'Issues currently being worked on',
        backlog_issues: 'Issues waiting to be started',
        flow_efficiency: 'Percentage of time spent on active work vs waiting',
        average_cycle_time: 'Average time from start to completion',
        median_cycle_time: '50% of items complete faster than this',
        p95_cycle_time: '95% of items complete faster than this',
        average_lead_time: 'Average time from creation to completion',
        median_lead_time: '50% of items delivered faster than this',
        p95_lead_time: '95% of items delivered faster than this',
        weekly_avg: 'Average items completed per week',
        total_completed: 'Total items delivered in time period'
      }.freeze

      def initialize(metrics, team_metrics = nil, issues = nil)
        @metrics = metrics
        @team_metrics = team_metrics
        @issues = issues
      end

      def print_summary
        table = build_summary_table
        puts "\n📈 SUMMARY"
        puts table
      end

      def print_cycle_time
        table = build_cycle_time_table
        puts "\n⏱️  CYCLE TIME"
        puts table
      end

      def print_lead_time
        table = build_lead_time_table
        puts "\n📏 LEAD TIME"
        puts table
      end

      def print_throughput
        table = build_throughput_table
        puts "\n🚀 THROUGHPUT"
        puts table
      end

      def print_team_metrics
        return unless team_metrics_available?

        print_individual_teams
        print_team_comparison
      end

      def print_kpi_definitions
        table = build_definitions_table
        puts "\n📚 KPI DEFINITIONS"
        puts '=' * 80
        puts table
      end

      def print_individual_tickets
        return unless @issues&.any?

        puts "\n🎫 INDIVIDUAL TICKET DETAILS"
        puts '=' * 80
        table = build_individual_tickets_table
        puts table
      end

      private

      def build_summary_table
        Terminal::Table.new do |tab|
          tab.headings = %w[Metric Value Description]
          tab.add_row ['Total Issues', @metrics[:total_issues], KPI_DESCRIPTIONS[:total_issues]]
          tab.add_row ['Completed Issues', @metrics[:completed_issues], KPI_DESCRIPTIONS[:completed_issues]]
          tab.add_row ['In Progress Issues', @metrics[:in_progress_issues], KPI_DESCRIPTIONS[:in_progress_issues]]
          tab.add_row ['Backlog Issues', @metrics[:backlog_issues], KPI_DESCRIPTIONS[:backlog_issues]]
          tab.add_row ['Flow Efficiency', "#{@metrics[:flow_efficiency]}%", KPI_DESCRIPTIONS[:flow_efficiency]]
        end
      end

      def build_cycle_time_table
        Terminal::Table.new do |tab|
          tab.headings = %w[Metric Days Description]
          tab.add_row ['Average Cycle Time', @metrics[:cycle_time][:average], KPI_DESCRIPTIONS[:average_cycle_time]]
          tab.add_row ['Median Cycle Time', @metrics[:cycle_time][:median], KPI_DESCRIPTIONS[:median_cycle_time]]
          tab.add_row ['95th Percentile', @metrics[:cycle_time][:p95], KPI_DESCRIPTIONS[:p95_cycle_time]]
        end
      end

      def build_lead_time_table
        Terminal::Table.new do |tab|
          tab.headings = %w[Metric Days Description]
          tab.add_row ['Average Lead Time', @metrics[:lead_time][:average], KPI_DESCRIPTIONS[:average_lead_time]]
          tab.add_row ['Median Lead Time', @metrics[:lead_time][:median], KPI_DESCRIPTIONS[:median_lead_time]]
          tab.add_row ['95th Percentile', @metrics[:lead_time][:p95], KPI_DESCRIPTIONS[:p95_lead_time]]
        end
      end

      def build_throughput_table
        Terminal::Table.new do |tab|
          tab.headings = %w[Metric Value Description]
          tab.add_row ['Weekly Average', @metrics[:throughput][:weekly_avg], KPI_DESCRIPTIONS[:weekly_avg]]
          tab.add_row ['Total Completed', @metrics[:throughput][:total_completed], KPI_DESCRIPTIONS[:total_completed]]
        end
      end

      def build_definitions_table
        Terminal::Table.new do |tab|
          tab.headings = ['KPI', 'Definition', 'What it tells you']
          tab.add_row ['Cycle Time', 'Time from when work starts to completion',
                       'How efficient your team is at executing work']
          tab.add_row ['Lead Time', 'Time from request/creation to delivery',
                       'How responsive you are to customer needs']
          tab.add_row ['Throughput', 'Number of items completed per time period',
                       'Team productivity and delivery capacity']
          tab.add_row ['Flow Efficiency', '% of time spent on active work vs waiting',
                       'How much waste exists in your process']
          tab.add_row ['WIP (Work in Progress)', 'Number of items currently being worked on',
                       'Process load and potential bottlenecks']
          tab.add_row ['95th Percentile', '95% of items complete faster than this',
                       'Worst-case scenario for delivery predictions']
        end
      end

      def team_metrics_available?
        !@team_metrics.nil? && !@team_metrics.empty?
      end

      def print_individual_teams
        puts "\n👥 TEAM METRICS"
        puts '=' * 80

        @team_metrics.sort.each do |team, stats|
          puts "\n🏷️  #{team.upcase}"
          puts build_team_table(stats)
        end
      end

      def print_team_comparison
        puts "\n📊 TEAM COMPARISON"
        puts build_team_comparison_table
      end

      def build_team_table(stats)
        Terminal::Table.new do |tab|
          tab.headings = %w[Metric Value Description]
          tab.add_row ['Total Issues', stats[:total_issues], KPI_DESCRIPTIONS[:total_issues]]
          tab.add_row ['Completed Issues', stats[:completed_issues], KPI_DESCRIPTIONS[:completed_issues]]
          tab.add_row ['In Progress Issues', stats[:in_progress_issues], KPI_DESCRIPTIONS[:in_progress_issues]]
          tab.add_row ['Backlog Issues', stats[:backlog_issues], KPI_DESCRIPTIONS[:backlog_issues]]
          tab.add_row ['Avg Cycle Time', "#{stats[:cycle_time][:average]} days", KPI_DESCRIPTIONS[:average_cycle_time]]
          tab.add_row ['Median Cycle Time', "#{stats[:cycle_time][:median]} days", KPI_DESCRIPTIONS[:median_cycle_time]]
          tab.add_row ['Avg Lead Time', "#{stats[:lead_time][:average]} days", KPI_DESCRIPTIONS[:average_lead_time]]
          tab.add_row ['Median Lead Time', "#{stats[:lead_time][:median]} days", KPI_DESCRIPTIONS[:median_lead_time]]
          tab.add_row ['Throughput', "#{stats[:throughput]} completed", KPI_DESCRIPTIONS[:total_completed]]
        end
      end

      def build_team_comparison_table
        Terminal::Table.new do |tab|
          tab.headings = [
            'Team', 'Total', 'Completed', 'In Progress', 'Backlog',
            'Avg Cycle', 'Median Cycle', 'Avg Lead', 'Median Lead', 'Throughput'
          ]
          @team_metrics.sort.each do |team, stats|
            tab.add_row [
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
      end

      def build_individual_tickets_table
        Terminal::Table.new do |tab|
          tab.headings = [
            'ID', 'Title', 'State', 'Created At', 'Completed At',
            'Cycle Time (days)', 'Lead Time (days)', 'Team'
          ]

          @issues.each do |issue_data|
            issue = ensure_domain_issue(issue_data)

            tab.add_row [
              issue.identifier || 'N/A',
              truncate_title(issue.title || 'N/A'),
              issue.state_name || 'N/A',
              Utils::TimestampFormatter.to_display(issue.created_at),
              Utils::TimestampFormatter.to_display(issue.completed_at),
              issue.cycle_time_days || 'N/A',
              issue.lead_time_days || 'N/A',
              issue.team_name || 'N/A'
            ]
          end
        end
      end

      def ensure_domain_issue(issue_data)
        return issue_data if issue_data.is_a?(Domain::Issue)

        Domain::Issue.new(issue_data)
      end

      def truncate_title(title, max_length = 30)
        return title if title.length <= max_length

        "#{title[0, max_length - 3]}..."
      end
    end
  end
end
