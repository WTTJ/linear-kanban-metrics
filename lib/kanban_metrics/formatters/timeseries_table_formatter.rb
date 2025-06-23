# frozen_string_literal: true

require 'terminal-table'
require 'date'

module KanbanMetrics
  module Formatters
    # Configuration for timeseries table formatting
    class TimeseriesTableConfig
      MAIN_HEADER = '📈 TIMESERIES ANALYSIS'
      HEADER_SEPARATOR = '=' * 80
      TRANSITIONS_HEADER = '🔀 STATUS TRANSITIONS (Most Common)'
      TIME_IN_STATUS_HEADER = '⏰ AVERAGE TIME IN STATUS'
      RECENT_ACTIVITY_HEADER = '📊 RECENT ACTIVITY (Last 10 Days)'

      TRANSITIONS_COLUMNS = %w[Transition Count Description].freeze
      TIME_IN_STATUS_COLUMNS = ['Status', 'Average Days', 'Description'].freeze
      ACTIVITY_COLUMNS = ['Date', 'Status Changes', 'Description'].freeze

      MAX_TRANSITIONS = 10
      MAX_RECENT_DAYS = 10
      DATE_FORMAT = '%Y-%m-%d'

      TRANSITIONS_DESCRIPTION = 'Number of times this transition occurred'
      TIME_IN_STATUS_DESCRIPTION = 'Average time issues spend in this status'
      DAILY_ACTIVITY_DESCRIPTION = 'Daily status change activity'

      def self.main_header
        MAIN_HEADER
      end

      def self.header_separator
        HEADER_SEPARATOR
      end

      def self.transitions_header
        TRANSITIONS_HEADER
      end

      def self.time_in_status_header
        TIME_IN_STATUS_HEADER
      end

      def self.recent_activity_header
        RECENT_ACTIVITY_HEADER
      end

      def self.transitions_columns
        TRANSITIONS_COLUMNS
      end

      def self.time_in_status_columns
        TIME_IN_STATUS_COLUMNS
      end

      def self.activity_columns
        ACTIVITY_COLUMNS
      end

      def self.max_transitions
        MAX_TRANSITIONS
      end

      def self.max_recent_days
        MAX_RECENT_DAYS
      end

      def self.date_format
        DATE_FORMAT
      end

      def self.transitions_description
        TRANSITIONS_DESCRIPTION
      end

      def self.time_in_status_description
        TIME_IN_STATUS_DESCRIPTION
      end

      def self.daily_activity_description
        DAILY_ACTIVITY_DESCRIPTION
      end
    end

    # Service for building status transitions table
    class TransitionsTableBuilder
      def initialize(config = TimeseriesTableConfig)
        @config = config
      end

      def build_table(flow_analysis)
        return nil if flow_analysis.empty?

        Terminal::Table.new do |tab|
          tab.headings = @config.transitions_columns
          flow_analysis.first(@config.max_transitions).each do |transition, count|
            tab.add_row [transition, count, @config.transitions_description]
          end
        end
      end
    end

    # Service for building time in status table
    class TimeInStatusTableBuilder
      def initialize(config = TimeseriesTableConfig)
        @config = config
      end

      def build_table(time_in_status)
        return nil if time_in_status.empty?

        Terminal::Table.new do |tab|
          tab.headings = @config.time_in_status_columns
          time_in_status.sort_by { |_, days| -days }.each do |status, days|
            tab.add_row [status, days, @config.time_in_status_description]
          end
        end
      end
    end

    # Service for building activity table
    class ActivityTableBuilder
      def initialize(config = TimeseriesTableConfig)
        @config = config
      end

      def build_table(daily_counts)
        return nil if daily_counts.empty?

        recent_days = daily_counts.keys.last(@config.max_recent_days)

        Terminal::Table.new do |tab|
          tab.headings = @config.activity_columns
          recent_days.each do |date|
            changes = daily_counts[date]
            total_changes = changes.values.sum
            status_summary = changes.map { |status, count| "#{status}(#{count})" }.join(', ')
            tab.add_row [
              date.strftime(@config.date_format),
              "#{total_changes} total: #{status_summary}",
              @config.daily_activity_description
            ]
          end
        end
      end
    end

    # Service for formatting timeseries sections
    class TimeseriesSectionFormatter
      def initialize(config: TimeseriesTableConfig,
                     transitions_builder: nil,
                     time_builder: nil,
                     activity_builder: nil)
        @config = config
        @transitions_builder = transitions_builder || TransitionsTableBuilder.new(config)
        @time_builder = time_builder || TimeInStatusTableBuilder.new(config)
        @activity_builder = activity_builder || ActivityTableBuilder.new(config)
      end

      def format_transitions_section(flow_analysis)
        table = @transitions_builder.build_table(flow_analysis)
        return nil unless table

        [
          "\n#{@config.transitions_header}",
          table.to_s
        ].join("\n")
      end

      def format_time_in_status_section(time_in_status)
        table = @time_builder.build_table(time_in_status)
        return nil unless table

        [
          "\n#{@config.time_in_status_header}",
          table.to_s
        ].join("\n")
      end

      def format_activity_section(daily_counts)
        table = @activity_builder.build_table(daily_counts)
        return nil unless table

        [
          "\n#{@config.recent_activity_header}",
          table.to_s
        ].join("\n")
      end
    end

    # Service for formatting complete timeseries output
    class TimeseriesOutputFormatter
      def initialize(config = TimeseriesTableConfig, section_formatter = nil)
        @config = config
        @section_formatter = section_formatter || TimeseriesSectionFormatter.new(config: config)
      end

      def format_timeseries(timeseries)
        sections = [
          header_section,
          @section_formatter.format_transitions_section(timeseries.status_flow_analysis),
          @section_formatter.format_time_in_status_section(timeseries.average_time_in_status),
          @section_formatter.format_activity_section(timeseries.daily_status_counts)
        ].compact

        sections.join("\n")
      end

      private

      def header_section
        [
          "\n#{@config.main_header}",
          @config.header_separator
        ].join("\n")
      end
    end

    # Main class for timeseries table formatting
    class TimeseriesTableFormatter
      def initialize(timeseries, formatter: nil, output_handler: nil)
        @timeseries = timeseries
        @formatter = formatter || TimeseriesOutputFormatter.new
        @output_handler = output_handler || method(:puts)
      end

      def print_timeseries
        output = @formatter.format_timeseries(@timeseries)
        @output_handler.call(output)
      end
    end
  end
end
