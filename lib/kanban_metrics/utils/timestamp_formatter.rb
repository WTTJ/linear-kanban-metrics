# frozen_string_literal: true

module KanbanMetrics
  module Utils
    # Utility module for consistent timestamp formatting across the application
    module TimestampFormatter
      # ISO 8601 format for APIs and data exchange (CSV, JSON)
      ISO_FORMAT = '%Y-%m-%dT%H:%M:%SZ'

      # Human-readable format for display (tables, reports)
      DISPLAY_FORMAT = '%Y-%m-%d'

      # Default fallback value when timestamp is nil or invalid
      DEFAULT_FALLBACK = 'N/A'

      module_function

      # Format timestamp for API/data exchange (ISO 8601)
      # @param timestamp [DateTime, Time, nil] The timestamp to format
      # @param fallback [String, nil] Value to return when timestamp is nil (default: nil)
      # @return [String, nil] Formatted timestamp or fallback value
      def to_iso(timestamp, fallback: nil)
        return fallback unless timestamp

        timestamp.strftime(ISO_FORMAT)
      rescue StandardError
        fallback
      end

      # Format timestamp for human-readable display
      # @param timestamp [DateTime, Time, nil] The timestamp to format
      # @param fallback [String] Value to return when timestamp is nil (default: 'N/A')
      # @return [String] Formatted timestamp or fallback value
      def to_display(timestamp, fallback: DEFAULT_FALLBACK)
        return fallback unless timestamp

        timestamp.strftime(DISPLAY_FORMAT)
      rescue StandardError
        fallback
      end

      # Format timestamp with custom format string
      # @param timestamp [DateTime, Time, nil] The timestamp to format
      # @param format [String] The strftime format string
      # @param fallback [String, nil] Value to return when timestamp is nil
      # @return [String, nil] Formatted timestamp or fallback value
      def to_custom(timestamp, format:, fallback: nil)
        return fallback unless timestamp

        timestamp.strftime(format)
      rescue StandardError
        fallback
      end
    end
  end
end
