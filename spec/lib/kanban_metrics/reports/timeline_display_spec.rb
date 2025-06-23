# frozen_string_literal: true

require 'spec_helper'

RSpec.describe KanbanMetrics::Reports::TimelineDisplay do
  subject(:timeline_display) { described_class.new(issues, **dependencies) }

  let(:dependencies) { {} }

  # Shared test data
  let(:sample_issues) do
    [
      {
        'id' => 'issue-1',
        'title' => 'Test Issue 1',
        'team' => { 'name' => 'Backend Team' }
      },
      {
        'id' => 'issue-2',
        'title' => 'Test Issue 2',
        'team' => { 'name' => 'Frontend Team' }
      }
    ]
  end

  let(:sample_timeline_data) do
    [
      {
        id: 'issue-1',
        title: 'Test Issue 1',
        team: 'Backend Team',
        timeline: [
          {
            date: '2024-01-01T10:00:00Z',
            from_state: nil,
            to_state: 'Backlog'
          },
          {
            date: '2024-01-02T10:00:00Z',
            from_state: 'Backlog',
            to_state: 'In Progress'
          },
          {
            date: '2024-01-05T10:00:00Z',
            from_state: 'In Progress',
            to_state: 'Done'
          }
        ]
      }
    ]
  end

  describe '#initialize' do
    context 'with an array of issues' do
      let(:issues) { sample_issues }

      it 'creates a timeline display instance' do
        expect(timeline_display).to be_a(described_class)
      end
    end

    context 'with empty array' do
      let(:issues) { [] }

      it 'creates a timeline display instance with empty issues' do
        expect(timeline_display).to be_a(described_class)
      end
    end

    context 'with custom dependencies' do
      let(:issues) { sample_issues }
      let(:mock_data_service) { instance_double(KanbanMetrics::Reports::TimelineDataService) }
      let(:mock_formatter) { instance_double(KanbanMetrics::Reports::TimelineFormatter) }
      let(:mock_output_handler) { spy }
      let(:dependencies) do
        {
          data_service: mock_data_service,
          formatter: mock_formatter,
          output_handler: mock_output_handler
        }
      end

      it 'accepts custom dependencies for testing' do
        expect(timeline_display).to be_a(described_class)
      end
    end
  end

  describe '#show_timeline' do
    let(:issues) { sample_issues }
    let(:mock_data_service) { instance_double(KanbanMetrics::Reports::TimelineDataService) }
    let(:mock_formatter) { instance_double(KanbanMetrics::Reports::TimelineFormatter) }
    let(:captured_output) { [] }
    let(:output_spy) { ->(text) { captured_output << text } }
    let(:dependencies) do
      {
        data_service: mock_data_service,
        formatter: mock_formatter,
        output_handler: output_spy
      }
    end

    context 'when issue exists with timeline data' do
      let(:timeline_data) { sample_timeline_data.first }
      let(:formatted_output) { 'formatted timeline output' }

      before do
        allow(mock_data_service).to receive(:find_timeline_data).with('issue-1').and_return(timeline_data)
        allow(mock_formatter).to receive(:format_timeline).with(timeline_data).and_return(formatted_output)
      end

      it 'retrieves timeline data and formats output correctly' do
        timeline_display.show_timeline('issue-1')

        aggregate_failures do
          expect(mock_data_service).to have_received(:find_timeline_data).with('issue-1')
          expect(mock_formatter).to have_received(:format_timeline).with(timeline_data)
          expect(captured_output).to eq([formatted_output])
        end
      end
    end

    context 'when issue does not exist' do
      let(:not_found_message) { '❌ Issue non-existent not found' }

      before do
        allow(mock_data_service).to receive(:find_timeline_data).with('non-existent').and_return(nil)
        allow(mock_formatter).to receive(:format_not_found_message).with('non-existent').and_return(not_found_message)
      end

      it 'displays not found message' do
        timeline_display.show_timeline('non-existent')

        aggregate_failures do
          expect(mock_data_service).to have_received(:find_timeline_data).with('non-existent')
          expect(mock_formatter).to have_received(:format_not_found_message).with('non-existent')
          expect(captured_output).to eq([not_found_message])
        end
      end
    end

    context 'with default dependencies (integration test)' do
      let(:issues) { sample_issues }
      let(:mock_timeseries) { instance_double(KanbanMetrics::Timeseries::TicketTimeseries) }
      let(:integration_display) { described_class.new(issues) }

      before do
        allow(KanbanMetrics::Timeseries::TicketTimeseries).to receive(:new)
          .with(sample_issues)
          .and_return(mock_timeseries)
      end

      context 'when issue exists' do
        it 'displays complete timeline with all events and formatting' do
          allow(mock_timeseries).to receive(:generate_timeseries).and_return(sample_timeline_data)

          output = capture_stdout { integration_display.show_timeline('issue-1') }

          aggregate_failures do
            expect(output).to include('📈 TIMELINE FOR issue-1: Test Issue 1')
            expect(output).to include('Team: Backend Team')
            expect(output).to include('=' * 80)
            expect(output).to include('2024-01-01 10:00 | Created → Backlog')
            expect(output).to include('2024-01-02 10:00 | Backlog → In Progress')
            expect(output).to include('2024-01-05 10:00 | In Progress → Done')
          end
        end
      end

      context 'when issue does not exist' do
        it 'displays not found message' do
          allow(mock_timeseries).to receive(:generate_timeseries).and_return([])

          output = capture_stdout { integration_display.show_timeline('non-existent') }

          expect(output).to include('❌ Issue non-existent not found')
        end
      end
    end
  end
end

# Supporting classes specs
RSpec.describe KanbanMetrics::Reports::TimelineDisplayConfig do
  describe 'constants' do
    it 'provides configuration values' do
      aggregate_failures do
        expect(described_class.header_separator).to eq('=' * 80)
        expect(described_class.date_format).to eq('%Y-%m-%d %H:%M')
        expect(described_class.timeline_emoji).to eq('📈')
        expect(described_class.error_emoji).to eq('❌')
        expect(described_class.arrow_symbol).to eq('→')
        expect(described_class.separator_symbol).to eq('|')
        expect(described_class.created_state).to eq('Created')
      end
    end
  end
end

RSpec.describe KanbanMetrics::Reports::TimelineDataService do
  subject(:service) { described_class.new(issues, timeseries_generator) }

  let(:issues) { [{ 'id' => 'test-issue' }] }
  let(:timeseries_generator) { ->(_data) { sample_timeline_data } }
  let(:sample_timeline_data) do
    [
      { id: 'test-issue', title: 'Test Issue' },
      { id: 'other-issue', title: 'Other Issue' }
    ]
  end

  describe '#find_timeline_data' do
    context 'when issue exists' do
      it 'returns the timeline data for the issue' do
        result = service.find_timeline_data('test-issue')
        expect(result).to eq({ id: 'test-issue', title: 'Test Issue' })
      end
    end

    context 'when issue does not exist' do
      it 'returns nil' do
        result = service.find_timeline_data('non-existent')
        expect(result).to be_nil
      end
    end

    context 'with default generator' do
      subject(:service) { described_class.new(issues) }

      let(:mock_timeseries) { instance_double(KanbanMetrics::Timeseries::TicketTimeseries) }

      before do
        allow(KanbanMetrics::Timeseries::TicketTimeseries).to receive(:new).with(issues).and_return(mock_timeseries)
        allow(mock_timeseries).to receive(:generate_timeseries).and_return(sample_timeline_data)
      end

      it 'uses TicketTimeseries as default generator' do
        result = service.find_timeline_data('test-issue')

        aggregate_failures do
          expect(KanbanMetrics::Timeseries::TicketTimeseries).to have_received(:new).with(issues)
          expect(mock_timeseries).to have_received(:generate_timeseries)
          expect(result).to eq({ id: 'test-issue', title: 'Test Issue' })
        end
      end
    end
  end
end

RSpec.describe KanbanMetrics::Reports::TimelineEventFormatter do
  subject(:formatter) { described_class.new }

  describe '#format_event' do
    context 'with creation event (no from_state)' do
      let(:event) do
        {
          date: '2024-01-01T10:00:00Z',
          from_state: nil,
          to_state: 'Backlog'
        }
      end

      it 'formats creation event correctly' do
        result = formatter.format_event(event)
        expect(result).to eq('2024-01-01 10:00 | Created → Backlog')
      end
    end

    context 'with state transition event' do
      let(:event) do
        {
          date: '2024-01-02T14:30:00Z',
          from_state: 'Backlog',
          to_state: 'In Progress'
        }
      end

      it 'formats transition event correctly' do
        result = formatter.format_event(event)
        expect(result).to eq('2024-01-02 14:30 | Backlog → In Progress')
      end
    end
  end
end

RSpec.describe KanbanMetrics::Reports::TimelineFormatter do
  subject(:formatter) { described_class.new }

  describe '#format_timeline' do
    let(:timeline_data) do
      {
        id: 'test-issue',
        title: 'Test Issue',
        team: 'Test Team',
        timeline: [
          {
            date: '2024-01-01T10:00:00Z',
            from_state: nil,
            to_state: 'Backlog'
          },
          {
            date: '2024-01-02T14:30:00Z',
            from_state: 'Backlog',
            to_state: 'Done'
          }
        ]
      }
    end

    it 'formats complete timeline with header and events' do
      result = formatter.format_timeline(timeline_data)

      aggregate_failures do
        expect(result).to include('📈 TIMELINE FOR test-issue: Test Issue')
        expect(result).to include('Team: Test Team')
        expect(result).to include('=' * 80)
        expect(result).to include('2024-01-01 10:00 | Created → Backlog')
        expect(result).to include('2024-01-02 14:30 | Backlog → Done')
      end
    end

    context 'with empty timeline' do
      let(:timeline_data) do
        {
          id: 'test-issue',
          title: 'Test Issue',
          team: 'Test Team',
          timeline: []
        }
      end

      it 'formats header without events' do
        result = formatter.format_timeline(timeline_data)

        aggregate_failures do
          expect(result).to include('📈 TIMELINE FOR test-issue: Test Issue')
          expect(result).to include('Team: Test Team')
          expect(result).not_to include('|')
        end
      end
    end
  end

  describe '#format_not_found_message' do
    it 'formats not found message' do
      result = formatter.format_not_found_message('test-issue')
      expect(result).to eq('❌ Issue test-issue not found')
    end
  end
end
