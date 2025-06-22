# frozen_string_literal: true

require 'date'

module KanbanMetrics
  module Calculators
    # Calculates throughput for completed issues
    #
    # Provides weekly throughput statistics including:
    # - Average issues completed per week
    # - Total completed issues count
    # - Weekly completion patterns
    #
    # Supports both Domain::Issue objects and raw hash data for backward compatibility.
    class ThroughputCalculator
      # Constant for invalid date grouping key
      INVALID_DATE_KEY = 'invalid-date'

      # Default statistics structure for empty datasets
      DEFAULT_STATS = {
        weekly_avg: 0.0,
        total_completed: 0
      }.freeze

      # Calculate throughput statistics directly without instantiation
      #
      # @param completed_issues [Array<Domain::Issue, Hash>] Array of issue objects or hashes
      # @return [Hash] Statistics hash with :weekly_avg and :total_completed
      def self.calculate(completed_issues)
        new(completed_issues).stats
      end

      # Initialize with array of completed issues
      #
      # @param completed_issues [Array<Domain::Issue, Hash>] Array of issue objects or hashes
      # @raise [ArgumentError] if completed_issues is not enumerable
      def initialize(completed_issues)
        validate_input(completed_issues)
        @completed_issues = Array(completed_issues).freeze
        @memoized_weekly_groups = nil # Memoization cache
      end

      # Calculate throughput statistics
      #
      # @return [Hash] Statistics hash with :weekly_avg and :total_completed
      def stats
        return DEFAULT_STATS.dup if completed_issues_empty?

        weekly_counts = calculate_weekly_counts
        build_stats_hash(weekly_counts)
      end

      # Get issues grouped by week (for debugging/analysis)
      #
      # @return [Hash] Hash with week strings as keys and issue arrays as values
      def group_by_week
        return {} if completed_issues_empty?

        memoized_weekly_groups
      end

      private

      attr_reader :completed_issues

      # Get memoized weekly groups to avoid recalculation
      #
      # @return [Hash] Hash with week strings as keys and issue arrays as values
      def memoized_weekly_groups
        @memoized_weekly_groups ||= group_issues_by_week
      end

      # Validate input parameters
      #
      # @param completed_issues [Object] Input to validate
      # @raise [ArgumentError] if input is invalid
      def validate_input(completed_issues)
        return if completed_issues.nil? || completed_issues.respond_to?(:each)

        raise ArgumentError, 'completed_issues must be enumerable (Array, etc.)'
      end

      # Check if completed issues array is empty
      #
      # @return [Boolean] True if no completed issues
      def completed_issues_empty?
        @completed_issues.empty?
      end

      # Build the statistics hash from weekly counts
      #
      # @param weekly_counts [Array<Integer>] Array of issue counts per week
      # @return [Hash] Statistics hash with calculated metrics
      def build_stats_hash(weekly_counts)
        {
          weekly_avg: calculate_average(weekly_counts),
          total_completed: @completed_issues.size
        }
      end

      # Calculate count of issues completed per week
      #
      # @return [Array<Integer>] Array of weekly completion counts, excluding invalid dates
      def calculate_weekly_counts
        weekly_groups = memoized_weekly_groups

        # Filter out invalid dates and extract counts more efficiently
        weekly_groups.filter_map do |week_key, completed_items|
          completed_items.size unless week_key == INVALID_DATE_KEY
        end
      end

      # Group issues by week based on completion date
      #
      # @return [Hash] Hash with week strings as keys and issue arrays as values
      def group_issues_by_week
        @completed_issues.group_by { |completed_item| extract_week_from_issue(completed_item) }
      end

      # Extract week identifier from issue completion date
      #
      # @param completed_item [Domain::Issue, Hash] Completed issue object or hash
      # @return [String] Week identifier in format 'YYYY-WNN' or 'invalid-date'
      def extract_week_from_issue(completed_item)
        completed_at = extract_completion_date(completed_item)

        return handle_missing_date(completed_item) if completed_at.nil?

        parse_completion_date(completed_at)
      end

      # Extract completion date from issue using appropriate method
      #
      # @param work_item [Domain::Issue, Hash] Work item object or hash
      # @return [DateTime, String, nil] Completion date or nil if missing
      def extract_completion_date(work_item)
        case work_item
        when ->(item) { item.respond_to?(:completed_at) }
          work_item.completed_at
        when Hash
          work_item['completedAt']
        else
          log_warning("Unexpected work item type: #{work_item.class}")
          nil
        end
      end

      # Handle missing completion date with better context
      #
      # @param work_item [Object] Work item that's missing completion date
      # @return [String] Invalid date identifier
      def handle_missing_date(work_item)
        item_id = extract_item_id(work_item)
        log_warning("Missing completion date for work item #{item_id}")
        INVALID_DATE_KEY
      end

      # Extract item ID for better error messages
      #
      # @param work_item [Object] Work item object or hash
      # @return [String] Item identifier or 'unknown'
      def extract_item_id(work_item)
        case work_item
        when ->(item) { item.respond_to?(:id) }
          work_item.id&.to_s || 'unknown'
        when Hash
          (work_item['id'] || work_item[:id])&.to_s || 'unknown'
        else
          'unknown'
        end
      end

      # Parse completion date to week format with robust error handling
      #
      # @param completed_at [DateTime, String] Completion date object or string
      # @return [String] Week identifier or invalid date key
      def parse_completion_date(completed_at)
        date_obj = normalize_date(completed_at)
        date_obj.strftime('%Y-W%U')
      rescue StandardError => e
        log_warning("Invalid date '#{completed_at}' (#{completed_at.class}): #{e.message}")
        INVALID_DATE_KEY
      end

      # Normalize various date formats to Date object
      #
      # @param date_input [DateTime, Date, String] Input date in various formats
      # @return [Date] Normalized date object
      # @raise [ArgumentError] if date cannot be parsed
      def normalize_date(date_input)
        case date_input
        when Date
          date_input
        when DateTime, Time
          date_input.to_date
        when String
          Date.parse(date_input)
        else
          raise ArgumentError, "Unsupported date type: #{date_input.class}"
        end
      end

      # Log warning message unless in quiet mode
      #
      # @param message [String] Warning message to log
      def log_warning(message)
        return if ENV['QUIET'] || ENV['RAILS_ENV'] == 'test'

        puts "Warning: #{message}"
      end

      # Calculate average of numeric array with better precision
      #
      # @param values [Array<Numeric>] Array of numeric values
      # @return [Float] Rounded average or 0.0 if empty
      def calculate_average(values)
        return 0.0 if values.empty?

        # Use more precise calculation for better accuracy
        average = values.sum.to_f / values.size
        average.round(2)
      end
    end
  end
end
