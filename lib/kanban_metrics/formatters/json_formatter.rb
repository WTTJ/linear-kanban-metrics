# frozen_string_literal: true

require 'json'

module KanbanMetrics
  module Formatters
    # Handles JSON formatting for kanban metrics data
    #
    # Provides comprehensive JSON export functionality including:
    # - Overall metrics data
    # - Team-specific metrics breakdown
    # - Timeseries analysis data
    # - Individual ticket details
    # - Robust error handling and data validation
    # - Consistent timestamp formatting
    class JsonFormatter
      # Generate JSON directly without instantiation
      #
      # @param metrics [Hash] Overall metrics data
      # @param team_metrics [Hash, nil] Team-specific metrics
      # @param timeseries [Object, nil] Timeseries analysis object
      # @param issues [Array, nil] Array of issues for individual ticket data
      # @return [String] Generated JSON content
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

      # Generate JSON content
      #
      # @return [String] Generated JSON content
      def generate
        output = build_output_structure
        JSON.pretty_generate(output)
      rescue JSON::GeneratorError => e
        log_error("Failed to generate JSON: #{e.message}")
        raise
      rescue StandardError => e
        log_error("Unexpected error during JSON generation: #{e.message}")
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

      # JSON structure building

      # Build the main output structure
      #
      # @return [Hash] Complete output structure
      def build_output_structure
        output = { overall_metrics: metrics }

        add_team_metrics(output) if should_include_team_metrics?
        add_timeseries_data(output) if should_include_timeseries?
        add_individual_tickets(output) if should_include_individual_tickets?

        output
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

      # Data building methods

      # Add team metrics to output
      #
      # @param output [Hash] Output structure to modify
      def add_team_metrics(output)
        output[:team_metrics] = team_metrics
      rescue StandardError => e
        log_warning("Failed to add team metrics: #{e.message}")
        output[:team_metrics] = {}
      end

      # Add timeseries data to output
      #
      # @param output [Hash] Output structure to modify
      def add_timeseries_data(output)
        output[:timeseries] = build_timeseries_data
      rescue StandardError => e
        log_warning("Failed to add timeseries data: #{e.message}")
        output[:timeseries] = {}
      end

      # Build timeseries data structure
      #
      # @return [Hash] Timeseries data structure
      def build_timeseries_data
        return {} unless timeseries

        result = {}

        safely_add_timeseries_field(result, :status_flow_analysis)
        safely_add_timeseries_field(result, :average_time_in_status)
        safely_add_timeseries_field(result, :daily_status_counts)

        result
      end

      # Safely add a timeseries field to the result
      #
      # @param result [Hash] Result hash to modify
      # @param field_name [Symbol] Name of the field to add
      def safely_add_timeseries_field(result, field_name)
        return unless timeseries.respond_to?(field_name)

        result[field_name] = timeseries.public_send(field_name)
      rescue StandardError => e
        log_warning("Failed to add timeseries field '#{field_name}': #{e.message}")
        result[field_name] = {}
      end

      # Add individual tickets to output
      #
      # @param output [Hash] Output structure to modify
      def add_individual_tickets(output)
        output[:individual_tickets] = build_individual_tickets_data
      rescue StandardError => e
        log_warning("Failed to add individual tickets: #{e.message}")
        output[:individual_tickets] = []
      end

      # Build individual tickets data structure
      #
      # @return [Array<Hash>] Array of ticket data hashes
      def build_individual_tickets_data
        return [] unless issues

        issues.filter_map do |issue_data|
          build_individual_ticket_data(issue_data)
        end
      end

      # Build data structure for a single ticket
      #
      # @param issue_data [Object] Issue data to convert
      # @return [Hash, nil] Ticket data hash or nil if conversion fails
      def build_individual_ticket_data(issue_data)
        domain_issue = safely_convert_to_domain_issue(issue_data)
        return nil unless domain_issue

        {
          id: domain_issue.id,
          identifier: domain_issue.identifier,
          title: domain_issue.title,
          state: build_state_data(domain_issue),
          team: domain_issue.team_name,
          assignee: domain_issue.assignee_name,
          priority: domain_issue.priority,
          estimate: domain_issue.estimate,
          createdAt: format_timestamp(domain_issue.created_at),
          updatedAt: format_timestamp(domain_issue.updated_at),
          startedAt: format_timestamp(domain_issue.started_at),
          completedAt: format_timestamp(domain_issue.completed_at),
          archivedAt: format_timestamp(domain_issue.archived_at),
          cycle_time_days: domain_issue.cycle_time_days,
          lead_time_days: domain_issue.lead_time_days
        }
      rescue StandardError => e
        log_warning("Failed to build ticket data: #{e.message}")
        nil
      end

      # Build state data for a ticket
      #
      # @param domain_issue [Domain::Issue] Domain issue object
      # @return [Hash] State data structure
      def build_state_data(domain_issue)
        {
          name: domain_issue.state_name,
          type: domain_issue.state_type
        }
      end

      # Data conversion utilities

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

      # Format timestamp for JSON output
      #
      # @param timestamp [DateTime, nil] Timestamp to format
      # @return [String, nil] Formatted timestamp or nil
      def format_timestamp(timestamp)
        return nil if timestamp.nil?
        return Utils::TimestampFormatter.to_iso(timestamp) if defined?(Utils::TimestampFormatter)

        timestamp.strftime('%Y-%m-%dT%H:%M:%SZ')
      rescue StandardError => e
        log_warning("Failed to format timestamp: #{e.message}")
        nil
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
