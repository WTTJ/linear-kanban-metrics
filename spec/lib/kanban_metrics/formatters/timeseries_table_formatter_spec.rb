# frozen_string_literal: true

require 'spec_helper'

RSpec.describe KanbanMetrics::Formatters::TimeseriesTableFormatter do
  subject(:formatter) { described_class.new(timeseries, **dependencies) }

  let(:dependencies) { {} }

  let(:timeseries) do
    double('timeseries',
           status_flow_analysis: {
             'Backlog → In Progress' => 45,
             'In Progress → Done' => 40,
             'Done → Backlog' => 5,
             'Backlog → Done' => 3
           },
           average_time_in_status: {
             'In Progress' => 5.8,
             'Backlog' => 2.5,
             'Done' => 0.1
           },
           daily_status_counts: {
             Date.new(2024, 1, 1) => { 'Backlog' => 3, 'In Progress' => 2 },
             Date.new(2024, 1, 2) => { 'In Progress' => 1, 'Done' => 4 },
             Date.new(2024, 1, 3) => { 'Backlog' => 2, 'Done' => 1 }
           })
  end

  let(:empty_timeseries) do
    double('empty_timeseries',
           status_flow_analysis: {},
           average_time_in_status: {},
           daily_status_counts: {})
  end

  describe '#initialize' do
    let(:timeseries_param) { timeseries }

    it 'creates formatter instance with timeseries object' do
      expect(formatter).to be_a(described_class)
    end

    context 'with custom dependencies' do
      let(:mock_formatter) { instance_double(KanbanMetrics::Formatters::TimeseriesOutputFormatter) }
      let(:mock_output_handler) { spy }
      let(:dependencies) do
        {
          formatter: mock_formatter,
          output_handler: mock_output_handler
        }
      end

      it 'accepts custom dependencies for testing' do
        expect(formatter).to be_a(described_class)
      end
    end
  end

  describe '#print_timeseries' do
    let(:mock_formatter) { instance_double(KanbanMetrics::Formatters::TimeseriesOutputFormatter) }
    let(:captured_output) { [] }
    let(:output_spy) { ->(text) { captured_output << text } }
    let(:dependencies) do
      {
        formatter: mock_formatter,
        output_handler: output_spy
      }
    end
    let(:formatted_output) { 'formatted timeseries output' }

    before do
      allow(mock_formatter).to receive(:format_timeseries).with(timeseries).and_return(formatted_output)
    end

    it 'formats timeseries and outputs result' do
      formatter.print_timeseries

      aggregate_failures do
        expect(mock_formatter).to have_received(:format_timeseries).with(timeseries)
        expect(captured_output).to eq([formatted_output])
      end
    end

    context 'with default dependencies (integration test)' do
      let(:integration_formatter) { described_class.new(timeseries) }

      context 'with complete timeseries data' do
        it 'outputs the main section header and content' do
          output = capture_stdout { integration_formatter.print_timeseries }

          aggregate_failures 'complete output' do
            expect(output).to include('📈 TIMESERIES ANALYSIS')
            expect(output).to include('=' * 80)
            expect(output).to include('🔀 STATUS TRANSITIONS')
            expect(output).to include('⏰ AVERAGE TIME IN STATUS')
            expect(output).to include('📊 RECENT ACTIVITY')
            expect(output).to include('Backlog → In Progress')
            expect(output).to include('45')
          end
        end
      end

      context 'with empty timeseries data' do
        let(:integration_formatter) { described_class.new(empty_timeseries) }

        it 'prints header but no content for empty data' do
          output = capture_stdout { integration_formatter.print_timeseries }

          aggregate_failures 'empty data output' do
            expect(output).to include('📈 TIMESERIES ANALYSIS')
            expect(output).not_to include('🔀 STATUS TRANSITIONS')
            expect(output).not_to include('⏰ AVERAGE TIME IN STATUS')
            expect(output).not_to include('📊 RECENT ACTIVITY')
          end
        end
      end
    end
  end
end

# Supporting classes specs
RSpec.describe KanbanMetrics::Formatters::TimeseriesTableConfig do
  describe 'constants' do
    it 'provides configuration values' do
      aggregate_failures do
        expect(described_class.main_header).to eq('📈 TIMESERIES ANALYSIS')
        expect(described_class.header_separator).to eq('=' * 80)
        expect(described_class.transitions_header).to eq('🔀 STATUS TRANSITIONS (Most Common)')
        expect(described_class.time_in_status_header).to eq('⏰ AVERAGE TIME IN STATUS')
        expect(described_class.recent_activity_header).to eq('📊 RECENT ACTIVITY (Last 10 Days)')
        expect(described_class.transitions_columns).to eq(%w[Transition Count Description])
        expect(described_class.max_transitions).to eq(10)
        expect(described_class.max_recent_days).to eq(10)
        expect(described_class.date_format).to eq('%Y-%m-%d')
      end
    end
  end
end

RSpec.describe KanbanMetrics::Formatters::TransitionsTableBuilder do
  subject(:builder) { described_class.new }

  describe '#build_table' do
    context 'with transition data' do
      let(:flow_analysis) do
        {
          'Backlog → In Progress' => 45,
          'In Progress → Done' => 40,
          'Done → Backlog' => 5
        }
      end

      it 'builds a table with transition data' do
        table = builder.build_table(flow_analysis)

        expect(table).to be_a(Terminal::Table)
        expect(table.to_s).to include('Backlog → In Progress')
        expect(table.to_s).to include('45')
      end
    end

    context 'with empty data' do
      it 'returns nil' do
        result = builder.build_table({})
        expect(result).to be_nil
      end
    end
  end
end

RSpec.describe KanbanMetrics::Formatters::TimeInStatusTableBuilder do
  subject(:builder) { described_class.new }

  describe '#build_table' do
    context 'with time in status data' do
      let(:time_in_status) do
        {
          'In Progress' => 5.8,
          'Backlog' => 2.5,
          'Done' => 0.1
        }
      end

      it 'builds a table with time in status data sorted by time' do
        table = builder.build_table(time_in_status)

        expect(table).to be_a(Terminal::Table)
        table_content = table.to_s
        expect(table_content).to include('In Progress')
        expect(table_content).to include('5.8')

        # Check that it's sorted by time (highest first)
        in_progress_index = table_content.index('In Progress')
        backlog_index = table_content.index('Backlog')
        expect(in_progress_index).to be < backlog_index
      end
    end

    context 'with empty data' do
      it 'returns nil' do
        result = builder.build_table({})
        expect(result).to be_nil
      end
    end
  end
end

RSpec.describe KanbanMetrics::Formatters::ActivityTableBuilder do
  subject(:builder) { described_class.new }

  describe '#build_table' do
    context 'with activity data' do
      let(:daily_counts) do
        {
          Date.new(2024, 1, 1) => { 'Backlog' => 3, 'In Progress' => 2 },
          Date.new(2024, 1, 2) => { 'In Progress' => 1, 'Done' => 4 }
        }
      end

      it 'builds a table with activity data' do
        table = builder.build_table(daily_counts)

        expect(table).to be_a(Terminal::Table)
        expect(table.to_s).to include('2024-01-01')
        expect(table.to_s).to include('Backlog(3)')
        expect(table.to_s).to include('5 total')
      end
    end

    context 'with empty data' do
      it 'returns nil' do
        result = builder.build_table({})
        expect(result).to be_nil
      end
    end
  end
end

RSpec.describe KanbanMetrics::Formatters::TimeseriesSectionFormatter do
  subject(:formatter) { described_class.new }

  let(:flow_analysis) { { 'Backlog → In Progress' => 45 } }
  let(:time_in_status) { { 'In Progress' => 5.8 } }
  let(:daily_counts) { { Date.new(2024, 1, 1) => { 'Backlog' => 3 } } }

  describe '#format_transitions_section' do
    context 'with data' do
      it 'formats transitions section with header and table' do
        result = formatter.format_transitions_section(flow_analysis)

        expect(result).to include('🔀 STATUS TRANSITIONS')
        expect(result).to include('Backlog → In Progress')
      end
    end

    context 'with empty data' do
      it 'returns nil' do
        result = formatter.format_transitions_section({})
        expect(result).to be_nil
      end
    end
  end

  describe '#format_time_in_status_section' do
    context 'with data' do
      it 'formats time in status section with header and table' do
        result = formatter.format_time_in_status_section(time_in_status)

        expect(result).to include('⏰ AVERAGE TIME IN STATUS')
        expect(result).to include('In Progress')
      end
    end

    context 'with empty data' do
      it 'returns nil' do
        result = formatter.format_time_in_status_section({})
        expect(result).to be_nil
      end
    end
  end

  describe '#format_activity_section' do
    context 'with data' do
      it 'formats activity section with header and table' do
        result = formatter.format_activity_section(daily_counts)

        expect(result).to include('📊 RECENT ACTIVITY')
        expect(result).to include('2024-01-01')
      end
    end

    context 'with empty data' do
      it 'returns nil' do
        result = formatter.format_activity_section({})
        expect(result).to be_nil
      end
    end
  end
end

RSpec.describe KanbanMetrics::Formatters::TimeseriesOutputFormatter do
  subject(:formatter) { described_class.new }

  let(:timeseries) do
    double('timeseries',
           status_flow_analysis: { 'Backlog → In Progress' => 45 },
           average_time_in_status: { 'In Progress' => 5.8 },
           daily_status_counts: { Date.new(2024, 1, 1) => { 'Backlog' => 3 } })
  end

  describe '#format_timeseries' do
    it 'formats complete timeseries with header and all sections' do
      result = formatter.format_timeseries(timeseries)

      aggregate_failures do
        expect(result).to include('📈 TIMESERIES ANALYSIS')
        expect(result).to include('=' * 80)
        expect(result).to include('🔀 STATUS TRANSITIONS')
        expect(result).to include('⏰ AVERAGE TIME IN STATUS')
        expect(result).to include('📊 RECENT ACTIVITY')
      end
    end

    context 'with empty timeseries' do
      let(:empty_timeseries) do
        double('empty_timeseries',
               status_flow_analysis: {},
               average_time_in_status: {},
               daily_status_counts: {})
      end

      it 'formats only header when no data' do
        result = formatter.format_timeseries(empty_timeseries)

        aggregate_failures do
          expect(result).to include('📈 TIMESERIES ANALYSIS')
          expect(result).to include('=' * 80)
          expect(result).not_to include('🔀 STATUS TRANSITIONS')
          expect(result).not_to include('⏰ AVERAGE TIME IN STATUS')
          expect(result).not_to include('📊 RECENT ACTIVITY')
        end
      end
    end
  end
end
