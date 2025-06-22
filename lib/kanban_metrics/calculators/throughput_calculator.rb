# frozen_string_literal: true

require 'date'

module KanbanMetrics
  module Calculators
    # Calculates throughput for completed issues
    #
    # Provides weekly throughput statistics including:
    # - Average issues completed per week
    # - Total completed issues count
    class ThroughputCalculator
      # Constant for invalid date grouping key
      INVALID_DATE_KEY = 'invalid-date'

      # Initialize with array of completed issues
      #
      # @param completed_issues [Array<Domain::Issue, Hash>] Array of issue objects or hashes
      def initialize(completed_issues)
        @completed_issues = Array(completed_issues)
      end

      # Calculate throughput statistics
      #
      # @return [Hash] Statistics hash with :weekly_avg and :total_completed
      def stats
        return default_stats if completed_issues_empty?

        weekly_counts = calculate_weekly_counts
        build_stats_hash(weekly_counts)
      end

      private

      attr_reader :completed_issues

      # Default statistics when no completed issues
      #
      # @return [Hash] Default stats structure
      def default_stats
        {
          weekly_avg: 0.0,
          total_completed: 0
        }
      end

      # Check if completed issues array is empty
      #
      # @return [Boolean] True if no completed issues
      def completed_issues_empty?
        @completed_issues.nil? || @completed_issues.empty?
      end

      # Build the statistics hash from weekly counts
      #
      # @param weekly_counts [Array<Integer>] Array of issue counts per week
      # @return [Hash] Statistics hash
      def build_stats_hash(weekly_counts)
        {
          weekly_avg: calculate_average(weekly_counts),
          total_completed: @completed_issues.size
        }
      end

      # Calculate count of issues completed per week
      #
      # @return [Array<Integer>] Array of weekly completion counts
      def calculate_weekly_counts
        weekly_groups = group_issues_by_week
        weekly_groups.values.map(&:size)
      end

      # Group issues by week based on completion date
      #
      # @return [Hash] Hash with week strings as keys and issue arrays as values
      def group_issues_by_week
        @completed_issues.group_by do |issue|
          extract_week_from_issue(issue)
        end
      end

      # Alias for backward compatibility with existing tests
      alias group_by_week group_issues_by_week

      # Extract week identifier from issue completion date
      #
      # @param issue [Domain::Issue, Hash] Issue object or hash
      # @return [String] Week identifier in format 'YYYY-WNN' or 'invalid-date'
      def extract_week_from_issue(issue)
        # Handle both Domain::Issue objects and raw hashes for backward compatibility
        completed_at = issue.respond_to?(:completed_at) ? issue.completed_at : issue['completedAt']

        return handle_missing_date if completed_at.nil?

        parse_completion_date(completed_at)
      end

      # Handle missing completion date
      #
      # @return [String] Invalid date identifier
      def handle_missing_date
        log_warning('Missing completion date for issue')
        INVALID_DATE_KEY
      end

      # Parse completion date to week format
      #
      # @param completed_at [DateTime, String] Completion date object or string
      # @return [String] Week identifier or invalid date key
      def parse_completion_date(completed_at)
        # Handle both DateTime objects and string timestamps
        date_obj = completed_at.is_a?(String) ? Date.parse(completed_at) : completed_at.to_date
        date_obj.strftime('%Y-W%U')
      rescue StandardError => e
        log_warning("Invalid date '#{completed_at}' - #{e.message}")
        INVALID_DATE_KEY
      end

      # Log warning message unless in quiet mode
      #
      # @param message [String] Warning message to log
      def log_warning(message)
        puts "Warning: #{message}" unless ENV['QUIET']
      end

      # Calculate average of numeric array
      #
      # @param values [Array<Numeric>] Array of numeric values
      # @return [Float] Rounded average or 0.0 if empty
      def calculate_average(values)
        return 0.0 if values.empty?

        (values.sum.to_f / values.size).round(2)
      end
    end
  end
end
