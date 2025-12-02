# frozen_string_literal: true

require 'spec_helper'

RSpec.describe KanbanMetrics::Formatters::MarkdownFormatter do
  # === TEST DATA SETUP ===
  subject(:formatter) { described_class.new(metrics, team_metrics, teammate_metrics_data, timeseries_data, issues_data) }

  # Default values that can be overridden in specific contexts
  let(:teammate_metrics_data) { nil }
  let(:timeseries_data) { nil }
  let(:issues_data) { nil }
  let(:team_metrics) { nil }

  let(:metrics) do
    {
      total_issues: 100,
      completed_issues: 60,
      in_progress_issues: 25,
      backlog_issues: 15,
      cycle_time: {
        average: 8.5,
        median: 6.0,
        p95: 18.2
      },
      lead_time: {
        average: 12.3,
        median: 9.1,
        p95: 25.7
      },
      throughput: {
        weekly_avg: 15.2,
        total_completed: 60
      },
      flow_efficiency: 65.5
    }
  end

  let(:sample_team_metrics) do
    {
      'Backend Team' => {
        total_issues: 60,
        completed_issues: 40,
        in_progress_issues: 15,
        backlog_issues: 5,
        cycle_time: { average: 7.2, median: 5.5 },
        lead_time: { average: 10.8, median: 8.2 },
        throughput: 40
      },
      'Frontend Team' => {
        total_issues: 40,
        completed_issues: 20,
        in_progress_issues: 10,
        backlog_issues: 10,
        cycle_time: { average: 10.1, median: 7.8 },
        lead_time: { average: 14.5, median: 11.2 },
        throughput: 20
      }
    }
  end

  let(:sample_teammate_metrics) do
    {
      'John Doe' => {
        total_issues: 30,
        completed_issues: 25,
        in_progress_issues: 3,
        backlog_issues: 2,
        cycle_time: { average: 5.5, median: 4.0 },
        lead_time: { average: 8.2, median: 6.1 },
        throughput: 25
      },
      'Jane Smith' => {
        total_issues: 25,
        completed_issues: 20,
        in_progress_issues: 4,
        backlog_issues: 1,
        cycle_time: { average: 6.8, median: 5.5 },
        lead_time: { average: 9.5, median: 7.2 },
        throughput: 20
      }
    }
  end

  let(:sample_timeseries) do
    instance_double(KanbanMetrics::Timeseries::TicketTimeseries,
                    status_flow_analysis: { ['Todo', 'In Progress'] => 15, ['In Progress', 'Done'] => 12 },
                    average_time_in_status: { 'Todo' => 3.2, 'In Progress' => 5.8, 'Done' => 0.1 },
                    daily_status_counts: { Date.today => { 'completed' => 3, 'started' => 2 } })
  end

  let(:sample_issues) do
    [
      {
        'id' => 'abc123',
        'identifier' => 'PROJ-123',
        'title' => 'Implement user authentication',
        'state' => { 'name' => 'Done', 'type' => 'completed' },
        'createdAt' => '2024-01-01T10:00:00Z',
        'startedAt' => '2024-01-02T14:00:00Z',
        'completedAt' => '2024-01-05T16:00:00Z',
        'team' => { 'name' => 'Backend Team' },
        'assignee' => { 'name' => 'John Doe' }
      }
    ]
  end

  describe '#initialize' do
    context 'with valid metrics' do
      it 'creates a formatter instance' do
        expect(formatter).to be_a(described_class)
      end

      it 'stores metrics correctly' do
        expect(formatter.instance_variable_get(:@metrics)).to eq(metrics)
      end
    end

    context 'with invalid metrics' do
      it 'raises ArgumentError for nil metrics' do
        expect { described_class.new(nil) }.to raise_error(ArgumentError, 'Metrics must be a non-empty Hash')
      end

      it 'raises ArgumentError for empty metrics' do
        expect { described_class.new({}) }.to raise_error(ArgumentError, 'Metrics must be a non-empty Hash')
      end

      it 'raises ArgumentError for non-Hash metrics' do
        expect { described_class.new([1, 2, 3]) }.to raise_error(ArgumentError, 'Metrics must be a non-empty Hash')
      end
    end
  end

  describe '#generate' do
    context 'with basic metrics only' do
      it 'generates markdown with header' do
        result = formatter.generate
        expect(result).to include('# 📊 Kanban Metrics Report')
      end

      it 'generates markdown with timestamp' do
        result = formatter.generate
        expect(result).to include('> Generated on')
      end

      it 'includes summary section' do
        result = formatter.generate
        expect(result).to include('## 📈 Summary')
      end

      it 'includes cycle time section' do
        result = formatter.generate
        expect(result).to include('## ⏱️ Cycle Time')
      end

      it 'includes lead time section' do
        result = formatter.generate
        expect(result).to include('## 📏 Lead Time')
      end

      it 'includes throughput section' do
        result = formatter.generate
        expect(result).to include('## 🚀 Throughput')
      end

      it 'includes KPI definitions section' do
        result = formatter.generate
        expect(result).to include('## 📚 KPI Definitions')
      end

      it 'includes metric values in summary table' do
        result = formatter.generate
        aggregate_failures 'summary values' do
          expect(result).to include('| Total Issues | 100 |')
          expect(result).to include('| Completed Issues | 60 |')
          expect(result).to include('| In Progress Issues | 25 |')
          expect(result).to include('| Backlog Issues | 15 |')
          expect(result).to include('| Flow Efficiency | 65.5% |')
        end
      end

      it 'includes cycle time values' do
        result = formatter.generate
        aggregate_failures 'cycle time values' do
          expect(result).to include('| Average | 8.5 |')
          expect(result).to include('| Median | 6.0 |')
          expect(result).to include('| 95th Percentile | 18.2 |')
        end
      end

      it 'includes lead time values' do
        result = formatter.generate
        aggregate_failures 'lead time values' do
          expect(result).to include('| Average | 12.3 |')
          expect(result).to include('| Median | 9.1 |')
          expect(result).to include('| 95th Percentile | 25.7 |')
        end
      end

      it 'includes throughput values' do
        result = formatter.generate
        aggregate_failures 'throughput values' do
          expect(result).to include('| Weekly Average | 15.2 |')
          expect(result).to include('| Total Completed | 60 |')
        end
      end
    end

    context 'with team metrics' do
      let(:team_metrics) { sample_team_metrics }

      it 'includes team metrics section' do
        result = formatter.generate
        expect(result).to include('## 👥 Team Metrics')
      end

      it 'includes individual team headers' do
        result = formatter.generate
        aggregate_failures 'team headers' do
          expect(result).to include('### 🏷️ Backend Team')
          expect(result).to include('### 🏷️ Frontend Team')
        end
      end

      it 'includes team comparison section' do
        result = formatter.generate
        expect(result).to include('### 📊 Team Comparison')
      end

      it 'includes team metrics values' do
        result = formatter.generate
        expect(result).to include('| Total Issues | 60 |')
        expect(result).to include('| Completed Issues | 40 |')
      end
    end

    context 'with teammate metrics' do
      let(:teammate_metrics_data) { sample_teammate_metrics }

      it 'includes teammate metrics section' do
        result = formatter.generate
        expect(result).to include('## 👤 Teammate Metrics')
      end

      it 'includes individual teammate headers' do
        result = formatter.generate
        aggregate_failures 'teammate headers' do
          expect(result).to include('### 🧑‍💻 John Doe')
          expect(result).to include('### 🧑‍💻 Jane Smith')
        end
      end

      it 'includes teammate comparison section' do
        result = formatter.generate
        expect(result).to include('### 📊 Teammate Comparison')
      end

      it 'includes teammate metrics values' do
        result = formatter.generate
        expect(result).to include('| Total Issues | 30 |')
        expect(result).to include('| Throughput | 25 |')
      end
    end

    context 'with timeseries data' do
      let(:timeseries_data) { sample_timeseries }

      it 'includes timeseries section' do
        result = formatter.generate
        expect(result).to include('## 📈 Timeseries Analysis')
      end

      it 'includes time in status section' do
        result = formatter.generate
        expect(result).to include('### ⏱️ Average Time in Status')
      end
    end

    context 'with individual tickets' do
      let(:issues_data) { sample_issues }

      it 'includes individual tickets section' do
        result = formatter.generate
        expect(result).to include('## 🎫 Individual Ticket Details')
      end

      it 'includes ticket identifier' do
        result = formatter.generate
        expect(result).to include('PROJ-123')
      end

      it 'includes ticket team' do
        result = formatter.generate
        expect(result).to include('Backend Team')
      end
    end

    context 'with all data combined' do
      let(:team_metrics) { sample_team_metrics }
      let(:teammate_metrics_data) { sample_teammate_metrics }
      let(:timeseries_data) { sample_timeseries }
      let(:issues_data) { sample_issues }

      it 'includes all sections' do
        result = formatter.generate
        aggregate_failures 'all sections' do
          expect(result).to include('## 📈 Summary')
          expect(result).to include('## ⏱️ Cycle Time')
          expect(result).to include('## 📏 Lead Time')
          expect(result).to include('## 🚀 Throughput')
          expect(result).to include('## 👥 Team Metrics')
          expect(result).to include('## 👤 Teammate Metrics')
          expect(result).to include('## 📈 Timeseries Analysis')
          expect(result).to include('## 🎫 Individual Ticket Details')
          expect(result).to include('## 📚 KPI Definitions')
        end
      end
    end
  end

  describe '.generate class method' do
    it 'generates markdown without instantiation' do
      result = described_class.generate(metrics, team_metrics: sample_team_metrics)
      expect(result).to include('# 📊 Kanban Metrics Report')
      expect(result).to include('## 👥 Team Metrics')
    end
  end

  describe 'markdown table formatting' do
    it 'uses proper markdown table syntax' do
      result = formatter.generate
      # Check for proper table separators
      expect(result).to include('|--------|')
    end

    it 'escapes pipe characters in content' do
      issues_with_pipes = [
        {
          'id' => 'abc123',
          'identifier' => 'PROJ-125',
          'title' => 'Feature A | Feature B comparison',
          'state' => { 'name' => 'Done', 'type' => 'completed' },
          'team' => { 'name' => 'Backend Team' }
        }
      ]
      formatter_with_pipes = described_class.new(metrics, nil, nil, nil, issues_with_pipes)
      result = formatter_with_pipes.generate
      # Pipes should be escaped
      expect(result).to include('Feature A \\| Feature B')
    end
  end

  describe 'edge cases' do
    context 'with missing nested data' do
      let(:incomplete_metrics) do
        {
          total_issues: 50,
          completed_issues: 30
          # Missing cycle_time, lead_time, throughput
        }
      end

      it 'handles missing cycle time gracefully' do
        formatter = described_class.new(incomplete_metrics)
        result = formatter.generate
        expect(result).to include('## 📈 Summary')
        # Should not raise error
      end
    end

    context 'with empty team metrics' do
      let(:team_metrics) { {} }

      it 'does not include team metrics section' do
        result = formatter.generate
        expect(result).not_to include('## 👥 Team Metrics')
      end
    end

    context 'with empty teammate metrics' do
      let(:teammate_metrics_data) { {} }

      it 'does not include teammate metrics section' do
        result = formatter.generate
        expect(result).not_to include('## 👤 Teammate Metrics')
      end
    end

    context 'with empty issues array' do
      let(:issues_data) { [] }

      it 'does not include individual tickets section' do
        result = formatter.generate
        expect(result).not_to include('## 🎫 Individual Ticket Details')
      end
    end

    context 'with very long title' do
      let(:issues_data) do
        [
          {
            'id' => 'abc123',
            'identifier' => 'PROJ-999',
            'title' => 'A' * 100, # Very long title
            'state' => { 'name' => 'Done' },
            'team' => { 'name' => 'Team' }
          }
        ]
      end

      it 'truncates long titles' do
        result = formatter.generate
        expect(result).to include('...')
        expect(result.length).to be < 100_000 # Reasonable size check
      end
    end
  end

  describe 'KPI definitions' do
    it 'includes all standard KPI definitions' do
      result = formatter.generate
      aggregate_failures 'KPI definitions' do
        expect(result).to include('| Cycle Time |')
        expect(result).to include('| Lead Time |')
        expect(result).to include('| Throughput |')
        expect(result).to include('| Flow Efficiency |')
        expect(result).to include('| WIP (Work in Progress) |')
        expect(result).to include('| 95th Percentile |')
      end
    end
  end
end
