# frozen_string_literal: true

module KanbanMetrics
  module Reports
    # Main report coordination class
    class KanbanReport
      def initialize(metrics, team_metrics = nil, timeseries = nil, issues = nil)
        @metrics = metrics
        @team_metrics = team_metrics
        @timeseries = timeseries
        @issues = issues
      end

      def display(format = 'table')
        case format
        when 'json'
          puts Formatters::JsonFormatter.new(@metrics, @team_metrics, @timeseries, @issues).generate
        when 'csv'
          puts Formatters::CsvFormatter.new(@metrics, @team_metrics, @timeseries, @issues).generate
        else
          display_table_format
        end

        display_timeseries if @timeseries && format == 'table'
      end

      private

      def display_table_format
        formatter = Formatters::TableFormatter.new(@metrics, @team_metrics, @issues)

        formatter.print_summary
        formatter.print_cycle_time
        formatter.print_lead_time
        formatter.print_throughput
        formatter.print_team_metrics if @team_metrics
        formatter.print_individual_tickets if @issues
        formatter.print_kpi_definitions
      end

      def display_timeseries
        Formatters::TimeseriesTableFormatter.new(@timeseries).print_timeseries
      end
    end
  end
end
