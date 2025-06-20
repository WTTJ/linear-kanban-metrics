# frozen_string_literal: true

module KanbanMetrics
  module Reports
    # Handles timeline display for individual issues
    class TimelineDisplay
      def initialize(issues)
        @issues = issues
      end

      def show_timeline(issue_id)
        timeline_data = find_timeline_data(issue_id)

        if timeline_data
          print_timeline(timeline_data)
        else
          puts "❌ Issue #{issue_id} not found"
        end
      end

      private

      def find_timeline_data(issue_id)
        timeseries = Timeseries::TicketTimeseries.new(@issues)
        timeseries.generate_timeseries.find { |t| t[:id] == issue_id }
      end

      def print_timeline(timeline_data)
        puts "\n📈 TIMELINE FOR #{timeline_data[:id]}: #{timeline_data[:title]}"
        puts "Team: #{timeline_data[:team]}"
        puts '=' * 80

        timeline_data[:timeline].each do |event|
          date_str = DateTime.parse(event[:date]).strftime('%Y-%m-%d %H:%M')
          transition = event[:from_state] ? "#{event[:from_state]} →" : 'Created →'
          puts "#{date_str} | #{transition} #{event[:to_state]}"
        end
      end
    end
  end
end
