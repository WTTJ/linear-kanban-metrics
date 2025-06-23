# frozen_string_literal: true

module KanbanMetrics
  module Reports
    # Value object to encapsulate report data
    class ReportData
      attr_reader :metrics, :team_metrics, :timeseries, :issues

      def initialize(metrics:, team_metrics: nil, timeseries: nil, issues: nil)
        @metrics = metrics
        @team_metrics = team_metrics
        @timeseries = timeseries
        @issues = issues
      end

      def has_team_metrics?
        !@team_metrics.nil?
      end

      def has_timeseries?
        !@timeseries.nil?
      end

      def has_issues?
        !@issues.nil?
      end
    end

    # Strategy for handling different output formats
    class FormatStrategy
      def self.for(format)
        case format
        when 'json'
          JsonFormatStrategy.new
        when 'csv'
          CsvFormatStrategy.new
        else
          TableFormatStrategy.new
        end
      end
    end

    # JSON output strategy
    class JsonFormatStrategy
      def display(report_data)
        content = Formatters::JsonFormatter.new(
          report_data.metrics,
          report_data.team_metrics,
          report_data.timeseries,
          report_data.issues
        ).generate
        puts content
      end
    end

    # CSV output strategy
    class CsvFormatStrategy
      def display(report_data)
        content = Formatters::CsvFormatter.new(
          report_data.metrics,
          report_data.team_metrics,
          report_data.timeseries,
          report_data.issues
        ).generate
        puts content
      end
    end

    # Table output strategy with timeseries support
    class TableFormatStrategy
      def display(report_data)
        display_table_report(report_data)
        display_timeseries_report(report_data) if report_data.has_timeseries?
      end

      private

      def display_table_report(report_data)
        formatter = create_table_formatter(report_data)

        formatter.print_summary
        formatter.print_cycle_time
        formatter.print_lead_time
        formatter.print_throughput
        formatter.print_team_metrics if report_data.has_team_metrics?
        formatter.print_individual_tickets if report_data.has_issues?
        formatter.print_kpi_definitions
      end

      def display_timeseries_report(report_data)
        Formatters::TimeseriesTableFormatter.new(report_data.timeseries).print_timeseries
      end

      def create_table_formatter(report_data)
        Formatters::TableFormatter.new(
          report_data.metrics,
          report_data.team_metrics,
          report_data.issues
        )
      end
    end

    # Service object for report display coordination
    class ReportDisplayService
      def display(report_data, format = 'table')
        strategy = FormatStrategy.for(format)
        strategy.display(report_data)
      end
    end

    # Main report coordination class
    class KanbanReport
      def initialize(metrics, team_metrics = nil, timeseries = nil, issues = nil)
        @report_data = ReportData.new(
          metrics: metrics,
          team_metrics: team_metrics,
          timeseries: timeseries,
          issues: issues
        )
        @display_service = ReportDisplayService.new
      end

      def display(format = 'table')
        @display_service.display(@report_data, format)
      end
    end
  end
end
