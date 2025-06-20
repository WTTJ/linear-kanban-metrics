# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../lib/kanban_metrics/options_parser'

RSpec.describe KanbanMetrics::OptionsParser do
  describe '.parse' do
    subject(:parse_options) { described_class.parse(args) }

    context 'with no arguments' do
      let(:args) { [] }

      it 'returns default options hash' do
        # Setup: empty args

        # Execute
        result = parse_options

        # Verify
        aggregate_failures do
          expect(result).to be_a(Hash)
          expect(result[:page_size]).to eq(250)
          expect(result[:format]).to eq('table')
          expect(result[:include_archived]).to be false
          expect(result[:no_cache]).to be false
          expect(result[:team_metrics]).to be false
          expect(result[:timeseries]).to be false
        end
      end
    end

    context 'with filter options' do
      let(:args) { ['--team-id', 'team-123'] }

      it 'parses team-id option correctly' do
        # Setup: args with team-id

        # Execute
        result = parse_options

        # Verify
        expect(result[:team_id]).to eq('team-123')
      end
    end

    context 'with date filter options' do
      let(:args) { ['--start-date', '2024-01-01', '--end-date', '2024-01-31'] }

      it 'parses date options correctly' do
        # Setup: args with date filters

        # Execute
        result = parse_options

        # Verify
        aggregate_failures do
          expect(result[:start_date]).to eq('2024-01-01')
          expect(result[:end_date]).to eq('2024-01-31')
        end
      end
    end

    context 'with output format options' do
      let(:args) { ['--format', 'json', '--page-size', '100'] }

      it 'parses output format options correctly' do
        # Setup: args with format options

        # Execute
        result = parse_options

        # Verify
        aggregate_failures do
          expect(result[:format]).to eq('json')
          expect(result[:page_size]).to eq(100)
        end
      end
    end

    context 'with feature flags' do
      context 'no-cache flag' do
        let(:args) { ['--no-cache'] }

        it 'parses no-cache flag correctly' do
          # Setup: args defined above

          # Execute
          result = parse_options

          # Verify
          expect(result[:no_cache]).to be true
        end
      end

      context 'team-metrics flag' do
        let(:args) { ['--team-metrics'] }

        it 'parses team-metrics flag correctly' do
          # Setup: args defined above

          # Execute
          result = parse_options

          # Verify
          expect(result[:team_metrics]).to be true
        end
      end

      context 'timeseries flag' do
        let(:args) { ['--timeseries'] }

        it 'parses timeseries flag correctly' do
          # Setup: args defined above

          # Execute
          result = parse_options

          # Verify
          expect(result[:timeseries]).to be true
        end
      end

      context 'timeline option' do
        let(:args) { ['--timeline', 'ISSUE-123'] }

        it 'parses timeline option correctly' do
          # Setup: args defined above

          # Execute
          result = parse_options

          # Verify
          expect(result[:timeline]).to eq('ISSUE-123')
        end
      end

      context 'include-archived flag' do
        let(:args) { ['--include-archived'] }

        it 'parses include-archived flag correctly' do
          # Setup: args defined above

          # Execute
          result = parse_options

          # Verify
          expect(result[:include_archived]).to be true
        end
      end
    end

    context 'with complex option combinations' do
      let(:args) do
        [
          '--team-id', 'team-456',
          '--start-date', '2024-01-01',
          '--end-date', '2024-01-31',
          '--format', 'csv',
          '--page-size', '150',
          '--team-metrics',
          '--include-archived'
        ]
      end

      it 'parses all options correctly together' do
        # Setup: complex args defined above

        # Execute
        result = parse_options

        # Verify
        aggregate_failures 'complex options validation' do
          expect(result[:team_id]).to eq('team-456')
          expect(result[:start_date]).to eq('2024-01-01')
          expect(result[:end_date]).to eq('2024-01-31')
          expect(result[:format]).to eq('csv')
          expect(result[:page_size]).to eq(150)
          expect(result[:team_metrics]).to be true
          expect(result[:include_archived]).to be true
        end
      end
    end

    context 'with invalid options' do
      it 'handles invalid page size gracefully' do
        options = described_class.parse(['--page-size', '300'])
        expect(options[:page_size]).to eq(250) # Should normalize to maximum allowed
      end

      it 'handles invalid format gracefully' do
        options = described_class.parse(['--format', 'invalid'])
        expect(options[:format]).to eq('table') # Should default to table
      end
    end

    context 'with help option' do
      it 'shows help and exits' do
        expect do
          described_class.parse(['--help'])
        end.to raise_error(SystemExit)
      end

      it 'shows help with -h flag' do
        expect do
          described_class.parse(['-h'])
        end.to raise_error(SystemExit)
      end
    end
  end
end
