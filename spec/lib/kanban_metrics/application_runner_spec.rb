# frozen_string_literal: true

require 'spec_helper'

RSpec.describe KanbanMetrics::ApplicationRunner do
  # Test Data Setup
  subject(:runner) { described_class.new(args) }

  let(:args) { ['--team-id', 'team-123', '--format', 'json'] }
  let(:parsed_options) { { team_id: 'team-123', format: 'json' } }
  let(:api_token) { 'test-token-123' }
  let(:mock_app) { instance_double(KanbanMetrics::KanbanMetricsApp) }

  describe '#initialize' do
    it 'creates a runner instance with arguments' do
      # Execute & Verify
      expect(runner).to be_a(described_class)
    end

    it 'stores the provided arguments' do
      # Execute & Verify
      expect(runner.instance_variable_get(:@args)).to eq(args)
    end
  end

  describe '#run' do
    subject(:run_application) { runner.run }

    context 'with valid API token' do
      before do
        # Setup valid environment
        allow(ENV).to receive(:fetch).with('LINEAR_API_TOKEN', nil).and_return(api_token)
        allow(KanbanMetrics::OptionsParser).to receive(:parse).with(args).and_return(parsed_options)
        allow(KanbanMetrics::KanbanMetricsApp).to receive(:new).with(api_token).and_return(mock_app)
        allow(mock_app).to receive(:run).with(parsed_options)
      end

      it 'validates API token presence' do
        # Setup spy
        allow(runner).to receive(:validate_api_token).and_call_original

        # Execute
        run_application

        # Verify
        expect(runner).to have_received(:validate_api_token)
      end

      it 'parses command line arguments' do
        # Execute
        run_application

        # Verify
        expect(KanbanMetrics::OptionsParser).to have_received(:parse).with(args)
      end

      it 'creates KanbanMetricsApp with API token' do
        # Execute
        run_application

        # Verify
        expect(KanbanMetrics::KanbanMetricsApp).to have_received(:new).with(api_token)
      end

      it 'runs the application with parsed options' do
        # Execute
        run_application

        # Verify
        expect(mock_app).to have_received(:run).with(parsed_options)
      end

      it 'executes the complete workflow' do
        # Execute
        run_application

        # Verify complete workflow (ENV.fetch is called twice - once in validate_api_token, once in run)
        expect(ENV).to have_received(:fetch).with('LINEAR_API_TOKEN', nil).at_least(:once)
        expect(KanbanMetrics::OptionsParser).to have_received(:parse).with(args)
        expect(KanbanMetrics::KanbanMetricsApp).to have_received(:new).with(api_token)
        expect(mock_app).to have_received(:run).with(parsed_options)
      end
    end

    context 'with missing API token' do
      before do
        allow(ENV).to receive(:fetch).with('LINEAR_API_TOKEN', nil).and_return(nil)
        allow(ENV).to receive(:fetch).with('LINEAR_TEAM_ID', nil).and_return(nil)
        allow(ENV).to receive(:fetch).with('METRICS_START_DATE', nil).and_return(nil)
        allow(ENV).to receive(:fetch).with('METRICS_END_DATE', nil).and_return(nil)
      end

      it 'exits with error message when token is nil' do
        # Execute & Verify
        expect { run_application }
          .to raise_error(SystemExit)
          .and output(/❌ LINEAR_API_TOKEN environment variable not set/).to_stdout
      end

      it 'displays helpful instructions for getting token' do
        # Execute & Verify
        expect { run_application }
          .to raise_error(SystemExit)
          .and output(%r{Get your token from: https://linear\.app/settings/api}).to_stdout
      end

      it 'suggests creating .env file' do
        # Execute & Verify
        expect { run_application }
          .to raise_error(SystemExit)
          .and output(/Please create a \.env file with your Linear API token/).to_stdout
      end
    end

    context 'with empty API token' do
      before do
        allow(ENV).to receive(:fetch).with('LINEAR_API_TOKEN', nil).and_return('')
        allow(ENV).to receive(:fetch).with('LINEAR_TEAM_ID', nil).and_return(nil)
        allow(ENV).to receive(:fetch).with('METRICS_START_DATE', nil).and_return(nil)
        allow(ENV).to receive(:fetch).with('METRICS_END_DATE', nil).and_return(nil)
      end

      it 'exits with error message when token is empty string' do
        # Execute & Verify
        expect { run_application }
          .to raise_error(SystemExit)
          .and output(/❌ LINEAR_API_TOKEN environment variable not set/).to_stdout
      end
    end

    context 'when OptionsParser raises an error' do
      before do
        allow(ENV).to receive(:fetch).with('LINEAR_API_TOKEN', nil).and_return(api_token)
        allow(KanbanMetrics::OptionsParser).to receive(:parse).with(args).and_raise(StandardError.new('Invalid arguments'))
      end

      it 'propagates parsing errors' do
        # Execute & Verify
        expect { run_application }.to raise_error(StandardError, 'Invalid arguments')
      end
    end

    context 'when KanbanMetricsApp raises an error' do
      before do
        allow(ENV).to receive(:fetch).with('LINEAR_API_TOKEN', nil).and_return(api_token)
        allow(KanbanMetrics::OptionsParser).to receive(:parse).with(args).and_return(parsed_options)
        allow(KanbanMetrics::KanbanMetricsApp).to receive(:new).with(api_token).and_return(mock_app)
        allow(mock_app).to receive(:run).with(parsed_options).and_raise(KanbanMetrics::ApiError.new('API failed'))
      end

      it 'propagates application errors' do
        # Execute & Verify
        expect { run_application }.to raise_error(KanbanMetrics::ApiError, 'API failed')
      end
    end
  end



  describe 'integration scenarios' do
    context 'with complete valid workflow' do
      let(:sample_issues) { [{ 'id' => 'issue-1', 'title' => 'Test Issue' }] }

      before do
        allow(ENV).to receive(:fetch).with('LINEAR_API_TOKEN', nil).and_return(api_token)
        allow(KanbanMetrics::OptionsParser).to receive(:parse).with(args).and_return(parsed_options)
        allow(KanbanMetrics::KanbanMetricsApp).to receive(:new).with(api_token).and_return(mock_app)
        allow(mock_app).to receive(:run).with(parsed_options)
      end

      it 'successfully executes end-to-end workflow' do
        # Execute
        runner.run

        # Verify complete execution chain (ENV.fetch is called twice - validate and run)
        expect(ENV).to have_received(:fetch).with('LINEAR_API_TOKEN', nil).at_least(:once)
        expect(KanbanMetrics::OptionsParser).to have_received(:parse).with(args)
        expect(KanbanMetrics::KanbanMetricsApp).to have_received(:new).with(api_token)
        expect(mock_app).to have_received(:run).with(parsed_options)
      end
    end

    context 'with different argument combinations' do
      let(:complex_args) { ['--team-id', 'team-123', '--format', 'csv', '--team-metrics', '--timeseries'] }
      let(:complex_options) { { team_id: 'team-123', format: 'csv', team_metrics: true, timeseries: true } }

      before do
        allow(ENV).to receive(:fetch).with('LINEAR_API_TOKEN', nil).and_return(api_token)
        allow(KanbanMetrics::OptionsParser).to receive(:parse).with(complex_args).and_return(complex_options)
        allow(KanbanMetrics::KanbanMetricsApp).to receive(:new).with(api_token).and_return(mock_app)
        allow(mock_app).to receive(:run).with(complex_options)
      end

      it 'handles complex argument combinations' do
        # Setup
        runner_with_complex_args = described_class.new(complex_args)

        # Execute
        runner_with_complex_args.run

        # Verify
        expect(KanbanMetrics::OptionsParser).to have_received(:parse).with(complex_args)
        expect(mock_app).to have_received(:run).with(complex_options)
      end
    end

    context 'with minimal arguments' do
      let(:minimal_args) { [] }
      let(:minimal_options) { {} }

      before do
        allow(ENV).to receive(:fetch).with('LINEAR_API_TOKEN', nil).and_return(api_token)
        allow(KanbanMetrics::OptionsParser).to receive(:parse).with(minimal_args).and_return(minimal_options)
        allow(KanbanMetrics::KanbanMetricsApp).to receive(:new).with(api_token).and_return(mock_app)
        allow(mock_app).to receive(:run).with(minimal_options)
      end

      it 'handles minimal arguments gracefully' do
        # Setup
        runner_with_minimal_args = described_class.new(minimal_args)

        # Execute
        runner_with_minimal_args.run

        # Verify
        expect(KanbanMetrics::OptionsParser).to have_received(:parse).with(minimal_args)
        expect(mock_app).to have_received(:run).with(minimal_options)
      end
    end
  end

  describe 'error resilience' do
    before do
      allow(ENV).to receive(:fetch).with('LINEAR_API_TOKEN', nil).and_return(api_token)
    end

    context 'when options parsing fails with ArgumentError' do
      before do
        allow(KanbanMetrics::OptionsParser).to receive(:parse).and_raise(ArgumentError.new('Invalid flag'))
      end

      it 'lets ArgumentError bubble up for proper handling' do
        # Execute & Verify
        expect { runner.run }.to raise_error(ArgumentError, 'Invalid flag')
      end
    end

    context 'when application creation fails' do
      before do
        allow(KanbanMetrics::OptionsParser).to receive(:parse).with(args).and_return(parsed_options)
        allow(KanbanMetrics::KanbanMetricsApp).to receive(:new).and_raise(StandardError.new('Client creation failed'))
      end

      it 'propagates creation errors' do
        # Execute & Verify
        expect { runner.run }.to raise_error(StandardError, 'Client creation failed')
      end
    end
  end
end
