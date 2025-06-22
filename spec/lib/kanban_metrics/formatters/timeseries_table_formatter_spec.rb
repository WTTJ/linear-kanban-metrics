# frozen_string_literal: true

require 'spec_helper'

RSpec.describe KanbanMetrics::Formatters::TimeseriesTableFormatter do
  # Test Data Setup
  subject(:formatter) { described_class.new(timeseries_param) }

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
    # Setup
    let(:timeseries_param) { timeseries }

    it 'creates formatter instance with timeseries object' do
      # Execute & Verify
      expect(formatter).to be_a(described_class)
    end
  end

  describe '#print_timeseries' do
    subject(:print_timeseries) { formatter.print_timeseries }

    context 'with complete timeseries data' do
      # Setup
      let(:timeseries_param) { timeseries }

      it 'prints timeseries without errors' do
        # Execute & Verify
        expect { print_timeseries }.not_to raise_error
      end

      it 'outputs the main section header' do
        # Execute & Verify
        expect { print_timeseries }.to output(/📈 TIMESERIES ANALYSIS/).to_stdout
      end

      it 'outputs section separators' do
        # Execute & Verify
        expect { print_timeseries }.to output(/={80}/).to_stdout
      end

      it 'calls all subsection methods' do
        # Setup
        expect(formatter).to receive(:print_status_transitions)
        expect(formatter).to receive(:print_time_in_status)
        expect(formatter).to receive(:print_recent_activity)

        # Execute
        print_timeseries
      end
    end

    context 'with empty timeseries data' do
      # Setup
      let(:timeseries_param) { empty_timeseries }

      it 'prints header but no content for empty data' do
        # Execute
        output = capture_stdout { print_timeseries }

        # Verify
        aggregate_failures 'empty data output' do
          expect(output).to include('📈 TIMESERIES ANALYSIS')
          expect(output).not_to include('🔀 STATUS TRANSITIONS')
          expect(output).not_to include('⏰ AVERAGE TIME IN STATUS')
          expect(output).not_to include('📊 RECENT ACTIVITY')
        end
      end
    end
  end

  describe '#print_status_transitions' do
    subject(:print_status_transitions) { formatter.send(:print_status_transitions) }

    context 'with status transition data' do
      # Setup
      let(:timeseries_param) { timeseries }

      it 'prints status transitions section content' do
        # Execute
        output = capture_stdout { print_status_transitions }

        # Verify
        aggregate_failures 'status transitions content' do
          expect(output).to include('🔀 STATUS TRANSITIONS')
          expect(output).to include('Backlog → In Progress')
          expect(output).to include('In Progress → Done')
          expect(output).to include('45')
          expect(output).to include('40')
        end
      end

      it 'includes transition table headers' do
        # Execute
        output = capture_stdout { print_status_transitions }

        # Verify
        aggregate_failures 'transition headers' do
          expect(output).to include('Count')
          expect(output).to include('Description')
        end
      end
    end

    context 'with empty flow analysis' do
      # Setup
      let(:timeseries_param) { empty_timeseries }

      it 'does not print section when no data' do
        # Execute
        output = capture_stdout { print_status_transitions }

        # Verify
        expect(output).to be_empty
      end
    end
  end

  describe '#print_time_in_status' do
    subject(:print_time_in_status) { formatter.send(:print_time_in_status) }

    context 'with time in status data' do
      # Setup
      let(:timeseries_param) { timeseries }

      it 'prints time in status section content' do
        # Execute
        output = capture_stdout { print_time_in_status }

        # Verify
        aggregate_failures 'time in status content' do
          expect(output).to include('⏰ AVERAGE TIME IN STATUS')
          expect(output).to include('In Progress')
          expect(output).to include('Backlog')
          expect(output).to include('Done')
          expect(output).to include('5.8')
          expect(output).to include('2.5')
        end
      end

      it 'sorts by time descending' do
        # Execute
        output = capture_stdout { print_time_in_status }
        lines = output.split("\n")

        # Verify
        in_progress_line = lines.find { |line| line.include?('In Progress') }
        backlog_line = lines.find { |line| line.include?('Backlog') }

        expect(lines.index(in_progress_line)).to be < lines.index(backlog_line)
      end
    end

    context 'with empty time in status data' do
      # Setup
      let(:timeseries_param) { empty_timeseries }

      it 'does not print section when no data' do
        # Execute
        output = capture_stdout { print_time_in_status }

        # Verify
        expect(output).to be_empty
      end
    end
  end

  describe '#print_recent_activity' do
    subject(:print_recent_activity) { formatter.send(:print_recent_activity) }

    context 'with daily activity data' do
      # Setup
      let(:timeseries_param) { timeseries }

      it 'prints recent activity section content' do
        # Execute
        output = capture_stdout { print_recent_activity }

        # Verify
        aggregate_failures 'recent activity content' do
          expect(output).to include('📊 RECENT ACTIVITY')
          expect(output).to include('2024-01-01')
          expect(output).to include('2024-01-02')
          expect(output).to include('2024-01-03')
        end
      end

      it 'includes daily status counts' do
        # Execute
        output = capture_stdout { print_recent_activity }

        # Verify
        aggregate_failures 'daily status counts' do
          expect(output).to include('Status Changes')
          expect(output).to include('Backlog(3)')
          expect(output).to include('In Progress(2)')
          expect(output).to include('Done(4)')
        end
      end
    end

    context 'with empty daily counts' do
      # Setup
      let(:timeseries_param) { empty_timeseries }

      it 'does not print section when no data' do
        # Execute
        output = capture_stdout { print_recent_activity }

        # Verify
        expect(output).to be_empty
      end
    end
  end

  describe 'private methods' do
    # Setup
    let(:timeseries_param) { timeseries }

    describe '#build_transitions_table' do
      subject(:build_transitions_table) { formatter.send(:build_transitions_table, flow_analysis) }

      context 'with basic flow analysis' do
        # Setup
        let(:flow_analysis) { { 'Backlog → Done' => 10 } }

        it 'creates a Terminal::Table instance' do
          # Execute
          result = build_transitions_table

          # Verify
          expect(result).to be_a(Terminal::Table)
        end

        it 'includes correct headings' do
          # Execute
          result = build_transitions_table
          headings = result.headings.first.cells.map(&:value)

          # Verify
          expect(headings).to eq(%w[Transition Count Description])
        end
      end

      context 'with large flow analysis' do
        # Setup
        let(:flow_analysis) { (1..15).to_h { |i| ["Transition #{i}", i] } }

        it 'limits to first 10 entries' do
          # Execute
          result = build_transitions_table

          # Verify
          expect(result.rows.length).to eq(10)
        end
      end
    end

    describe '#build_time_in_status_table' do
      subject(:build_time_in_status_table) { formatter.send(:build_time_in_status_table, time_data) }

      context 'with basic time data' do
        # Setup
        let(:time_data) { { 'Status' => 5.0 } }

        it 'creates a Terminal::Table instance' do
          # Execute
          result = build_time_in_status_table

          # Verify
          expect(result).to be_a(Terminal::Table)
        end

        it 'includes correct headings' do
          # Execute
          result = build_time_in_status_table
          headings = result.headings.first.cells.map(&:value)

          # Verify
          expect(headings).to eq(['Status', 'Average Days', 'Description'])
        end
      end

      context 'with multiple time data' do
        # Setup
        let(:time_data) { { 'Fast' => 1.0, 'Slow' => 10.0, 'Medium' => 5.0 } }

        it 'sorts by time descending' do
          # Execute
          result = build_time_in_status_table

          # Verify
          aggregate_failures 'sorted time data' do
            expect(result.rows[0][0].value).to eq('Slow')
            expect(result.rows[1][0].value).to eq('Medium')
            expect(result.rows[2][0].value).to eq('Fast')
          end
        end
      end
    end

    describe '#build_activity_table' do
      subject(:build_activity_table) { formatter.send(:build_activity_table, daily_data) }

      context 'with basic daily data' do
        # Setup
        let(:daily_data) { { Date.new(2024, 1, 1) => { 'Status' => 1 } } }

        it 'creates a Terminal::Table instance' do
          # Execute
          result = build_activity_table

          # Verify
          expect(result).to be_a(Terminal::Table)
        end

        it 'includes correct headings' do
          # Execute
          result = build_activity_table
          headings = result.headings.first.cells.map(&:value)

          # Verify
          expect(headings).to eq(['Date', 'Status Changes', 'Description'])
        end
      end

      context 'with large daily data' do
        # Setup
        let(:daily_data) { (1..15).to_h { |i| [Date.new(2024, 1, i), { 'Status' => 1 }] } }

        it 'limits to last 10 days' do
          # Execute
          result = build_activity_table

          # Verify
          aggregate_failures 'activity table limits' do
            expect(result.rows.length).to eq(10)
            expect(result.rows.first[0].value).to eq('2024-01-06') # Should start from day 6
          end
        end
      end

      context 'with status summary data' do
        # Setup
        let(:daily_data) { { Date.new(2024, 1, 1) => { 'Done' => 3, 'Backlog' => 2 } } }

        it 'formats status summary correctly' do
          # Execute
          result = build_activity_table

          # Verify
          aggregate_failures 'status summary format' do
            expect(result.rows.first[1].value).to include('5 total')
            expect(result.rows.first[1].value).to include('Done(3)')
            expect(result.rows.first[1].value).to include('Backlog(2)')
          end
        end
      end
    end
  end
end
