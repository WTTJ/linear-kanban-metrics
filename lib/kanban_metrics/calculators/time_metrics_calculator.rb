# frozen_string_literal: true

require 'date'

module KanbanMetrics
  module Calculators
    # Calculates time-based metrics for Domain::Issue objects
    #
    # Provides statistical analysis of cycle time and lead time metrics:
    # - Average, median, and 95th percentile calculations
    # - Support for both individual issue analysis and bulk statistics
    # - Robust error handling and input validation
    #
    # Supports both Domain::Issue objects and raw hash data for backward compatibility.
    class TimeMetricsCalculator
      # Default statistics structure for empty datasets
      DEFAULT_TIME_STATS = {
        average: 0.0,
        median: 0.0,
        p95: 0.0
      }.freeze

      # Calculate cycle time statistics directly without instantiation
      #
      # @param domain_issues [Array<Domain::Issue, Hash>] Array of issue objects or hashes
      # @return [Hash] Statistics hash with :average, :median, and :p95
      def self.cycle_time_stats(domain_issues)
        new(domain_issues).cycle_time_stats
      end

      # Calculate lead time statistics directly without instantiation
      #
      # @param domain_issues [Array<Domain::Issue, Hash>] Array of issue objects or hashes
      # @return [Hash] Statistics hash with :average, :median, and :p95
      def self.lead_time_stats(domain_issues)
        new(domain_issues).lead_time_stats
      end

      # Initialize with array of issues
      #
      # @param domain_issues [Array<Domain::Issue, Hash>, Domain::Issue, Hash] Issue objects, hashes, or single item
      # @raise [ArgumentError] if domain_issues is not a valid input type
      def initialize(domain_issues)
        validate_input(domain_issues)
        @domain_issues = normalize_to_domain_issues(domain_issues).freeze
      end

      # Calculate cycle time statistics
      #
      # @return [Hash] Statistics hash with :average, :median, and :p95
      def cycle_time_stats
        cycle_times = extract_cycle_times
        return DEFAULT_TIME_STATS.dup if cycle_times.empty?

        build_time_stats(cycle_times)
      end

      # Calculate lead time statistics
      #
      # @return [Hash] Statistics hash with :average, :median, and :p95
      def lead_time_stats
        lead_times = extract_lead_times
        return DEFAULT_TIME_STATS.dup if lead_times.empty?

        build_time_stats(lead_times)
      end

      # Calculate cycle time for a single issue
      #
      # @param issue_data [Domain::Issue, Hash] Issue object or hash
      # @return [Float, nil] Cycle time in days or nil if not available
      def cycle_time_for_issue(issue_data)
        domain_issue = ensure_domain_issue(issue_data)
        domain_issue.cycle_time_days
      rescue StandardError => e
        log_warning("Error calculating cycle time for issue: #{e.message}")
        nil
      end

      # Calculate lead time for a single issue
      #
      # @param issue_data [Domain::Issue, Hash] Issue object or hash
      # @return [Float, nil] Lead time in days or nil if not available
      def lead_time_for_issue(issue_data)
        domain_issue = ensure_domain_issue(issue_data)
        domain_issue.lead_time_days
      rescue StandardError => e
        log_warning("Error calculating lead time for issue: #{e.message}")
        nil
      end

      private

      attr_reader :domain_issues

      # Validate input parameters
      #
      # @param input [Object] Input to validate
      # @raise [ArgumentError] if input is invalid
      def validate_input(input)
        return if input.nil?
        return if input.respond_to?(:each) # Array-like
        return if input.respond_to?(:cycle_time_days) # Single Domain::Issue
        return if input.is_a?(Hash) # Single hash

        raise ArgumentError, "Invalid input type: #{input.class}. Expected Array, Domain::Issue, Hash, or nil"
      end

      # Normalize input to array of Domain::Issue objects
      #
      # @param input [various] Input to normalize
      # @return [Array<Domain::Issue>] Array of Domain::Issue objects
      def normalize_to_domain_issues(input)
        return [] if input.nil?

        case input
        when Array
          convert_array_to_domain_issues(input)
        else
          [ensure_domain_issue(input)]
        end
      end

      # Convert array of various types to Domain::Issue objects
      #
      # @param raw_issues [Array] Array of issues in various formats
      # @return [Array<Domain::Issue>] Array of Domain::Issue objects
      def convert_array_to_domain_issues(raw_issues)
        raw_issues.filter_map { |issue_data| safely_convert_to_domain_issue(issue_data) }
      end

      # Safely convert single item to Domain::Issue
      #
      # @param issue_data [Object] Issue data to convert
      # @return [Domain::Issue, nil] Domain::Issue object or nil if conversion fails
      def safely_convert_to_domain_issue(issue_data)
        ensure_domain_issue(issue_data)
      rescue StandardError => e
        log_warning("Failed to convert issue to Domain::Issue: #{e.message}")
        nil
      end

      # Extract cycle times from all issues
      #
      # @return [Array<Float>] Array of cycle times in days
      def extract_cycle_times
        @domain_issues.filter_map do |domain_issue|
          safely_extract_time(domain_issue, :cycle_time_days)
        end
      end

      # Extract lead times from all issues
      #
      # @return [Array<Float>] Array of lead times in days
      def extract_lead_times
        @domain_issues.filter_map do |domain_issue|
          safely_extract_time(domain_issue, :lead_time_days)
        end
      end

      # Safely extract time metric from issue
      #
      # @param domain_issue [Domain::Issue] Issue object
      # @param time_method [Symbol] Method to call for time extraction
      # @return [Float, nil] Time value or nil if extraction fails
      def safely_extract_time(domain_issue, time_method)
        time_value = domain_issue.public_send(time_method)
        return nil if time_value.nil? || !time_value.is_a?(Numeric)

        time_value.to_f
      rescue StandardError => e
        log_warning("Error extracting #{time_method} from issue: #{e.message}")
        nil
      end

      # Ensure input is a Domain::Issue object
      #
      # @param issue_data [Domain::Issue, Hash] Issue data
      # @return [Domain::Issue] Domain::Issue object
      # @raise [ArgumentError] if conversion fails
      def ensure_domain_issue(issue_data)
        return issue_data if issue_data.is_a?(Domain::Issue)
        return Domain::Issue.new(issue_data) if issue_data.is_a?(Hash)

        raise ArgumentError, "Cannot convert #{issue_data.class} to Domain::Issue"
      end

      # Build statistics hash from time values
      #
      # @param time_values [Array<Float>] Array of time values
      # @return [Hash] Statistics hash with calculated metrics
      def build_time_stats(time_values)
        return DEFAULT_TIME_STATS.dup if time_values.empty?

        {
          average: calculate_average(time_values),
          median: calculate_median(time_values),
          p95: calculate_percentile(time_values, 95)
        }
      end

      # Calculate average of numeric array
      #
      # @param values [Array<Numeric>] Array of numeric values
      # @return [Float] Rounded average or 0.0 if empty
      def calculate_average(values)
        return 0.0 if values.empty?

        (values.sum.to_f / values.size).round(2)
      end

      # Calculate median of numeric array
      #
      # @param values [Array<Numeric>] Array of numeric values
      # @return [Float] Median value or 0.0 if empty
      def calculate_median(values)
        return 0.0 if values.empty?

        sorted_values = values.sort
        middle_index = sorted_values.size / 2

        if sorted_values.size.odd?
          sorted_values[middle_index].round(2)
        else
          average_of_middle = (sorted_values[middle_index - 1] + sorted_values[middle_index]) / 2.0
          average_of_middle.round(2)
        end
      end

      # Calculate percentile of numeric array
      #
      # @param values [Array<Numeric>] Array of numeric values
      # @param percentile [Integer] Percentile to calculate (0-100)
      # @return [Float] Percentile value or 0.0 if empty
      def calculate_percentile(values, percentile)
        return 0.0 if values.empty?
        return 0.0 unless percentile.between?(0, 100)

        sorted_values = values.sort
        index = ((percentile / 100.0) * (sorted_values.size - 1)).round
        sorted_values[index].round(2)
      end

      # Log warning message unless in quiet mode
      #
      # @param message [String] Warning message to log
      def log_warning(message)
        return if ENV['QUIET'] || ENV['RAILS_ENV'] == 'test'

        puts "Warning: #{message}"
      end
    end
  end
end
