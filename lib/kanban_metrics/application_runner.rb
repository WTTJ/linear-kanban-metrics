# frozen_string_literal: true

module KanbanMetrics
  # Value object to encapsulate report data
  class ReportData
    attr_reader :metrics, :team_metrics, :timeseries, :issues

    def initialize(metrics:, team_metrics: nil, timeseries: nil, issues: nil)
      @metrics = metrics
      @team_metrics = team_metrics
      @timeseries = timeseries
      @issues = issues
    end
  end

  # Main application orchestrator
  class KanbanMetricsApp
    DEFAULT_FORMAT = 'table'

    def initialize(api_token)
      @client = Linear::Client.new(api_token)
    end

    def run(options)
      issues = fetch_issues(options)
      return handle_no_issues if issues.empty?

      if options[:timeline]
        show_timeline(issues, options[:timeline])
      else
        show_metrics(issues, options)
      end
    end

    private

    def fetch_issues(options)
      @client.fetch_issues(options)
    end

    def handle_no_issues
      puts '❌ No issues found with the given criteria'
      exit 1
    end

    def show_timeline(issues, issue_id)
      Reports::TimelineDisplay.new(issues).show_timeline(issue_id)
    end

    def show_metrics(issues, options)
      announce_metrics_calculation(issues)

      report_data = build_report_data(issues, options)
      display_report(report_data, options[:format])
    end

    def announce_metrics_calculation(issues)
      puts "📊 Found #{issues.length} issues, calculating metrics..."
    end

    def build_report_data(issues, options)
      calculator = Calculators::KanbanMetricsCalculator.new(issues)

      ReportData.new(
        metrics: calculator.overall_metrics,
        team_metrics: build_team_metrics(calculator, options),
        timeseries: build_timeseries(issues, options),
        issues: build_issues_for_report(issues, options)
      )
    end

    def build_team_metrics(calculator, options)
      options[:team_metrics] ? calculator.team_metrics : nil
    end

    def build_timeseries(issues, options)
      options[:timeseries] ? Timeseries::TicketTimeseries.new(issues) : nil
    end

    def build_issues_for_report(issues, options)
      options[:ticket_details] ? issues : nil
    end

    def display_report(report_data, format)
      Reports::KanbanReport.new(
        report_data.metrics,
        report_data.team_metrics,
        report_data.timeseries,
        report_data.issues
      ).display(format || DEFAULT_FORMAT)
    end
  end

  # Application entry point
  class ApplicationRunner
    API_TOKEN_ENV_KEY = 'LINEAR_API_TOKEN'

    def initialize(args, token_provider: ENV)
      @args = args
      @token_provider = token_provider
    end

    def run
      options = parse_options
      api_token = fetch_and_validate_api_token
      app = create_application(api_token)
      app.run(options)
    end

    private

    attr_reader :args, :token_provider

    def parse_options
      OptionsParser.parse(args)
    end

    def fetch_and_validate_api_token
      api_token = token_provider.fetch(API_TOKEN_ENV_KEY, nil)
      validate_api_token(api_token)
      api_token
    end

    def validate_api_token(api_token)
      return if valid_token?(api_token)

      display_token_error_message
      exit 1
    end

    def valid_token?(token)
      token && !token.empty?
    end

    def create_application(api_token)
      KanbanMetricsApp.new(api_token)
    end

    def display_token_error_message
      puts '❌ LINEAR_API_TOKEN environment variable not set'
      puts '   Please create a .env file with your Linear API token'
      puts '   Get your token from: https://linear.app/settings/api'
    end
  end
end
