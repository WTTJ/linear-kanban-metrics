# frozen_string_literal: true

require 'date'

module KanbanMetrics
  module Reports
    # Value object to hold timeline display configuration
    class TimelineDisplayConfig
      HEADER_SEPARATOR = '=' * 80
      DATE_FORMAT = '%Y-%m-%d %H:%M'
      TIMELINE_EMOJI = '📈'
      ERROR_EMOJI = '❌'
      ARROW_SYMBOL = '→'
      SEPARATOR_SYMBOL = '|'
      CREATED_STATE = 'Created'

      def self.header_separator
        HEADER_SEPARATOR
      end

      def self.date_format
        DATE_FORMAT
      end

      def self.timeline_emoji
        TIMELINE_EMOJI
      end

      def self.error_emoji
        ERROR_EMOJI
      end

      def self.arrow_symbol
        ARROW_SYMBOL
      end

      def self.separator_symbol
        SEPARATOR_SYMBOL
      end

      def self.created_state
        CREATED_STATE
      end
    end

    # Service to retrieve timeline data for issues
    class TimelineDataService
      def initialize(issues, timeseries_generator = nil)
        @issues = issues
        @timeseries_generator = timeseries_generator || default_generator
      end

      def find_timeline_data(issue_id)
        timeline_data = @timeseries_generator.call(@issues)
        timeline_data.find { |data| data[:id] == issue_id }
      end

      private

      def default_generator
        ->(issues) { Timeseries::TicketTimeseries.new(issues).generate_timeseries }
      end
    end

    # Service to format individual timeline events
    class TimelineEventFormatter
      def initialize(config = TimelineDisplayConfig)
        @config = config
      end

      def format_event(event)
        date_str = format_date(event[:date])
        transition = format_transition(event[:from_state], event[:to_state])
        "#{date_str} #{@config.separator_symbol} #{transition}"
      end

      private

      def format_date(date_string)
        DateTime.parse(date_string).strftime(@config.date_format)
      end

      def format_transition(from_state, to_state)
        source_state = from_state || @config.created_state
        "#{source_state} #{@config.arrow_symbol} #{to_state}"
      end
    end

    # Service to format complete timeline output
    class TimelineFormatter
      def initialize(config = TimelineDisplayConfig, event_formatter = nil)
        @config = config
        @event_formatter = event_formatter || TimelineEventFormatter.new(config)
      end

      def format_timeline(timeline_data)
        header = format_header(timeline_data)
        events = format_events(timeline_data[:timeline])

        [header, events].flatten.compact.join("\n")
      end

      def format_not_found_message(issue_id)
        "#{@config.error_emoji} Issue #{issue_id} not found"
      end

      private

      def format_header(timeline_data)
        [
          "\n#{@config.timeline_emoji} TIMELINE FOR #{timeline_data[:id]}: #{timeline_data[:title]}",
          "Team: #{timeline_data[:team]}",
          @config.header_separator
        ]
      end

      def format_events(timeline_events)
        return [] if timeline_events.nil? || timeline_events.empty?

        timeline_events.map { |event| @event_formatter.format_event(event) }
      end
    end

    # Main class for displaying issue timelines
    class TimelineDisplay
      def initialize(issues, data_service: nil, formatter: nil, output_handler: nil)
        @issues = issues
        @data_service = data_service || TimelineDataService.new(issues)
        @formatter = formatter || TimelineFormatter.new
        @output_handler = output_handler || method(:puts)
      end

      def show_timeline(issue_id)
        timeline_data = @data_service.find_timeline_data(issue_id)

        output = if timeline_data
                   @formatter.format_timeline(timeline_data)
                 else
                   @formatter.format_not_found_message(issue_id)
                 end

        @output_handler.call(output)
      end
    end
  end
end
