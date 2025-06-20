# frozen_string_literal: true

require 'spec_helper'

RSpec.describe KanbanMetrics::Reports::KanbanReport do
  subject(:report) { described_class.new(metrics, team_metrics, timeseries_data) }

  # Shared test data
  let(:sample_metrics) do
    {
      total_issues: 100,
      completed_issues: 60,
      cycle_time: { average: 8.5, median: 6.0 },
      lead_time: { average: 12.3, median: 9.1 },
      throughput: { weekly_avg: 15.2, total_completed: 60 },
      flow_efficiency: 65.5
    }
  end

  let(:sample_team_metrics) do
    {
      'Backend Team' => { total_issues: 60, completed_issues: 40 },
      'Frontend Team' => { total_issues: 40, completed_issues: 20 }
    }
  end

  let(:sample_timeseries) do
    instance_double(KanbanMetrics::Timeseries::TicketTimeseries).tap do |mock|
      allow(mock).to receive_messages(status_flow_analysis: {}, average_time_in_status: {}, daily_status_counts: {})
    end
  end

  describe '#initialize' do
    context 'with metrics only' do
      let(:metrics) { sample_metrics }
      let(:team_metrics) { nil }
      let(:timeseries_data) { nil }

      it 'creates a report instance with basic metrics' do
        # Given: Only basic metrics
        # When: Creating a new report
        # Then: Should create a valid report instance
        expect(report).to be_a(described_class)
      end
    end

    context 'with metrics and team metrics' do
      let(:metrics) { sample_metrics }
      let(:team_metrics) { sample_team_metrics }
      let(:timeseries_data) { nil }

      it 'creates a report instance with team metrics' do
        # Given: Metrics and team metrics
        # When: Creating a new report
        # Then: Should create a valid report instance
        expect(report).to be_a(described_class)
      end
    end

    context 'with all parameters' do
      let(:metrics) { sample_metrics }
      let(:team_metrics) { sample_team_metrics }
      let(:timeseries_data) { sample_timeseries }

      it 'creates a report instance with all data' do
        # Given: All available data types
        # When: Creating a new report
        # Then: Should create a valid report instance
        expect(report).to be_a(described_class)
      end
    end
  end

  describe '#display' do
    context 'when format is JSON' do
      let(:metrics) { sample_metrics }
      let(:team_metrics) { sample_team_metrics }
      let(:timeseries_data) { sample_timeseries }
      let(:mock_json_formatter) { instance_double(KanbanMetrics::Formatters::JsonFormatter) }
      let(:expected_json) { '{"test":"json"}' }

      it 'uses JsonFormatter and outputs JSON to stdout' do
        # Given: A report with all data and a mocked JSON formatter
        allow(KanbanMetrics::Formatters::JsonFormatter).to receive(:new)
          .with(sample_metrics, sample_team_metrics, sample_timeseries)
          .and_return(mock_json_formatter)
        allow(mock_json_formatter).to receive(:generate).and_return(expected_json)

        # When: Displaying in JSON format
        output = capture_stdout { report.display('json') }

        # Then: Should output formatted JSON
        expect(output).to eq("#{expected_json}\n")
      end
    end

    context 'when format is CSV' do
      let(:metrics) { sample_metrics }
      let(:team_metrics) { sample_team_metrics }
      let(:timeseries_data) { sample_timeseries }
      let(:mock_csv_formatter) { instance_double(KanbanMetrics::Formatters::CsvFormatter) }
      let(:expected_csv) { 'csv,data,header' }

      it 'uses CsvFormatter and outputs CSV to stdout' do
        # Given: A report with all data and a mocked CSV formatter
        allow(KanbanMetrics::Formatters::CsvFormatter).to receive(:new)
          .with(sample_metrics, sample_team_metrics, sample_timeseries)
          .and_return(mock_csv_formatter)
        allow(mock_csv_formatter).to receive(:generate).and_return(expected_csv)

        # When: Displaying in CSV format
        output = capture_stdout { report.display('csv') }

        # Then: Should output formatted CSV
        expect(output).to eq("#{expected_csv}\n")
      end
    end

    context 'when format is table (default)' do
      let(:metrics) { sample_metrics }
      let(:team_metrics) { sample_team_metrics }
      let(:timeseries_data) { nil }
      let(:mock_table_formatter) { instance_double(KanbanMetrics::Formatters::TableFormatter) }

      before do
        # Setup table formatter mock
        allow(KanbanMetrics::Formatters::TableFormatter).to receive(:new)
          .with(sample_metrics, sample_team_metrics)
          .and_return(mock_table_formatter)
        setup_table_formatter_stubs
      end

      it 'displays all table sections in correct order' do
        # Given: A report with metrics and team metrics
        # When: Displaying in table format
        report.display('table')

        # Then: Should call all formatter methods in sequence
        aggregate_failures do
          expect(mock_table_formatter).to have_received(:print_summary)
          expect(mock_table_formatter).to have_received(:print_cycle_time)
          expect(mock_table_formatter).to have_received(:print_lead_time)
          expect(mock_table_formatter).to have_received(:print_throughput)
          expect(mock_table_formatter).to have_received(:print_kpi_definitions)
        end
      end

      it 'displays team metrics when available' do
        # Given: A report with team metrics
        # When: Displaying in table format
        report.display('table')

        # Then: Should display team metrics
        expect(mock_table_formatter).to have_received(:print_team_metrics)
      end

      it 'defaults to table format when no format specified' do
        # Given: A report instance
        # When: Displaying without format parameter
        report.display

        # Then: Should use table format
        expect(mock_table_formatter).to have_received(:print_summary)
      end

      private

      def setup_table_formatter_stubs
        allow(mock_table_formatter).to receive(:print_summary)
        allow(mock_table_formatter).to receive(:print_cycle_time)
        allow(mock_table_formatter).to receive(:print_lead_time)
        allow(mock_table_formatter).to receive(:print_throughput)
        allow(mock_table_formatter).to receive(:print_team_metrics)
        allow(mock_table_formatter).to receive(:print_kpi_definitions)
      end
    end

    context 'when timeseries data is present and format is table' do
      let(:metrics) { sample_metrics }
      let(:team_metrics) { nil }
      let(:timeseries_data) { sample_timeseries }
      let(:mock_table_formatter) { instance_double(KanbanMetrics::Formatters::TableFormatter) }
      let(:mock_timeseries_formatter) { instance_double(KanbanMetrics::Formatters::TimeseriesTableFormatter) }

      before do
        setup_formatters
      end

      it 'displays timeseries data in addition to standard metrics' do
        # Given: A report with timeseries data
        # When: Displaying in table format
        report.display('table')

        # Then: Should display timeseries data
        expect(mock_timeseries_formatter).to have_received(:print_timeseries)
      end

      it 'does not display timeseries for non-table formats' do
        # Given: A report with timeseries data and mocked JSON formatter
        mock_json_formatter = instance_double(KanbanMetrics::Formatters::JsonFormatter)
        allow(KanbanMetrics::Formatters::JsonFormatter).to receive(:new)
          .and_return(mock_json_formatter)
        allow(mock_json_formatter).to receive(:generate).and_return('{}')

        # When: Displaying in JSON format
        capture_stdout { report.display('json') }

        # Then: Should not create timeseries formatter
        expect(KanbanMetrics::Formatters::TimeseriesTableFormatter).not_to have_received(:new)
      end

      private

      def setup_formatters
        allow(KanbanMetrics::Formatters::TableFormatter).to receive(:new)
          .and_return(mock_table_formatter)
        allow(mock_table_formatter).to receive(:print_summary)
        allow(mock_table_formatter).to receive(:print_cycle_time)
        allow(mock_table_formatter).to receive(:print_lead_time)
        allow(mock_table_formatter).to receive(:print_throughput)
        allow(mock_table_formatter).to receive(:print_team_metrics)
        allow(mock_table_formatter).to receive(:print_kpi_definitions)

        allow(KanbanMetrics::Formatters::TimeseriesTableFormatter).to receive(:new)
          .with(sample_timeseries)
          .and_return(mock_timeseries_formatter)
        allow(mock_timeseries_formatter).to receive(:print_timeseries)
      end
    end

    context 'when team metrics are not provided' do
      let(:metrics) { sample_metrics }
      let(:team_metrics) { nil }
      let(:timeseries_data) { nil }
      let(:mock_table_formatter) { instance_double(KanbanMetrics::Formatters::TableFormatter) }

      before do
        allow(KanbanMetrics::Formatters::TableFormatter).to receive(:new)
          .with(sample_metrics, nil)
          .and_return(mock_table_formatter)
        setup_table_formatter_stubs
      end

      it 'does not attempt to print team metrics' do
        # Given: A report without team metrics
        # When: Displaying in table format
        report.display('table')

        # Then: Should not call print_team_metrics
        expect(mock_table_formatter).not_to have_received(:print_team_metrics)
      end

      private

      def setup_table_formatter_stubs
        allow(mock_table_formatter).to receive(:print_summary)
        allow(mock_table_formatter).to receive(:print_cycle_time)
        allow(mock_table_formatter).to receive(:print_lead_time)
        allow(mock_table_formatter).to receive(:print_throughput)
        allow(mock_table_formatter).to receive(:print_team_metrics)
        allow(mock_table_formatter).to receive(:print_kpi_definitions)
      end
    end

    context 'when timeseries data is not provided' do
      let(:metrics) { sample_metrics }
      let(:team_metrics) { nil }
      let(:timeseries_data) { nil }
      let(:mock_table_formatter) { instance_double(KanbanMetrics::Formatters::TableFormatter) }

      before do
        allow(KanbanMetrics::Formatters::TableFormatter).to receive(:new)
          .and_return(mock_table_formatter)
        setup_table_formatter_stubs
      end

      it 'does not attempt to display timeseries' do
        # Given: A report without timeseries data
        # When: Displaying in table format
        report.display('table')

        # Then: Should not create timeseries formatter
        expect(KanbanMetrics::Formatters::TimeseriesTableFormatter).not_to receive(:new)
      end

      private

      def setup_table_formatter_stubs
        allow(mock_table_formatter).to receive(:print_summary)
        allow(mock_table_formatter).to receive(:print_cycle_time)
        allow(mock_table_formatter).to receive(:print_lead_time)
        allow(mock_table_formatter).to receive(:print_throughput)
        allow(mock_table_formatter).to receive(:print_kpi_definitions)
      end
    end
  end

  describe 'private methods' do
    let(:metrics) { sample_metrics }
    let(:team_metrics) { sample_team_metrics }
    let(:timeseries_data) { nil }

    describe '#display_table_format' do
      let(:mock_table_formatter) { instance_double(KanbanMetrics::Formatters::TableFormatter) }

      it 'creates TableFormatter and calls all print methods in sequence' do
        # Given: A report with metrics and team metrics
        allow(KanbanMetrics::Formatters::TableFormatter).to receive(:new)
          .with(sample_metrics, sample_team_metrics)
          .and_return(mock_table_formatter)
        setup_table_formatter_stubs

        # When: Calling display_table_format
        report.send(:display_table_format)

        # Then: Should create formatter and call all methods
        aggregate_failures do
          expect(KanbanMetrics::Formatters::TableFormatter).to have_received(:new)
            .with(sample_metrics, sample_team_metrics)

          # And: Should call all print methods
          expect(mock_table_formatter).to have_received(:print_summary)
          expect(mock_table_formatter).to have_received(:print_cycle_time)
          expect(mock_table_formatter).to have_received(:print_lead_time)
          expect(mock_table_formatter).to have_received(:print_throughput)
          expect(mock_table_formatter).to have_received(:print_team_metrics)
          expect(mock_table_formatter).to have_received(:print_kpi_definitions)
        end
      end

      private

      def setup_table_formatter_stubs
        allow(mock_table_formatter).to receive(:print_summary)
        allow(mock_table_formatter).to receive(:print_cycle_time)
        allow(mock_table_formatter).to receive(:print_lead_time)
        allow(mock_table_formatter).to receive(:print_throughput)
        allow(mock_table_formatter).to receive(:print_team_metrics)
        allow(mock_table_formatter).to receive(:print_kpi_definitions)
      end
    end

    describe '#display_timeseries' do
      let(:metrics) { sample_metrics }
      let(:team_metrics) { nil }
      let(:timeseries_data) { sample_timeseries }
      let(:mock_timeseries_formatter) { instance_double(KanbanMetrics::Formatters::TimeseriesTableFormatter) }

      it 'creates TimeseriesTableFormatter and prints timeseries data' do
        # Given: A report with timeseries data
        allow(KanbanMetrics::Formatters::TimeseriesTableFormatter).to receive(:new)
          .with(sample_timeseries)
          .and_return(mock_timeseries_formatter)
        allow(mock_timeseries_formatter).to receive(:print_timeseries)

        # When: Calling display_timeseries
        report.send(:display_timeseries)

        # Then: Should create formatter and print timeseries
        aggregate_failures do
          expect(KanbanMetrics::Formatters::TimeseriesTableFormatter).to have_received(:new)
            .with(sample_timeseries)
          expect(mock_timeseries_formatter).to have_received(:print_timeseries)
        end
      end
    end
  end

  describe 'error handling and edge cases' do
    let(:metrics) { sample_metrics }
    let(:team_metrics) { nil }
    let(:timeseries_data) { nil }

    context 'when unknown format is provided' do
      it 'handles unknown format gracefully without raising error' do
        # Given: A report instance
        # When: Displaying with unknown format
        # Then: Should not raise an error
        expect { report.display('unknown_format') }.not_to raise_error
      end

      it 'defaults to table format for unknown formats' do
        # Given: A report instance and mocked table formatter
        mock_table_formatter = instance_double(KanbanMetrics::Formatters::TableFormatter)
        allow(KanbanMetrics::Formatters::TableFormatter).to receive(:new)
          .and_return(mock_table_formatter)
        setup_table_formatter_stubs(mock_table_formatter)

        # When: Displaying with unknown format
        report.display('unknown_format')

        # Then: Should use table format as fallback
        expect(mock_table_formatter).to have_received(:print_summary)
      end

      private

      def setup_table_formatter_stubs(formatter)
        allow(formatter).to receive(:print_summary)
        allow(formatter).to receive(:print_cycle_time)
        allow(formatter).to receive(:print_lead_time)
        allow(formatter).to receive(:print_throughput)
        allow(formatter).to receive(:print_kpi_definitions)
      end
    end
  end
end
