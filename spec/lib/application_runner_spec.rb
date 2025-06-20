# frozen_string_literal: true

require 'spec_helper'

RSpec.describe KanbanMetrics::ApplicationRunner do
  # Test Data Setup
  subject(:runner) { described_class.new(args) }

  let(:args) { ['--team-id', 'team-123', '--format', 'json'] }
  let(:parsed_options) { { team_id: 'team-123', format: 'json' } }
  let(:mock_app) { instance_double(KanbanMetrics::KanbanMetricsApp) }

  describe '#initialize' do
    it 'creates a runner instance with arguments' do
      # Execute & Verify
      expect(runner).to be_a(described_class)
    end
  end

  describe '#run' do
    subject(:run_application) { runner.run }

    context 'with valid API token' do
      before do
        # Setup
        allow(ENV).to receive(:fetch).with('LINEAR_API_TOKEN', nil).and_return('test-token')
        allow(KanbanMetrics::OptionsParser).to receive(:parse).with(args).and_return(parsed_options)
        allow(KanbanMetrics::KanbanMetricsApp).to receive(:new).with('test-token').and_return(mock_app)
        allow(mock_app).to receive(:run).with(parsed_options)
      end

      it 'validates API token' do
        # Setup
        expect(runner).to receive(:validate_api_token)

        # Execute & Verify
        run_application
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
        expect(KanbanMetrics::KanbanMetricsApp).to have_received(:new).with('test-token')
      end

      it 'runs the app with parsed options' do
        # Execute
        run_application

        # Verify
        expect(mock_app).to have_received(:run).with(parsed_options)
      end
    end

    context 'when API token is missing' do
      before do
        # Setup
        allow(ENV).to receive(:fetch).with('LINEAR_API_TOKEN', nil).and_return(nil)
      end

      it 'exits with error message' do
        # Execute & Verify
        expect { run_application }.to raise_error(SystemExit)
      end

      it 'prints error message about missing token' do
        # Execute & Verify
        expect do
          run_application
        rescue StandardError
          nil
        end.to output(/LINEAR_API_TOKEN environment variable not set/).to_stdout
      end
    end

    context 'when API token is empty' do
      before do
        # Setup
        allow(ENV).to receive(:fetch).with('LINEAR_API_TOKEN', nil).and_return('')
      end

      it 'exits with error message' do
        # Execute & Verify
        expect { run_application }.to raise_error(SystemExit)
      end
    end
  end

  describe '#validate_api_token' do
    subject(:validate_token) { runner.send(:validate_api_token) }

    context 'with valid API token' do
      before do
        # Setup
        allow(ENV).to receive(:fetch).with('LINEAR_API_TOKEN', nil).and_return('valid-token')
      end

      it 'does not raise error' do
        # Execute & Verify
        expect { validate_token }.not_to raise_error
      end
    end

    context 'with missing API token' do
      before do
        # Setup
        allow(ENV).to receive(:fetch).with('LINEAR_API_TOKEN', nil).and_return(nil)
      end

      it 'exits with error' do
        # Execute & Verify
        expect { validate_token }.to raise_error(SystemExit)
      end

      it 'prints helpful error message' do
        # Execute
        output = capture_stdout do
          validate_token
        rescue StandardError
          nil
        end

        # Verify
        aggregate_failures 'error message content' do
          expect(output).to include('LINEAR_API_TOKEN environment variable not set')
          expect(output).to include('Please create a .env file')
          expect(output).to include('https://linear.app/settings/api')
        end
      end
    end

    context 'with empty API token' do
      before do
        # Setup
        allow(ENV).to receive(:fetch).with('LINEAR_API_TOKEN', nil).and_return('')
      end

      it 'exits with error' do
        # Execute & Verify
        expect { validate_token }.to raise_error(SystemExit)
      end
    end
  end
end

RSpec.describe KanbanMetrics::KanbanMetricsApp do
  # Test Data Setup
  subject(:app) { described_class.new(api_token) }

  let(:api_token) { 'test-token-123' }
  let(:mock_client) { instance_double(KanbanMetrics::Linear::Client) }
  let(:sample_issues) do
    [
      { 'id' => 'issue-1', 'title' => 'Test Issue 1' },
      { 'id' => 'issue-2', 'title' => 'Test Issue 2' }
    ]
  end

  describe '#initialize' do
    it 'creates client with API token' do
      # Setup
      expect(KanbanMetrics::Linear::Client).to receive(:new).with(api_token)

      # Execute & Verify
      described_class.new(api_token)
    end
  end

  describe '#run' do
    subject(:run_app) { app.run(options) }

    # Setup
    let(:options) { { team_id: 'team-123' } }

    before do
      allow(KanbanMetrics::Linear::Client).to receive(:new).and_return(mock_client)
      allow(mock_client).to receive(:fetch_issues).and_return(sample_issues)
    end

    context 'with standard options' do
      before do
        # Setup
        allow_any_instance_of(described_class).to receive(:show_metrics)
      end

      it 'fetches issues with provided options' do
        # Execute
        run_app

        # Verify
        expect(mock_client).to have_received(:fetch_issues).with(options)
      end
    end

    context 'with no issues found' do
      before do
        # Setup
        allow(mock_client).to receive(:fetch_issues).and_return([])
      end

      it 'handles no issues gracefully' do
        # Execute & Verify
        expect { run_app }.to raise_error(SystemExit)
      end

      it 'prints no issues message' do
        # Execute
        output = capture_stdout do
          run_app
        rescue StandardError
          nil
        end

        # Verify
        expect(output).to include('No issues found')
      end
    end

    context 'with timeline option' do
      # Setup
      let(:options) { { team_id: 'team-123', timeline: 'ISSUE-123' } }
      let(:mock_timeline_display) { instance_double(KanbanMetrics::Reports::TimelineDisplay) }

      before do
        allow(KanbanMetrics::Reports::TimelineDisplay).to receive(:new).and_return(mock_timeline_display)
        allow(mock_timeline_display).to receive(:show_timeline)
      end

      it 'shows timeline for specific issue' do
        # Execute
        run_app

        # Verify
        aggregate_failures 'timeline display' do
          expect(KanbanMetrics::Reports::TimelineDisplay).to have_received(:new).with(sample_issues)
          expect(mock_timeline_display).to have_received(:show_timeline).with('ISSUE-123')
        end
      end
    end

    context 'with metrics display' do
      # Setup
      let(:mock_calculator) { instance_double(KanbanMetrics::Calculators::KanbanMetricsCalculator) }
      let(:mock_report) { instance_double(KanbanMetrics::Reports::KanbanReport) }
      let(:metrics) { { total_issues: 2 } }

      before do
        allow(KanbanMetrics::Calculators::KanbanMetricsCalculator).to receive(:new).and_return(mock_calculator)
        allow(mock_calculator).to receive_messages(overall_metrics: metrics, team_metrics: nil)
        allow(KanbanMetrics::Reports::KanbanReport).to receive(:new).and_return(mock_report)
        allow(mock_report).to receive(:display)
      end

      it 'calculates and displays metrics' do
        # Execute
        run_app

        # Verify
        aggregate_failures 'metrics calculation and display' do
          expect(KanbanMetrics::Calculators::KanbanMetricsCalculator).to have_received(:new).with(sample_issues)
          expect(mock_calculator).to have_received(:overall_metrics)
          expect(mock_report).to have_received(:display).with('table')
        end
      end

      it 'includes team metrics when requested' do
        # Setup
        team_options = { team_id: 'team-123', team_metrics: true }
        team_metrics = { 'Team A' => { total_issues: 1 } }
        allow(mock_calculator).to receive(:team_metrics).and_return(team_metrics)

        # Execute
        app.run(team_options)

        # Verify
        aggregate_failures 'team metrics inclusion' do
          expect(mock_calculator).to have_received(:team_metrics)
          expect(KanbanMetrics::Reports::KanbanReport).to have_received(:new).with(metrics, team_metrics, anything)
        end
      end

      it 'includes timeseries when requested' do
        # Setup
        timeseries_options = { team_id: 'team-123', timeseries: true }
        mock_timeseries = instance_double(KanbanMetrics::Timeseries::TicketTimeseries)
        allow(KanbanMetrics::Timeseries::TicketTimeseries).to receive(:new).and_return(mock_timeseries)

        # Execute
        app.run(timeseries_options)

        # Verify
        aggregate_failures 'timeseries inclusion' do
          expect(KanbanMetrics::Timeseries::TicketTimeseries).to have_received(:new).with(sample_issues)
          expect(KanbanMetrics::Reports::KanbanReport).to have_received(:new).with(metrics, nil, mock_timeseries)
        end
      end

      it 'uses specified format' do
        # Setup
        format_options = { team_id: 'team-123', format: 'json' }

        # Execute
        app.run(format_options)

        # Verify
        expect(mock_report).to have_received(:display).with('json')
      end
    end
  end

  describe 'private methods' do
    before do
      # Setup
      allow(KanbanMetrics::Linear::Client).to receive(:new).and_return(mock_client)
    end

    describe '#fetch_issues' do
      subject(:fetch_issues) { app.send(:fetch_issues, options) }

      # Setup
      let(:options) { { team_id: 'team-123' } }

      it 'delegates to client' do
        # Setup
        allow(mock_client).to receive(:fetch_issues).with(options).and_return(sample_issues)

        # Execute
        result = fetch_issues

        # Verify
        aggregate_failures 'client delegation' do
          expect(result).to eq(sample_issues)
          expect(mock_client).to have_received(:fetch_issues).with(options)
        end
      end
    end

    describe '#handle_no_issues' do
      subject(:handle_no_issues) { app.send(:handle_no_issues) }

      it 'exits with error message' do
        # Execute & Verify
        expect { handle_no_issues }.to raise_error(SystemExit)
      end

      it 'prints no issues message' do
        # Execute
        output = capture_stdout do
          handle_no_issues
        rescue StandardError
          nil
        end

        # Verify
        expect(output).to include('No issues found')
      end
    end

    describe '#show_timeline' do
      subject(:show_timeline) { app.send(:show_timeline, sample_issues, issue_id) }

      # Setup
      let(:issue_id) { 'ISSUE-123' }
      let(:mock_timeline_display) { instance_double(KanbanMetrics::Reports::TimelineDisplay) }

      before do
        allow(KanbanMetrics::Reports::TimelineDisplay).to receive(:new).and_return(mock_timeline_display)
        allow(mock_timeline_display).to receive(:show_timeline)
      end

      it 'creates and uses TimelineDisplay' do
        # Execute
        show_timeline

        # Verify
        aggregate_failures 'timeline display creation and usage' do
          expect(KanbanMetrics::Reports::TimelineDisplay).to have_received(:new).with(sample_issues)
          expect(mock_timeline_display).to have_received(:show_timeline).with(issue_id)
        end
      end
    end

    describe '#show_metrics' do
      subject(:show_metrics) { app.send(:show_metrics, sample_issues, options) }

      # Setup
      let(:mock_calculator) { instance_double(KanbanMetrics::Calculators::KanbanMetricsCalculator) }
      let(:mock_report) { instance_double(KanbanMetrics::Reports::KanbanReport) }
      let(:metrics) { { total_issues: 2 } }
      let(:options) { { format: 'table' } }

      before do
        allow(KanbanMetrics::Calculators::KanbanMetricsCalculator).to receive(:new).and_return(mock_calculator)
        allow(mock_calculator).to receive_messages(overall_metrics: metrics, team_metrics: nil)
        allow(KanbanMetrics::Reports::KanbanReport).to receive(:new).and_return(mock_report)
        allow(mock_report).to receive(:display)
      end

      it 'calculates metrics and creates report' do
        # Execute
        show_metrics

        # Verify
        aggregate_failures 'metrics calculation and report creation' do
          expect(KanbanMetrics::Calculators::KanbanMetricsCalculator).to have_received(:new).with(sample_issues)
          expect(mock_calculator).to have_received(:overall_metrics)
          expect(KanbanMetrics::Reports::KanbanReport).to have_received(:new).with(metrics, nil, nil)
          expect(mock_report).to have_received(:display).with('table')
        end
      end
    end
  end
end
