# frozen_string_literal: true

require 'date'

module KanbanMetrics
  module Domain
    # Domain object representing a Linear issue with calculated properties
    #
    # Provides a rich interface for accessing Linear issue data with:
    # - Safe attribute access with nil handling
    # - Calculated time metrics (cycle time, lead time)
    # - Status classification methods
    # - Robust timestamp parsing with error handling
    # - Performance optimizations with memoization
    class Issue
      # Valid Linear state types for validation
      VALID_STATE_TYPES = %w[backlog unstarted started completed canceled].freeze

      attr_reader :raw_data

      # Initialize with issue data
      #
      # @param issue_data [Hash, Domain::Issue] Raw issue data hash or existing Domain::Issue
      # @raise [ArgumentError] if issue_data is nil or invalid
      def initialize(issue_data)
        validate_issue_data(issue_data)

        # Prevent double-wrapping: if we already have a Domain::Issue, use its raw_data
        @raw_data = issue_data.is_a?(Domain::Issue) ? issue_data.raw_data : issue_data
        @parsed_timestamps = {} # Memoization cache for parsed timestamps
      end

      # Core Linear fields with safe access

      # @return [String, nil] Unique issue ID
      def id
        safe_fetch('id')
      end

      # @return [String, nil] Human-readable issue identifier (e.g., "ENG-123")
      def identifier
        safe_fetch('identifier')
      end

      # @return [String, nil] Issue title/summary
      def title
        safe_fetch('title')
      end

      # @return [Integer, nil] Issue priority level
      def priority
        safe_fetch('priority')&.to_i
      end

      # @return [Float, nil] Story point estimate
      def estimate
        value = safe_fetch('estimate')
        value&.to_f
      end

      # State information with validation

      # @return [String, nil] Current state name
      def state_name
        safe_dig('state', 'name')
      end

      # @return [String, nil] Current state type (backlog, started, completed, etc.)
      def state_type
        state_type = safe_dig('state', 'type')
        return state_type if state_type.nil? || VALID_STATE_TYPES.include?(state_type)

        log_warning("Invalid state type: #{state_type}")
        state_type
      end

      # Team and assignee information

      # @return [String, nil] Team name
      def team_name
        safe_dig('team', 'name')
      end

      # @return [String, nil] Assignee name
      def assignee_name
        safe_dig('assignee', 'name')
      end

      # Timestamps with memoization and robust parsing

      # @return [DateTime, nil] When the issue was created
      def created_at
        memoized_timestamp('createdAt')
      end

      # @return [DateTime, nil] When the issue was last updated
      def updated_at
        memoized_timestamp('updatedAt')
      end

      # @return [DateTime, nil] When work started on the issue
      def started_at
        @started_at ||= memoized_timestamp('startedAt') || find_history_start_time
      end

      # @return [DateTime, nil] When the issue was completed
      def completed_at
        memoized_timestamp('completedAt')
      end

      # @return [DateTime, nil] When the issue was archived
      def archived_at
        memoized_timestamp('archivedAt')
      end

      # Calculated time metrics with validation

      # @return [Float, nil] Cycle time in days (started to completed)
      def cycle_time_days
        return nil unless started_at && completed_at
        return nil if completed_at < started_at # Invalid data protection

        calculate_time_difference(started_at, completed_at)
      end

      # @return [Float, nil] Lead time in days (created to completed)
      def lead_time_days
        return nil unless created_at && completed_at
        return nil if completed_at < created_at # Invalid data protection

        calculate_time_difference(created_at, completed_at)
      end

      # Status classification methods with comprehensive logic

      # @return [Boolean] True if the issue has been completed
      def completed?
        !completed_at.nil? && state_type == 'completed'
      end

      # @return [Boolean] True if work is currently in progress
      def in_progress?
        !started_at.nil? && completed_at.nil? && %w[started].include?(state_type)
      end

      # @return [Boolean] True if issue is in backlog (not started)
      def backlog?
        started_at.nil? && completed_at.nil? && %w[backlog unstarted].include?(state_type)
      end

      # @return [Boolean] True if issue was canceled/cancelled
      def canceled?
        state_type == 'canceled'
      end

      # @return [Boolean] True if issue is archived
      def archived?
        !archived_at.nil?
      end

      # Debugging and inspection methods

      # @return [String] Human-readable representation
      def to_s
        title_display = title ? truncate_string(title, 50) : 'No title'
        "Issue[#{identifier || id}]: #{title_display}"
      end

      # @return [String] Detailed string representation for debugging
      def inspect
        "#<#{self.class.name} id=#{id.inspect} identifier=#{identifier.inspect} " \
          "state=#{state_type.inspect} completed=#{completed?}>"
      end

      private

      # Input validation

      # @param issue_data [Object] Data to validate
      # @raise [ArgumentError] if data is invalid
      def validate_issue_data(issue_data)
        raise ArgumentError, 'Issue data cannot be nil' if issue_data.nil?

        # Accept Domain::Issue or Hash-like objects
        return if issue_data.is_a?(Domain::Issue)
        return if issue_data.respond_to?(:[]) # Hash-like

        raise ArgumentError, "Invalid issue data type: #{issue_data.class}. Expected Hash or Domain::Issue"
      end

      # Safe data access methods

      # @param key [String] Key to fetch
      # @return [Object, nil] Value or nil if not found
      def safe_fetch(key)
        return nil unless @raw_data.respond_to?(:[])

        @raw_data[key]
      end

      # @param *keys [String] Keys to dig through
      # @return [Object, nil] Value or nil if not found
      def safe_dig(*keys)
        return nil unless @raw_data.respond_to?(:dig)

        @raw_data.dig(*keys)
      end

      # Timestamp handling with memoization

      # @param field_name [String] Timestamp field name
      # @return [DateTime, nil] Parsed timestamp or nil
      def memoized_timestamp(field_name)
        return @parsed_timestamps[field_name] if @parsed_timestamps.key?(field_name)

        @parsed_timestamps[field_name] = parse_timestamp(safe_fetch(field_name))
      end

      # @param timestamp_str [String, nil] Timestamp string to parse
      # @return [DateTime, nil] Parsed DateTime or nil
      def parse_timestamp(timestamp_str)
        return nil unless timestamp_str.is_a?(String) && !timestamp_str.empty?

        DateTime.parse(timestamp_str)
      rescue StandardError => e
        log_warning("Failed to parse timestamp '#{timestamp_str}': #{e.message}")
        nil
      end

      # @return [DateTime, nil] Start time from history if available
      def find_history_start_time
        history_nodes = safe_dig('history', 'nodes')
        return nil unless history_nodes.is_a?(Array)

        start_event = history_nodes.find do |event|
          event.is_a?(Hash) && safe_dig_from_hash(event, 'toState', 'type') == 'started'
        end

        return nil unless start_event

        parse_timestamp(safe_dig_from_hash(start_event, 'createdAt'))
      end

      # @param hash [Hash] Hash to dig from
      # @param *keys [String] Keys to dig through
      # @return [Object, nil] Value or nil if not found
      def safe_dig_from_hash(hash, *keys)
        return nil unless hash.respond_to?(:dig)

        hash.dig(*keys)
      end

      # Time calculation with precision

      # @param start_time [DateTime] Start timestamp
      # @param end_time [DateTime] End timestamp
      # @return [Float] Time difference in days, rounded to 2 decimal places
      def calculate_time_difference(start_time, end_time)
        (end_time - start_time).to_f.round(2)
      end

      # Logging utility

      # @param message [String] Warning message to log
      def log_warning(message)
        return if ENV['QUIET'] || ENV['RAILS_ENV'] == 'test'

        puts "Warning: #{message}"
      end

      # String utility methods

      # @param str [String] String to truncate
      # @param max_length [Integer] Maximum length
      # @return [String] Truncated string with ellipsis if needed
      def truncate_string(str, max_length)
        return str if str.length <= max_length

        "#{str[0, max_length - 3]}..."
      end
    end
  end
end
