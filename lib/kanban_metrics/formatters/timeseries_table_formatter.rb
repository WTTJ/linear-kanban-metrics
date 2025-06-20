# frozen_string_literal: true

require 'terminal-table'
require 'date'

module KanbanMetrics
  module Formatters
    # Handles timeseries table formatting for console output
    class TimeseriesTableFormatter
      def initialize(timeseries)
        @timeseries = timeseries
      end

      def print_timeseries
        puts "\n📈 TIMESERIES ANALYSIS"
        puts '=' * 80

        print_status_transitions
        print_time_in_status
        print_recent_activity
      end

      private

      def print_status_transitions
        flow_analysis = @timeseries.status_flow_analysis
        return if flow_analysis.empty?

        puts "\n🔀 STATUS TRANSITIONS (Most Common)"
        table = build_transitions_table(flow_analysis)
        puts table
      end

      def print_time_in_status
        time_in_status = @timeseries.average_time_in_status
        return if time_in_status.empty?

        puts "\n⏰ AVERAGE TIME IN STATUS"
        table = build_time_in_status_table(time_in_status)
        puts table
      end

      def print_recent_activity
        daily_counts = @timeseries.daily_status_counts
        return if daily_counts.empty?

        puts "\n📊 RECENT ACTIVITY (Last 10 Days)"
        table = build_activity_table(daily_counts)
        puts table
      end

      def build_transitions_table(flow_analysis)
        Terminal::Table.new do |tab|
          tab.headings = %w[Transition Count Description]
          flow_analysis.first(10).each do |transition, count|
            tab.add_row [transition, count, 'Number of times this transition occurred']
          end
        end
      end

      def build_time_in_status_table(time_in_status)
        Terminal::Table.new do |tab|
          tab.headings = ['Status', 'Average Days', 'Description']
          time_in_status.sort_by { |_, days| -days }.each do |status, days|
            tab.add_row [status, days, 'Average time issues spend in this status']
          end
        end
      end

      def build_activity_table(daily_counts)
        recent_days = daily_counts.keys.last(10)

        Terminal::Table.new do |tab|
          tab.headings = ['Date', 'Status Changes', 'Description']
          recent_days.each do |date|
            changes = daily_counts[date]
            total_changes = changes.values.sum
            status_summary = changes.map { |status, count| "#{status}(#{count})" }.join(', ')
            tab.add_row [date.strftime('%Y-%m-%d'), "#{total_changes} total: #{status_summary}",
                         'Daily status change activity']
          end
        end
      end
    end
  end
end
