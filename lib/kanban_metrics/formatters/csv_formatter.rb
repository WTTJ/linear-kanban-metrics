# frozen_string_literal: true

require 'csv'

module KanbanMetrics
  module Formatters
    # Handles CSV formatting for kanban metrics data
    #
    # Provides comprehensive CSV export functionality including:
    # - Overall metrics summary
    # - Team-specific metrics breakdown
    # - Timeseries analysis data
    # - Individual ticket details
    # - Robust error handling and data validation
    #
    # rubocop:disable Metrics/ClassLength
    class CsvFormatter
      # CSV section headers for better organization
      SECTION_HEADERS = {
        team_metrics: 'TEAM METRICS',
        timeseries: 'TIMESERIES ANALYSIS',
        status_transitions: 'STATUS TRANSITIONS',
        time_in_status: 'AVERAGE TIME IN STATUS',
        individual_tickets: 'INDIVIDUAL TICKETS'
      }.freeze

      # Generate CSV directly without instantiation
      #
      # @param metrics [Hash] Overall metrics data
      # @param team_metrics [Hash, nil] Team-specific metrics
      # @param timeseries [Object, nil] Timeseries analysis object
      # @param issues [Array, nil] Array of issues for individual ticket data
      # @return [String] Generated CSV content
      def self.generate(metrics, team_metrics: nil, timeseries: nil, issues: nil)
        new(metrics, team_metrics, timeseries, issues).generate
      end

      # Initialize with metrics data
      #
      # @param metrics [Hash] Overall metrics data
      # @param team_metrics [Hash, nil] Team-specific metrics
      # @param timeseries [Object, nil] Timeseries analysis object
      # @param issues [Array, nil] Array of issues for individual ticket data
      # @raise [ArgumentError] if metrics is nil or invalid
      def initialize(metrics, team_metrics = nil, timeseries = nil, issues = nil)
        validate_metrics(metrics)

        @metrics = metrics
        @team_metrics = team_metrics
        @timeseries = timeseries
        @issues = Array(issues) # Ensure it's always an array
      end

      # Generate CSV content
      #
      # @return [String] Generated CSV content
      def generate
        CSV.generate do |csv|
          add_overall_metrics(csv)
          add_team_metrics(csv) if should_include_team_metrics?
          add_timeseries_data(csv) if should_include_timeseries?
          add_individual_tickets(csv) if should_include_individual_tickets?
        end
      rescue StandardError => e
        log_error("Failed to generate CSV: #{e.message}")
        raise
      end

      private

      attr_reader :metrics, :team_metrics, :timeseries, :issues

      # Input validation

      # @param metrics [Object] Metrics data to validate
      # @raise [ArgumentError] if metrics is invalid
      def validate_metrics(metrics)
        return if metrics.is_a?(Hash) && !metrics.empty?

        raise ArgumentError, 'Metrics must be a non-empty Hash'
      end

      # Section inclusion logic

      # @return [Boolean] True if team metrics should be included
      def should_include_team_metrics?
        team_metrics.is_a?(Hash) && !team_metrics.empty?
      end

      # @return [Boolean] True if timeseries data should be included
      def should_include_timeseries?
        !timeseries.nil? && timeseries.respond_to?(:status_flow_analysis)
      end

      # @return [Boolean] True if individual tickets should be included
      def should_include_individual_tickets?
        !issues.empty?
      end

      # CSV content generation methods

      # Add overall metrics section to CSV
      #
      # @param csv [CSV] CSV object to write to
      def add_overall_metrics(csv)
        csv << %w[Metric Value Unit]

        safe_add_metric(csv, 'Total Issues', metrics, :total_issues, 'count')
        safe_add_metric(csv, 'Completed Issues', metrics, :completed_issues, 'count')
        safe_add_metric(csv, 'In Progress Issues', metrics, :in_progress_issues, 'count')
        safe_add_metric(csv, 'Backlog Issues', metrics, :backlog_issues, 'count')

        add_time_metrics(csv, 'Cycle Time', :cycle_time)
        add_time_metrics(csv, 'Lead Time', :lead_time)

        add_throughput_metrics(csv)
        safe_add_metric(csv, 'Flow Efficiency', metrics, :flow_efficiency, 'percentage')
      end

      # Add time-based metrics (cycle time, lead time) to CSV
      #
      # @param csv [CSV] CSV object to write to
      # @param metric_name [String] Name of the metric
      # @param metric_key [Symbol] Key for the metric in the data
      def add_time_metrics(csv, metric_name, metric_key)
        time_data = safe_fetch_nested(metrics, metric_key)
        return unless time_data.is_a?(Hash)

        safe_add_metric(csv, "Average #{metric_name}", time_data, :average, 'days')
        safe_add_metric(csv, "Median #{metric_name}", time_data, :median, 'days')
        safe_add_metric(csv, "95th Percentile #{metric_name}", time_data, :p95, 'days')
      end

      # Add throughput metrics to CSV
      #
      # @param csv [CSV] CSV object to write to
      def add_throughput_metrics(csv)
        throughput_data = safe_fetch_nested(metrics, :throughput)
        return unless throughput_data.is_a?(Hash)

        safe_add_metric(csv, 'Weekly Throughput Average', throughput_data, :weekly_avg, 'issues/week')
        safe_add_metric(csv, 'Total Completed', throughput_data, :total_completed, 'count')
      end

      # Safely add a metric row to CSV
      #
      # @param csv [CSV] CSV object to write to
      # @param label [String] Metric label
      # @param data [Hash, Object] Data source (can be metrics hash or nested hash)
      # @param key [Symbol, nil] Key to fetch from data (optional)
      # @param unit [String] Unit of measurement
      def safe_add_metric(csv, label, data, key = nil, unit = 'count')
        value = if key.nil?
                  data
                elsif data.respond_to?(:[])
                  data[key]
                end
        csv << [label, format_metric_value(value), unit]
      rescue StandardError => e
        log_warning("Failed to add metric '#{label}': #{e.message}")
        csv << [label, 'N/A', unit]
      end

      # Add team metrics section to CSV
      #
      # @param csv [CSV] CSV object to write to
      def add_team_metrics(csv)
        add_section_separator(csv, SECTION_HEADERS[:team_metrics])

        add_team_metrics_header(csv)
        add_team_metrics_data(csv)
      end

      # Add team metrics header row
      #
      # @param csv [CSV] CSV object to write to
      def add_team_metrics_header(csv)
        csv << ['Team', 'Total Issues', 'Completed Issues', 'In Progress Issues', 'Backlog Issues',
                'Avg Cycle Time', 'Median Cycle Time', 'Avg Lead Time', 'Median Lead Time', 'Throughput']
      end

      # Add team metrics data rows
      #
      # @param csv [CSV] CSV object to write to
      def add_team_metrics_data(csv)
        sorted_teams = team_metrics.sort_by { |team_name, _| team_name.to_s }

        sorted_teams.each do |team_name, team_stats|
          add_team_row(csv, team_name, team_stats)
        end
      end

      # Add a single team's metrics row
      #
      # @param csv [CSV] CSV object to write to
      # @param team_name [String] Name of the team
      # @param team_stats [Hash] Team statistics
      def add_team_row(csv, team_name, team_stats)
        csv << [
          team_name,
          safe_fetch_nested(team_stats, :total_issues),
          safe_fetch_nested(team_stats, :completed_issues),
          safe_fetch_nested(team_stats, :in_progress_issues),
          safe_fetch_nested(team_stats, :backlog_issues),
          safe_fetch_nested(team_stats, :cycle_time, :average),
          safe_fetch_nested(team_stats, :cycle_time, :median),
          safe_fetch_nested(team_stats, :lead_time, :average),
          safe_fetch_nested(team_stats, :lead_time, :median),
          safe_fetch_nested(team_stats, :throughput)
        ].map { |value| format_metric_value(value) }
      rescue StandardError => e
        log_warning("Failed to add team row for '#{team_name}': #{e.message}")
        csv << ([team_name] + (['N/A'] * 9))
      end

      # Add timeseries analysis section to CSV
      #
      # @param csv [CSV] CSV object to write to
      def add_timeseries_data(csv)
        add_section_separator(csv, SECTION_HEADERS[:timeseries])
        add_status_transitions(csv)
        add_time_in_status(csv)
      end

      # Add status transitions subsection
      #
      # @param csv [CSV] CSV object to write to
      def add_status_transitions(csv)
        return unless timeseries.respond_to?(:status_flow_analysis)

        add_section_separator(csv, SECTION_HEADERS[:status_transitions])
        csv << %w[Transition Count]

        safely_iterate_timeseries_data(csv, :status_flow_analysis) do |transition, count|
          csv << [transition, format_metric_value(count)]
        end
      end

      # Add time in status subsection
      #
      # @param csv [CSV] CSV object to write to
      def add_time_in_status(csv)
        return unless timeseries.respond_to?(:average_time_in_status)

        add_section_separator(csv, SECTION_HEADERS[:time_in_status])
        csv << ['Status', 'Average Days']

        safely_iterate_timeseries_data(csv, :average_time_in_status) do |status, days|
          csv << [status, format_metric_value(days)]
        end
      end

      # Safely iterate over timeseries data
      #
      # @param csv [CSV] CSV object to write to
      # @param method_name [Symbol] Method to call on timeseries object
      # @yield [key, value] Block to execute for each data point
      def safely_iterate_timeseries_data(csv, method_name, &block)
        data = timeseries.public_send(method_name)
        return unless data.respond_to?(:each)

        data.each(&block)
      rescue StandardError => e
        log_warning("Failed to iterate #{method_name} data: #{e.message}")
        csv << ['Error loading data', 'N/A']
      end

      # Add individual tickets section to CSV
      #
      # @param csv [CSV] CSV object to write to
      def add_individual_tickets(csv)
        add_section_separator(csv, SECTION_HEADERS[:individual_tickets])
        add_ticket_headers(csv)
        add_ticket_data(csv)
      end

      # Add ticket headers row
      #
      # @param csv [CSV] CSV object to write to
      def add_ticket_headers(csv)
        csv << ['ID', 'Identifier', 'Title', 'State', 'State Type', 'Team', 'Assignee', 'Priority', 'Estimate',
                'Created At', 'Updated At', 'Started At', 'Completed At', 'Archived At', 'Cycle Time (days)', 'Lead Time (days)']
      end

      # Add ticket data rows
      #
      # @param csv [CSV] CSV object to write to
      def add_ticket_data(csv)
        issues.each do |issue_data|
          add_individual_ticket_row(csv, issue_data)
        end
      end

      # Add a single ticket row
      #
      # @param csv [CSV] CSV object to write to
      # @param issue_data [Object] Issue data (Domain::Issue or Hash)
      def add_individual_ticket_row(csv, issue_data)
        domain_issue = safely_convert_to_domain_issue(issue_data)
        return unless domain_issue

        csv << [
          domain_issue.id,
          domain_issue.identifier,
          truncate_title(domain_issue.title),
          domain_issue.state_name,
          domain_issue.state_type,
          domain_issue.team_name,
          domain_issue.assignee_name,
          domain_issue.priority,
          format_metric_value(domain_issue.estimate),
          format_timestamp(domain_issue.created_at),
          format_timestamp(domain_issue.updated_at),
          format_timestamp(domain_issue.started_at, use_nil_for_missing: true),
          format_timestamp(domain_issue.completed_at, use_nil_for_missing: true),
          format_timestamp(domain_issue.archived_at, use_nil_for_missing: true),
          format_metric_value(domain_issue.cycle_time_days, use_nil_for_missing: true),
          format_metric_value(domain_issue.lead_time_days, use_nil_for_missing: true)
        ]
      rescue StandardError => e
        log_warning("Failed to add ticket row: #{e.message}")
        csv << (['Error', 'N/A'] + (['N/A'] * 14))
      end

      # Data conversion and formatting utilities

      # Safely convert issue data to Domain::Issue
      #
      # @param issue_data [Object] Issue data to convert
      # @return [Domain::Issue, nil] Domain::Issue or nil if conversion fails
      def safely_convert_to_domain_issue(issue_data)
        return issue_data if issue_data.is_a?(Domain::Issue)
        return Domain::Issue.new(issue_data) if issue_data.respond_to?(:[])

        log_warning("Invalid issue data type: #{issue_data.class}")
        nil
      rescue StandardError => e
        log_warning("Failed to convert issue to Domain::Issue: #{e.message}")
        nil
      end

      # Safely fetch nested data from hash-like objects
      #
      # @param data [Object] Data source
      # @param *keys [Symbol] Keys to navigate through
      # @return [Object, nil] Found value or nil
      def safe_fetch_nested(data, *keys)
        return nil unless data.respond_to?(:[])

        keys.reduce(data) do |current, key|
          return nil unless current.respond_to?(:[])

          current[key]
        end
      end

      # Format metric values for CSV output
      #
      # @param value [Object] Value to format
      # @param use_nil_for_missing [Boolean] Whether to use nil instead of 'N/A' for nil values
      # @return [String, nil] Formatted value
      def format_metric_value(value, use_nil_for_missing: false)
        return use_nil_for_missing ? nil : 'N/A' if value.nil?

        case value
        when Float
          # Remove unnecessary decimal places for whole numbers
          value == value.to_i ? value.to_i.to_s : value.round(2).to_s
        else
          value.to_s
        end
      end

      # Format timestamp for CSV output
      #
      # @param timestamp [DateTime, nil] Timestamp to format
      # @param use_nil_for_missing [Boolean] Whether to use nil instead of 'N/A' for nil values
      # @return [String, nil] Formatted timestamp, 'N/A', or nil
      def format_timestamp(timestamp, use_nil_for_missing: false)
        return use_nil_for_missing ? nil : 'N/A' if timestamp.nil?
        return Utils::TimestampFormatter.to_iso(timestamp) if defined?(Utils::TimestampFormatter)

        timestamp.strftime('%Y-%m-%dT%H:%M:%SZ')
      rescue StandardError => e
        log_warning("Failed to format timestamp: #{e.message}")
        use_nil_for_missing ? nil : 'N/A'
      end

      # Truncate title for CSV readability
      #
      # @param title [String, nil] Title to truncate
      # @param max_length [Integer] Maximum length
      # @return [String] Truncated title
      def truncate_title(title, max_length = 50)
        return 'N/A' if title.nil? || title.empty?
        return title if title.length <= max_length

        "#{title[0, max_length - 3]}..."
      end

      # CSV formatting utilities

      # Add section separator (empty line + header)
      #
      # @param csv [CSV] CSV object to write to
      # @param header [String] Section header text
      def add_section_separator(csv, header)
        csv << []
        csv << [header]
      end

      # Logging utilities

      # Log warning message
      #
      # @param message [String] Warning message
      def log_warning(message)
        return if ENV['QUIET'] || ENV['RAILS_ENV'] == 'test'

        puts "Warning: #{message}"
      end

      # Log error message
      #
      # @param message [String] Error message
      def log_error(message)
        return if ENV['QUIET'] || ENV['RAILS_ENV'] == 'test'

        puts "Error: #{message}"
      end
    end
    # rubocop:enable Metrics/ClassLength
  end
end
