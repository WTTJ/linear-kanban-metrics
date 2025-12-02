# frozen_string_literal: true

module KanbanMetrics
  module Formatters
    # Handles Markdown formatting for kanban metrics data
    #
    # Provides comprehensive Markdown export functionality including:
    # - Overall metrics data in readable tables
    # - Team-specific metrics breakdown
    # - Teammate/assignee-specific metrics breakdown
    # - Timeseries analysis data
    # - Individual ticket details
    # - KPI definitions and explanations
    # - Robust error handling and data validation
    class MarkdownFormatter
      # KPI descriptions for user-friendly explanations
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

      # Generate Markdown directly without instantiation
      #
      # @param metrics [Hash] Overall metrics data
      # @param team_metrics [Hash, nil] Team-specific metrics
      # @param teammate_metrics [Hash, nil] Teammate/assignee-specific metrics
      # @param timeseries [Object, nil] Timeseries analysis object
      # @param issues [Array, nil] Array of issues for individual ticket data
      # @return [String] Generated Markdown content
      def self.generate(metrics, team_metrics: nil, teammate_metrics: nil, timeseries: nil, issues: nil)
        new(metrics, team_metrics, teammate_metrics, timeseries, issues).generate
      end

      # Initialize with metrics data
      #
      # @param metrics [Hash] Overall metrics data
      # @param team_metrics [Hash, nil] Team-specific metrics
      # @param teammate_metrics [Hash, nil] Teammate/assignee-specific metrics
      # @param timeseries [Object, nil] Timeseries analysis object
      # @param issues [Array, nil] Array of issues for individual ticket data
      # @raise [ArgumentError] if metrics is nil or invalid
      def initialize(metrics, team_metrics = nil, teammate_metrics = nil, timeseries = nil, issues = nil)
        validate_metrics(metrics)

        @metrics = metrics
        @team_metrics = team_metrics
        @teammate_metrics = teammate_metrics
        @timeseries = timeseries
        @issues = Array(issues)
      end

      # Generate Markdown content
      #
      # @return [String] Generated Markdown content
      def generate
        sections = []

        sections << build_header
        sections << build_summary_section
        sections << build_cycle_time_section
        sections << build_lead_time_section
        sections << build_throughput_section
        sections << build_team_metrics_section if should_include_team_metrics?
        sections << build_teammate_metrics_section if should_include_teammate_metrics?
        sections << build_timeseries_section if should_include_timeseries?
        sections << build_individual_tickets_section if should_include_individual_tickets?
        sections << build_kpi_definitions_section

        sections.compact.join("\n\n")
      rescue StandardError => e
        log_error("Failed to generate Markdown: #{e.message}")
        raise
      end

      private

      attr_reader :metrics, :team_metrics, :teammate_metrics, :timeseries, :issues

      # Input validation

      def validate_metrics(metrics)
        return if metrics.is_a?(Hash) && !metrics.empty?

        raise ArgumentError, 'Metrics must be a non-empty Hash'
      end

      # Section inclusion logic

      def should_include_team_metrics?
        team_metrics.is_a?(Hash) && !team_metrics.empty?
      end

      def should_include_teammate_metrics?
        teammate_metrics.is_a?(Hash) && !teammate_metrics.empty?
      end

      def should_include_timeseries?
        !timeseries.nil? && timeseries.respond_to?(:status_flow_analysis)
      end

      def should_include_individual_tickets?
        !issues.empty?
      end

      # Header section

      def build_header
        timestamp = Time.now.strftime('%Y-%m-%d %H:%M:%S')
        <<~MARKDOWN
          # 📊 Kanban Metrics Report

          > Generated on #{timestamp}
        MARKDOWN
      end

      # Summary section

      def build_summary_section
        <<~MARKDOWN
          ## 📈 Summary

          | Metric | Value | Description |
          |--------|-------|-------------|
          | Total Issues | #{safe_fetch(metrics, :total_issues) || 'N/A'} | #{KPI_DESCRIPTIONS[:total_issues]} |
          | Completed Issues | #{safe_fetch(metrics, :completed_issues) || 'N/A'} | #{KPI_DESCRIPTIONS[:completed_issues]} |
          | In Progress Issues | #{safe_fetch(metrics, :in_progress_issues) || 'N/A'} | #{KPI_DESCRIPTIONS[:in_progress_issues]} |
          | Backlog Issues | #{safe_fetch(metrics, :backlog_issues) || 'N/A'} | #{KPI_DESCRIPTIONS[:backlog_issues]} |
          | Flow Efficiency | #{format_percentage(safe_fetch(metrics, :flow_efficiency))} | #{KPI_DESCRIPTIONS[:flow_efficiency]} |
        MARKDOWN
      end

      # Cycle time section

      def build_cycle_time_section
        cycle_time = safe_fetch(metrics, :cycle_time)
        return nil unless cycle_time.is_a?(Hash)

        <<~MARKDOWN
          ## ⏱️ Cycle Time

          | Metric | Days | Description |
          |--------|------|-------------|
          | Average | #{safe_fetch(cycle_time, :average) || 'N/A'} | #{KPI_DESCRIPTIONS[:average_cycle_time]} |
          | Median | #{safe_fetch(cycle_time, :median) || 'N/A'} | #{KPI_DESCRIPTIONS[:median_cycle_time]} |
          | 95th Percentile | #{safe_fetch(cycle_time, :p95) || 'N/A'} | #{KPI_DESCRIPTIONS[:p95_cycle_time]} |
        MARKDOWN
      end

      # Lead time section

      def build_lead_time_section
        lead_time = safe_fetch(metrics, :lead_time)
        return nil unless lead_time.is_a?(Hash)

        <<~MARKDOWN
          ## 📏 Lead Time

          | Metric | Days | Description |
          |--------|------|-------------|
          | Average | #{safe_fetch(lead_time, :average) || 'N/A'} | #{KPI_DESCRIPTIONS[:average_lead_time]} |
          | Median | #{safe_fetch(lead_time, :median) || 'N/A'} | #{KPI_DESCRIPTIONS[:median_lead_time]} |
          | 95th Percentile | #{safe_fetch(lead_time, :p95) || 'N/A'} | #{KPI_DESCRIPTIONS[:p95_lead_time]} |
        MARKDOWN
      end

      # Throughput section

      def build_throughput_section
        throughput = safe_fetch(metrics, :throughput)
        return nil unless throughput.is_a?(Hash)

        <<~MARKDOWN
          ## 🚀 Throughput

          | Metric | Value | Description |
          |--------|-------|-------------|
          | Weekly Average | #{safe_fetch(throughput, :weekly_avg) || 'N/A'} | #{KPI_DESCRIPTIONS[:weekly_avg]} |
          | Total Completed | #{safe_fetch(throughput, :total_completed) || 'N/A'} | #{KPI_DESCRIPTIONS[:total_completed]} |
        MARKDOWN
      end

      # Team metrics section

      def build_team_metrics_section
        sections = ["## 👥 Team Metrics\n"]

        # Individual team tables
        team_metrics.sort.each do |team, stats|
          sections << build_team_detail_section(team, stats)
        end

        # Team comparison table
        sections << build_team_comparison_section

        sections.join("\n")
      end

      def build_team_detail_section(team, stats)
        cycle_time = safe_fetch(stats, :cycle_time)
        lead_time = safe_fetch(stats, :lead_time)

        <<~MARKDOWN
          ### 🏷️ #{team}

          | Metric | Value |
          |--------|-------|
          | Total Issues | #{safe_fetch(stats, :total_issues) || 'N/A'} |
          | Completed Issues | #{safe_fetch(stats, :completed_issues) || 'N/A'} |
          | In Progress Issues | #{safe_fetch(stats, :in_progress_issues) || 'N/A'} |
          | Backlog Issues | #{safe_fetch(stats, :backlog_issues) || 'N/A'} |
          | Avg Cycle Time | #{format_days(safe_fetch(cycle_time, :average))} |
          | Median Cycle Time | #{format_days(safe_fetch(cycle_time, :median))} |
          | Avg Lead Time | #{format_days(safe_fetch(lead_time, :average))} |
          | Median Lead Time | #{format_days(safe_fetch(lead_time, :median))} |
          | Throughput | #{format_throughput(safe_fetch(stats, :throughput))} |
        MARKDOWN
      end

      def build_team_comparison_section
        header = "### 📊 Team Comparison\n\n"
        table_header = "| Team | Total | Completed | In Progress | Backlog | Avg Cycle | Median Cycle | Avg Lead | Median Lead | Throughput |\n"
        table_separator = "|------|-------|-----------|-------------|---------|-----------|--------------|----------|-------------|------------|\n"

        rows = team_metrics.sort.map do |team, stats|
          build_comparison_row(team, stats)
        end

        header + table_header + table_separator + rows.join
      end

      def build_comparison_row(name, stats)
        cycle_time = safe_fetch(stats, :cycle_time)
        lead_time = safe_fetch(stats, :lead_time)

        "| #{name} " \
          "| #{safe_fetch(stats, :total_issues) || 'N/A'} " \
          "| #{safe_fetch(stats, :completed_issues) || 'N/A'} " \
          "| #{safe_fetch(stats, :in_progress_issues) || 'N/A'} " \
          "| #{safe_fetch(stats, :backlog_issues) || 'N/A'} " \
          "| #{safe_fetch(cycle_time, :average) || 'N/A'} " \
          "| #{safe_fetch(cycle_time, :median) || 'N/A'} " \
          "| #{safe_fetch(lead_time, :average) || 'N/A'} " \
          "| #{safe_fetch(lead_time, :median) || 'N/A'} " \
          "| #{format_throughput(safe_fetch(stats, :throughput))} |\n"
      end

      # Teammate metrics section

      def build_teammate_metrics_section
        sections = ["## 👤 Teammate Metrics\n"]

        # Individual teammate tables
        teammate_metrics.sort.each do |teammate, stats|
          sections << build_teammate_detail_section(teammate, stats)
        end

        # Teammate comparison table
        sections << build_teammate_comparison_section

        sections.join("\n")
      end

      def build_teammate_detail_section(teammate, stats)
        cycle_time = safe_fetch(stats, :cycle_time)
        lead_time = safe_fetch(stats, :lead_time)

        <<~MARKDOWN
          ### 🧑‍💻 #{teammate}

          | Metric | Value |
          |--------|-------|
          | Total Issues | #{safe_fetch(stats, :total_issues) || 'N/A'} |
          | Completed Issues | #{safe_fetch(stats, :completed_issues) || 'N/A'} |
          | In Progress Issues | #{safe_fetch(stats, :in_progress_issues) || 'N/A'} |
          | Backlog Issues | #{safe_fetch(stats, :backlog_issues) || 'N/A'} |
          | Avg Cycle Time | #{format_days(safe_fetch(cycle_time, :average))} |
          | Median Cycle Time | #{format_days(safe_fetch(cycle_time, :median))} |
          | Avg Lead Time | #{format_days(safe_fetch(lead_time, :average))} |
          | Median Lead Time | #{format_days(safe_fetch(lead_time, :median))} |
          | Throughput | #{format_throughput(safe_fetch(stats, :throughput))} |
        MARKDOWN
      end

      def build_teammate_comparison_section
        header = "### 📊 Teammate Comparison\n\n"
        table_header = "| Teammate | Total | Completed | In Progress | Backlog | Avg Cycle | Median Cycle | Avg Lead | Median Lead | Throughput |\n"
        table_separator = "|----------|-------|-----------|-------------|---------|-----------|--------------|----------|-------------|------------|\n"

        rows = teammate_metrics.sort.map do |teammate, stats|
          build_comparison_row(teammate, stats)
        end

        header + table_header + table_separator + rows.join
      end

      # Timeseries section

      def build_timeseries_section
        sections = ["## 📈 Timeseries Analysis\n"]

        sections << build_status_flow_section if timeseries.respond_to?(:status_flow_analysis)
        sections << build_time_in_status_section if timeseries.respond_to?(:average_time_in_status)

        sections.compact.join("\n")
      end

      def build_status_flow_section
        flow_data = timeseries.status_flow_analysis
        return nil unless flow_data.is_a?(Hash) && !flow_data.empty?

        header = "### 🔄 Status Flow Analysis\n\n"
        table_header = "| From Status | To Status | Count |\n"
        table_separator = "|-------------|-----------|-------|\n"

        rows = flow_data.first(10).map do |(from, to), count|
          "| #{from || 'Created'} | #{to} | #{count} |\n"
        end

        header + table_header + table_separator + rows.join
      rescue StandardError => e
        log_warning("Failed to build status flow section: #{e.message}")
        nil
      end

      def build_time_in_status_section
        time_data = timeseries.average_time_in_status
        return nil unless time_data.is_a?(Hash) && !time_data.empty?

        header = "### ⏱️ Average Time in Status\n\n"
        table_header = "| Status | Average Days |\n"
        table_separator = "|--------|-------------|\n"

        rows = time_data.sort_by { |_, days| -days.to_f }.map do |status, days|
          "| #{status} | #{format_days(days)} |\n"
        end

        header + table_header + table_separator + rows.join
      rescue StandardError => e
        log_warning("Failed to build time in status section: #{e.message}")
        nil
      end

      # Individual tickets section

      def build_individual_tickets_section
        header = "## 🎫 Individual Ticket Details\n\n"
        table_header = "| ID | Title | State | Team | Assignee | Cycle Time | Lead Time |\n"
        table_separator = "|----|-------|-------|------|----------|------------|----------|\n"

        rows = issues.first(100).filter_map do |issue_data|
          build_ticket_row(issue_data)
        end

        header + table_header + table_separator + rows.join
      end

      def build_ticket_row(issue_data)
        domain_issue = safely_convert_to_domain_issue(issue_data)
        return nil unless domain_issue

        "| #{domain_issue.identifier || 'N/A'} " \
          "| #{truncate_and_escape(domain_issue.title, 40)} " \
          "| #{domain_issue.state_name || 'N/A'} " \
          "| #{domain_issue.team_name || 'N/A'} " \
          "| #{domain_issue.assignee_name || 'N/A'} " \
          "| #{format_days(domain_issue.cycle_time_days)} " \
          "| #{format_days(domain_issue.lead_time_days)} |\n"
      rescue StandardError => e
        log_warning("Failed to build ticket row: #{e.message}")
        nil
      end

      # KPI definitions section

      def build_kpi_definitions_section
        <<~MARKDOWN
          ## 📚 KPI Definitions

          | KPI | Definition | What it tells you |
          |-----|------------|-------------------|
          | Cycle Time | Time from when work starts to completion | How efficient your team is at executing work |
          | Lead Time | Time from request/creation to delivery | How responsive you are to customer needs |
          | Throughput | Number of items completed per time period | Team productivity and delivery capacity |
          | Flow Efficiency | % of time spent on active work vs waiting | How much waste exists in your process |
          | WIP (Work in Progress) | Number of items currently being worked on | Process load and potential bottlenecks |
          | 95th Percentile | 95% of items complete faster than this | Worst-case scenario for delivery predictions |
        MARKDOWN
      end

      # Utility methods

      def safe_fetch(data, key)
        return nil unless data.respond_to?(:[])

        data[key]
      end

      def format_percentage(value)
        return 'N/A' if value.nil?

        "#{value}%"
      end

      def format_days(value)
        return 'N/A' if value.nil?

        "#{value} days"
      end

      def format_throughput(value)
        return 'N/A' if value.nil?

        if value.is_a?(Hash)
          safe_fetch(value, :total_completed) || safe_fetch(value, :total) || 'N/A'
        else
          value.to_s
        end
      end

      def truncate_and_escape(text, max_length = 40)
        return 'N/A' if text.nil? || text.to_s.empty?

        sanitized = text.to_s
                        .gsub(/\r?\n/, ' ')
                        .tr("\t", ' ')
                        .gsub(/\s+/, ' ')
                        .gsub('|', '\\|') # Escape pipe characters for Markdown tables
                        .strip

        return sanitized if sanitized.length <= max_length

        "#{sanitized[0, max_length - 3]}..."
      end

      def safely_convert_to_domain_issue(issue_data)
        return issue_data if issue_data.is_a?(Domain::Issue)
        return Domain::Issue.new(issue_data) if issue_data.respond_to?(:[])

        nil
      rescue StandardError => e
        log_warning("Failed to convert issue to Domain::Issue: #{e.message}")
        nil
      end

      def log_warning(message)
        return if ENV['QUIET'] || ENV['RAILS_ENV'] == 'test'

        warn "Warning: #{message}"
      end

      def log_error(message)
        return if ENV['QUIET'] || ENV['RAILS_ENV'] == 'test'

        warn "Error: #{message}"
      end
    end
  end
end
