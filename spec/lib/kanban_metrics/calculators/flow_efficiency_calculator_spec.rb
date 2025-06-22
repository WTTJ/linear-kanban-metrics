# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../../lib/kanban_metrics/calculators/flow_efficiency_calculator'

RSpec.describe KanbanMetrics::Calculators::FlowEfficiencyCalculator do
  # Test Data Setup
  # Named Subject
  subject(:calculator) { described_class.new(issues) }

  let(:issues_with_history) do
    [
      {
        'id' => 'issue-1',
        'history' => {
          'nodes' => [
            {
              'createdAt' => '2024-01-01T10:00:00Z',
              'toState' => { 'type' => 'backlog' }
            },
            {
              'createdAt' => '2024-01-02T10:00:00Z',
              'toState' => { 'type' => 'started' }
            },
            {
              'createdAt' => '2024-01-04T10:00:00Z',
              'toState' => { 'type' => 'completed' }
            }
          ]
        }
      },
      {
        'id' => 'issue-2',
        'history' => {
          'nodes' => [
            {
              'createdAt' => '2024-01-01T10:00:00Z',
              'toState' => { 'type' => 'backlog' }
            },
            {
              'createdAt' => '2024-01-03T10:00:00Z',
              'toState' => { 'type' => 'unstarted' }
            },
            {
              'createdAt' => '2024-01-05T10:00:00Z',
              'toState' => { 'type' => 'completed' }
            }
          ]
        }
      }
    ]
  end

  let(:empty_issues) { [] }

  let(:issues_without_history) do
    [
      { 'id' => 'issue-3' },
      { 'id' => 'issue-4', 'history' => { 'nodes' => [] } }
    ]
  end

  describe '#initialize' do
    # Setup
    let(:issues) { issues_with_history }

    # Execute & Verify
    it 'creates a calculator instance' do
      expect(calculator).to be_a(described_class)
    end
  end

  describe '#calculate' do
    context 'with empty issues array' do
      # Setup
      # Execute
      subject(:result) { calculator.calculate }

      let(:issues) { empty_issues }

      # Verify
      it 'returns zero as float' do
        expect(result).to eq(0.0)
      end
    end

    context 'with issues without history' do
      # Setup
      # Execute
      subject(:result) { calculator.calculate }

      let(:issues) { issues_without_history }

      # Verify
      it 'returns zero for issues without history' do
        expect(result).to eq(0.0)
      end
    end

    context 'with issues containing valid history' do
      # Setup
      # Execute
      subject(:result) { calculator.calculate }

      let(:issues) { issues_with_history }

      # Verify
      it 'calculates flow efficiency as a percentage', :aggregate_failures do
        expect(result).to be_a(Float)
        expect(result).to be >= 0
        expect(result).to be <= 100
      end

      it 'returns a value rounded to 2 decimal places' do
        expect(result.round(2)).to eq(result)
      end
    end

    context 'with mixed valid and invalid issues' do
      # Setup
      # Execute
      subject(:result) { calculator.calculate }

      let(:issues) { issues_with_history + issues_without_history }

      # Verify
      it 'handles mixed data gracefully' do
        expect(result).to be_a(Float)
        expect(result).to be >= 0
      end
    end

    context 'with different state transitions' do
      let(:issues_with_active_states) do
        [
          {
            'id' => 'active-1',
            'history' => {
              'nodes' => [
                { 'createdAt' => '2024-01-01T00:00:00Z', 'toState' => { 'type' => 'backlog' } },
                { 'createdAt' => '2024-01-02T00:00:00Z', 'toState' => { 'type' => 'started' } },
                { 'createdAt' => '2024-01-03T00:00:00Z', 'toState' => { 'type' => 'completed' } }
              ]
            }
          }
        ]
      end

      let(:issues_with_inactive_states) do
        [
          {
            'id' => 'inactive-1',
            'history' => {
              'nodes' => [
                { 'createdAt' => '2024-01-01T00:00:00Z', 'toState' => { 'type' => 'backlog' } },
                { 'createdAt' => '2024-01-02T00:00:00Z', 'toState' => { 'type' => 'completed' } }
              ]
            }
          }
        ]
      end

      let(:issues_with_mixed_states) do
        [
          {
            'id' => 'mixed-1',
            'history' => {
              'nodes' => [
                { 'createdAt' => '2024-01-01T00:00:00Z', 'toState' => { 'type' => 'backlog' } },
                { 'createdAt' => '2024-01-02T00:00:00Z', 'toState' => { 'type' => 'unstarted' } },
                { 'createdAt' => '2024-01-03T00:00:00Z', 'toState' => { 'type' => 'backlog' } },
                { 'createdAt' => '2024-01-04T00:00:00Z', 'toState' => { 'type' => 'completed' } }
              ]
            }
          }
        ]
      end

      it 'calculates higher efficiency for issues with active states' do
        calculator_active = described_class.new(issues_with_active_states)
        calculator_inactive = described_class.new(issues_with_inactive_states)

        active_efficiency = calculator_active.calculate
        inactive_efficiency = calculator_inactive.calculate

        expect(active_efficiency).to be > inactive_efficiency
      end

      it 'handles unstarted states as active' do
        calculator = described_class.new(issues_with_mixed_states)
        efficiency = calculator.calculate

        # Should be greater than 0 since unstarted is considered active
        expect(efficiency).to be > 0
      end

      it 'handles malformed state data gracefully' do
        malformed_issues = [
          {
            'id' => 'malformed-1',
            'history' => {
              'nodes' => [
                { 'createdAt' => '2024-01-01T00:00:00Z' }, # Missing toState
                { 'createdAt' => '2024-01-02T00:00:00Z', 'toState' => {} }, # Empty toState
                { 'createdAt' => '2024-01-03T00:00:00Z', 'toState' => { 'type' => 'started' } }
              ]
            }
          }
        ]

        calculator = described_class.new(malformed_issues)
        result = calculator.calculate

        expect(result).to be_a(Float)
        expect(result).to be >= 0
      end
    end

    context 'with timestamp edge cases' do
      let(:issues_with_invalid_timestamps) do
        [
          {
            'id' => 'invalid-timestamps',
            'history' => {
              'nodes' => [
                { 'createdAt' => 'invalid-date', 'toState' => { 'type' => 'backlog' } },
                { 'createdAt' => '2024-01-02T00:00:00Z', 'toState' => { 'type' => 'started' } },
                { 'createdAt' => '', 'toState' => { 'type' => 'completed' } }
              ]
            }
          }
        ]
      end

      let(:issues_with_same_timestamps) do
        [
          {
            'id' => 'same-timestamps',
            'history' => {
              'nodes' => [
                { 'createdAt' => '2024-01-01T00:00:00Z', 'toState' => { 'type' => 'backlog' } },
                { 'createdAt' => '2024-01-01T00:00:00Z', 'toState' => { 'type' => 'started' } }
              ]
            }
          }
        ]
      end

      it 'handles invalid timestamps gracefully' do
        calculator = described_class.new(issues_with_invalid_timestamps)
        result = calculator.calculate

        expect(result).to be_a(Float)
        expect(result).to be >= 0
      end

      it 'handles zero duration transitions' do
        calculator = described_class.new(issues_with_same_timestamps)
        result = calculator.calculate

        expect(result).to be_a(Float)
        expect(result).to be >= 0
      end
    end
  end
end
