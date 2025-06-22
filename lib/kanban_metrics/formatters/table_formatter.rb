# frozen_string_literal: true

require 'terminal-table'

module KanbanMetrics
  module Formatters
    # Handles table formatting for console output
    #
    # Provides comprehensive table-based reporting including:
    # - Summary metrics with KPI descriptions
    # - Detailed cycle time and lead time analysis
    # - Throughput metrics and trends
    # - Team-specific metrics breakdown
    # - Individual ticket details
    # - KPI definitions and explanations
    # - Robust error handling and data validation
    class TableFormatter
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

      # Initialize with metrics data
      #
      # @param metrics [Hash] Overall metrics data
      # @param team_metrics [Hash, nil] Team-specific metrics
      # @param issues [Array, nil] Array of issues for individual ticket data
      # @raise [ArgumentError] if metrics is nil or invalid
      def initialize(metrics, team_metrics = nil, issues = nil)
        validate_metrics(metrics)

        @metrics = metrics
        @team_metrics = team_metrics
        @issues = Array(issues) # Ensure it's always an array
      end

      # Generate and print all tables directly without instantiation
      #
      # @param metrics [Hash] Overall metrics data
      # @param team_metrics [Hash, nil] Team-specific metrics
      # @param issues [Array, nil] Array of issues for individual ticket data
      def self.print_all(metrics, team_metrics: nil, issues: nil)
        formatter = new(metrics, team_metrics, issues)
        formatter.print_summary
        formatter.print_cycle_time
        formatter.print_lead_time
        formatter.print_throughput
        formatter.print_team_metrics if team_metrics
        formatter.print_individual_tickets if issues&.any?
        formatter.print_kpi_definitions
      end

      # Print summary metrics table
      def print_summary
        table = build_summary_table
        puts "\n📈 SUMMARY"
        puts table
      rescue StandardError => e
        log_error("Failed to print summary: #{e.message}")
        puts "\n❌ Error displaying summary metrics"
      end

      # Print cycle time metrics table
      def print_cycle_time
        table = build_cycle_time_table
        puts "\n⏱️  CYCLE TIME"
        puts table
      rescue StandardError => e
        log_error("Failed to print cycle time: #{e.message}")
        puts "\n❌ Error displaying cycle time metrics"
      end

      # Print lead time metrics table
      def print_lead_time
        table = build_lead_time_table
        puts "\n📏 LEAD TIME"
        puts table
      rescue StandardError => e
        log_error("Failed to print lead time: #{e.message}")
        puts "\n❌ Error displaying lead time metrics"
      end

      # Print throughput metrics table
      def print_throughput
        table = build_throughput_table
        puts "\n🚀 THROUGHPUT"
        puts table
      rescue StandardError => e
        log_error("Failed to print throughput: #{e.message}")
        puts "\n❌ Error displaying throughput metrics"
      end

      # Print team metrics (individual and comparison)
      def print_team_metrics
        return unless team_metrics_available?

        print_individual_teams
        print_team_comparison
      rescue StandardError => e
        log_error("Failed to print team metrics: #{e.message}")
        puts "\n❌ Error displaying team metrics"
      end

      # Print KPI definitions table
      def print_kpi_definitions
        table = build_definitions_table
        puts "\n📚 KPI DEFINITIONS"
        puts '=' * 80
        puts table
      rescue StandardError => e
        log_error("Failed to print KPI definitions: #{e.message}")
        puts "\n❌ Error displaying KPI definitions"
      end

      # Print individual tickets table
      def print_individual_tickets
        return unless should_print_individual_tickets?

        puts "\n🎫 INDIVIDUAL TICKET DETAILS"
        puts '=' * 80
        table = build_individual_tickets_table
        puts table
      rescue StandardError => e
        log_error("Failed to print individual tickets: #{e.message}")
        puts "\n❌ Error displaying individual tickets"
      end

      private

      attr_reader :metrics, :team_metrics, :issues

      # Input validation

      # @param metrics [Object] Metrics data to validate
      # @raise [ArgumentError] if metrics is invalid
      def validate_metrics(metrics)
        return if metrics.is_a?(Hash) && !metrics.empty?

        raise ArgumentError, 'Metrics must be a non-empty Hash'
      end

      # Section availability logic

      # @return [Boolean] True if team metrics should be displayed
      def team_metrics_available?
        team_metrics.is_a?(Hash) && !team_metrics.empty?
      end

      # @return [Boolean] True if individual tickets should be displayed
      def should_print_individual_tickets?
        !issues.empty?
      end

      # Table building methods

      # Build summary metrics table
      #
      # @return [Terminal::Table] Summary table
      def build_summary_table
        Terminal::Table.new do |tab|
          tab.headings = %w[Metric Value Description]
          add_summary_rows(tab)
        end
      end

      # Add summary rows to table
      #
      # @param tab [Terminal::Table] Table to modify
      def add_summary_rows(tab)
        safe_add_metric_row(tab, 'Total Issues', metrics, :total_issues, KPI_DESCRIPTIONS[:total_issues])
        safe_add_metric_row(tab, 'Completed Issues', metrics, :completed_issues, KPI_DESCRIPTIONS[:completed_issues])
        safe_add_metric_row(tab, 'In Progress Issues', metrics, :in_progress_issues, KPI_DESCRIPTIONS[:in_progress_issues])
        safe_add_metric_row(tab, 'Backlog Issues', metrics, :backlog_issues, KPI_DESCRIPTIONS[:backlog_issues])

        flow_efficiency = safe_fetch_nested(metrics, :flow_efficiency)
        flow_value = flow_efficiency ? "#{flow_efficiency}%" : 'N/A'
        tab.add_row ['Flow Efficiency', flow_value, KPI_DESCRIPTIONS[:flow_efficiency]]
      end

      # Build cycle time metrics table
      #
      # @return [Terminal::Table] Cycle time table
      def build_cycle_time_table
        Terminal::Table.new do |tab|
          tab.headings = %w[Metric Days Description]
          add_time_metric_rows(tab, :cycle_time, 'Cycle Time')
        end
      end

      # Build lead time metrics table
      #
      # @return [Terminal::Table] Lead time table
      def build_lead_time_table
        Terminal::Table.new do |tab|
          tab.headings = %w[Metric Days Description]
          add_time_metric_rows(tab, :lead_time, 'Lead Time')
        end
      end

      # Add time-based metric rows to table
      #
      # @param tab [Terminal::Table] Table to modify
      # @param metric_key [Symbol] Key for the metric (cycle_time or lead_time)
      # @param metric_name [String] Display name for the metric
      def add_time_metric_rows(tab, metric_key, metric_name)
        time_data = safe_fetch_nested(metrics, metric_key)
        return unless time_data.is_a?(Hash)

        safe_add_time_row(tab, "Average #{metric_name}", time_data, :average, :"average_#{metric_key}")
        safe_add_time_row(tab, "Median #{metric_name}", time_data, :median, :"median_#{metric_key}")
        safe_add_time_row(tab, '95th Percentile', time_data, :p95, :"p95_#{metric_key}")
      end

      # Build throughput metrics table
      #
      # @return [Terminal::Table] Throughput table
      def build_throughput_table
        Terminal::Table.new do |tab|
          tab.headings = %w[Metric Value Description]
          add_throughput_rows(tab)
        end
      end

      # Add throughput rows to table
      #
      # @param tab [Terminal::Table] Table to modify
      def add_throughput_rows(tab)
        throughput_data = safe_fetch_nested(metrics, :throughput)
        return unless throughput_data.is_a?(Hash)

        safe_add_throughput_row(tab, 'Weekly Average', throughput_data, :weekly_avg, KPI_DESCRIPTIONS[:weekly_avg])
        safe_add_throughput_row(tab, 'Total Completed', throughput_data, :total_completed, KPI_DESCRIPTIONS[:total_completed])
      end

      # Build KPI definitions table
      #
      # @return [Terminal::Table] Definitions table
      def build_definitions_table
        Terminal::Table.new do |tab|
          tab.headings = ['KPI', 'Definition', 'What it tells you']
          add_definition_rows(tab)
        end
      end

      # Add definition rows to table
      #
      # @param tab [Terminal::Table] Table to modify
      def add_definition_rows(tab)
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

      # Team metrics methods

      # Print individual team metrics
      def print_individual_teams
        puts "\n👥 TEAM METRICS"
        puts '=' * 80

        sorted_teams = team_metrics.sort
        sorted_teams.each do |team, stats|
          print_individual_team(team, stats)
        end
      end

      # Print metrics for a single team
      #
      # @param team [String] Team name
      # @param stats [Hash] Team statistics
      def print_individual_team(team, stats)
        puts "\n🏷️  #{team.upcase}"
        table = build_team_table(stats)
        puts table
      rescue StandardError => e
        log_warning("Failed to display metrics for team '#{team}': #{e.message}")
        puts "\n❌ Error displaying metrics for team '#{team}'"
      end

      # Print team comparison table
      def print_team_comparison
        puts "\n📊 TEAM COMPARISON"
        table = build_team_comparison_table
        puts table
      end

      # Build metrics table for a single team
      #
      # @param stats [Hash] Team statistics
      # @return [Terminal::Table] Team metrics table
      def build_team_table(stats)
        Terminal::Table.new do |tab|
          tab.headings = %w[Metric Value Description]
          add_team_metric_rows(tab, stats)
        end
      end

      # Add team metric rows to table
      #
      # @param tab [Terminal::Table] Table to modify
      # @param stats [Hash] Team statistics
      def add_team_metric_rows(tab, stats)
        safe_add_metric_row(tab, 'Total Issues', stats, :total_issues, KPI_DESCRIPTIONS[:total_issues])
        safe_add_metric_row(tab, 'Completed Issues', stats, :completed_issues, KPI_DESCRIPTIONS[:completed_issues])
        safe_add_metric_row(tab, 'In Progress Issues', stats, :in_progress_issues, KPI_DESCRIPTIONS[:in_progress_issues])
        safe_add_metric_row(tab, 'Backlog Issues', stats, :backlog_issues, KPI_DESCRIPTIONS[:backlog_issues])

        # Time metrics with units
        add_team_time_metrics(tab, stats)

        # Throughput
        throughput = safe_fetch_nested(stats, :throughput)
        throughput_value = format_throughput_value(throughput)
        tab.add_row ['Throughput', throughput_value, KPI_DESCRIPTIONS[:total_completed]]
      end

      # Add time metrics for team table
      #
      # @param tab [Terminal::Table] Table to modify
      # @param stats [Hash] Team statistics
      def add_team_time_metrics(tab, stats)
        cycle_time = safe_fetch_nested(stats, :cycle_time)
        lead_time = safe_fetch_nested(stats, :lead_time)

        if cycle_time.is_a?(Hash)
          add_team_time_row(tab, 'Avg Cycle Time', cycle_time, :average, KPI_DESCRIPTIONS[:average_cycle_time])
          add_team_time_row(tab, 'Median Cycle Time', cycle_time, :median, KPI_DESCRIPTIONS[:median_cycle_time])
        end

        return unless lead_time.is_a?(Hash)

        add_team_time_row(tab, 'Avg Lead Time', lead_time, :average, KPI_DESCRIPTIONS[:average_lead_time])
        add_team_time_row(tab, 'Median Lead Time', lead_time, :median, KPI_DESCRIPTIONS[:median_lead_time])
      end

      # Build team comparison table
      #
      # @return [Terminal::Table] Team comparison table
      def build_team_comparison_table
        Terminal::Table.new do |tab|
          tab.headings = [
            'Team', 'Total', 'Completed', 'In Progress', 'Backlog',
            'Avg Cycle', 'Median Cycle', 'Avg Lead', 'Median Lead', 'Throughput'
          ]
          add_team_comparison_rows(tab)
        end
      end

      # Add team comparison rows to table
      #
      # @param tab [Terminal::Table] Table to modify
      def add_team_comparison_rows(tab)
        sorted_teams = team_metrics.sort
        sorted_teams.each do |team, stats|
          add_team_comparison_row(tab, team, stats)
        end
      end

      # Add single team comparison row
      #
      # @param tab [Terminal::Table] Table to modify
      # @param team [String] Team name
      # @param stats [Hash] Team statistics
      def add_team_comparison_row(tab, team, stats)
        tab.add_row [
          team,
          safe_fetch_nested(stats, :total_issues) || 'N/A',
          safe_fetch_nested(stats, :completed_issues) || 'N/A',
          safe_fetch_nested(stats, :in_progress_issues) || 'N/A',
          safe_fetch_nested(stats, :backlog_issues) || 'N/A',
          safe_fetch_nested(stats, :cycle_time, :average) || 'N/A',
          safe_fetch_nested(stats, :cycle_time, :median) || 'N/A',
          safe_fetch_nested(stats, :lead_time, :average) || 'N/A',
          safe_fetch_nested(stats, :lead_time, :median) || 'N/A',
          safe_fetch_nested(stats, :throughput) || 'N/A'
        ]
      rescue StandardError => e
        log_warning("Failed to add comparison row for team '#{team}': #{e.message}")
        tab.add_row [team] + (['Error'] * 9)
      end

      # Individual tickets methods

      # Build individual tickets table
      #
      # @return [Terminal::Table] Individual tickets table
      def build_individual_tickets_table
        Terminal::Table.new do |tab|
          tab.headings = [
            'ID', 'Title', 'State', 'Created At', 'Completed At',
            'Cycle Time (days)', 'Lead Time (days)', 'Team'
          ]
          add_individual_ticket_rows(tab)
        end
      end

      # Add individual ticket rows to table
      #
      # @param tab [Terminal::Table] Table to modify
      def add_individual_ticket_rows(tab)
        issues.each do |issue_data|
          add_individual_ticket_row(tab, issue_data)
        end
      end

      # Add single ticket row to table
      #
      # @param tab [Terminal::Table] Table to modify
      # @param issue_data [Object] Issue data
      def add_individual_ticket_row(tab, issue_data)
        domain_issue = safely_convert_to_domain_issue(issue_data)
        return unless domain_issue

        tab.add_row [
          domain_issue.identifier || 'N/A',
          truncate_title(domain_issue.title || 'N/A'),
          domain_issue.state_name || 'N/A',
          format_timestamp_for_display(domain_issue.created_at),
          format_timestamp_for_display(domain_issue.completed_at),
          domain_issue.cycle_time_days || 'N/A',
          domain_issue.lead_time_days || 'N/A',
          domain_issue.team_name || 'N/A'
        ]
      rescue StandardError => e
        log_warning("Failed to add ticket row: #{e.message}")
        tab.add_row ['Error', 'N/A', 'N/A', 'N/A', 'N/A', 'N/A', 'N/A', 'N/A']
      end

      # Utility methods for safe data access and formatting

      # Safely add a metric row to table
      #
      # @param tab [Terminal::Table] Table to modify
      # @param label [String] Row label
      # @param data [Hash] Data source
      # @param key [Symbol] Key to fetch from data
      # @param description [String] Description for the metric
      def safe_add_metric_row(tab, label, data, key, description)
        value = safe_fetch_nested(data, key) || 'N/A'
        tab.add_row [label, value, description]
      rescue StandardError => e
        log_warning("Failed to add metric row '#{label}': #{e.message}")
        tab.add_row [label, 'N/A', description]
      end

      # Safely add a time metric row to table
      #
      # @param tab [Terminal::Table] Table to modify
      # @param label [String] Row label
      # @param data [Hash] Data source
      # @param key [Symbol] Key to fetch from data
      # @param description_key [Symbol] Key for description
      def safe_add_time_row(tab, label, data, key, description_key)
        value = safe_fetch_nested(data, key) || 'N/A'
        description = KPI_DESCRIPTIONS[description_key] || 'N/A'
        tab.add_row [label, value, description]
      rescue StandardError => e
        log_warning("Failed to add time row '#{label}': #{e.message}")
        tab.add_row [label, 'N/A', description || 'N/A']
      end

      # Safely add a throughput row to table
      #
      # @param tab [Terminal::Table] Table to modify
      # @param label [String] Row label
      # @param data [Hash] Data source
      # @param key [Symbol] Key to fetch from data
      # @param description [String] Description for the metric
      def safe_add_throughput_row(tab, label, data, key, description)
        value = safe_fetch_nested(data, key) || 'N/A'
        tab.add_row [label, value, description]
      rescue StandardError => e
        log_warning("Failed to add throughput row '#{label}': #{e.message}")
        tab.add_row [label, 'N/A', description]
      end

      # Safely add team time metric row
      #
      # @param tab [Terminal::Table] Table to modify
      # @param label [String] Row label
      # @param data [Hash] Data source
      # @param key [Symbol] Key to fetch from data
      # @param description [String] Description for the metric
      def add_team_time_row(tab, label, data, key, description)
        value = safe_fetch_nested(data, key)
        formatted_value = value ? "#{value} days" : 'N/A'
        tab.add_row [label, formatted_value, description]
      rescue StandardError => e
        log_warning("Failed to add team time row '#{label}': #{e.message}")
        tab.add_row [label, 'N/A', description]
      end

      # Format throughput value for display
      #
      # @param throughput [Object] Throughput data to format
      # @return [String] Formatted throughput value
      def format_throughput_value(throughput)
        return 'N/A' if throughput.nil?

        # Handle hash format (e.g., from some team metrics)
        if throughput.is_a?(Hash)
          total = safe_fetch_nested(throughput, :total_completed) ||
                  safe_fetch_nested(throughput, :total) ||
                  throughput.values.find { |v| v.is_a?(Numeric) && v.positive? }
          return total ? "#{total} completed" : '0 completed'
        end

        # Handle numeric format
        return "#{throughput} completed" if throughput.is_a?(Numeric)

        # Fallback for any other format
        throughput.to_s
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

      # Format timestamp for display
      #
      # @param timestamp [DateTime, nil] Timestamp to format
      # @return [String] Formatted timestamp or 'N/A'
      def format_timestamp_for_display(timestamp)
        return 'N/A' if timestamp.nil?
        return Utils::TimestampFormatter.to_display(timestamp) if defined?(Utils::TimestampFormatter)

        timestamp.strftime('%Y-%m-%d')
      rescue StandardError => e
        log_warning("Failed to format timestamp: #{e.message}")
        'N/A'
      end

      # Truncate and sanitize title for table display
      #
      # @param title [String, nil] Title to truncate and sanitize
      # @param max_length [Integer] Maximum length
      # @return [String] Sanitized and truncated title
      def truncate_title(title, max_length = 30)
        return 'N/A' if title.nil? || title.empty?

        # Sanitize: replace newlines with spaces, remove other problematic characters
        sanitized = title.to_s
                         .gsub(/\r?\n/, ' ') # Replace newlines with spaces
                         .tr("\t", ' ') # Replace tabs with spaces
                         .gsub(/\s+/, ' ')            # Collapse multiple spaces
                         .strip                       # Remove leading/trailing whitespace

        return sanitized if sanitized.length <= max_length

        "#{sanitized[0, max_length - 3]}..."
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
  end
end
