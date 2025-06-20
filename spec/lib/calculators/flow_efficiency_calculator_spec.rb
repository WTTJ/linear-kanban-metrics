# frozen_string_literal: true

require 'spec_helper'

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
  end

  describe 'private methods' do
    # Setup
    let(:issues) { issues_with_history }

    describe '#active_state?' do
      # Test cases for different state types
      [
        { state_type: 'started', expected: true, description: 'started states as active' },
        { state_type: 'unstarted', expected: true, description: 'unstarted states as active' },
        { state_type: 'backlog', expected: false, description: 'backlog states as inactive' },
        { state_type: 'completed', expected: false, description: 'completed states as inactive' }
      ].each do |test_case|
        it "identifies #{test_case[:description]}" do
          # Setup
          event = { 'toState' => { 'type' => test_case[:state_type] } }

          # Execute & Verify
          expect(calculator.send(:active_state?, event)).to be test_case[:expected]
        end
      end

      it 'handles missing toState gracefully' do
        # Setup
        event = {}

        # Execute & Verify
        expect(calculator.send(:active_state?, event)).to be false
      end
    end

    describe '#calculate_duration' do
      it 'calculates duration between two events' do
        # Setup
        from_event = { 'createdAt' => '2024-01-01T10:00:00Z' }
        to_event = { 'createdAt' => '2024-01-02T10:00:00Z' }

        # Execute
        duration = calculator.send(:calculate_duration, from_event, to_event)

        # Verify
        expect(duration).to eq(1.0) # 1 day
      end

      it 'handles fractional days' do
        # Setup
        from_event = { 'createdAt' => '2024-01-01T10:00:00Z' }
        to_event = { 'createdAt' => '2024-01-01T22:00:00Z' }

        # Execute
        duration = calculator.send(:calculate_duration, from_event, to_event)

        # Verify
        expect(duration).to eq(0.5) # 12 hours = 0.5 days
      end
    end
  end
end
