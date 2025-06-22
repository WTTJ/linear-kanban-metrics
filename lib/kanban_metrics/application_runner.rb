# frozen_string_literal: true

module KanbanMetrics
  # Main application orchestrator
  class KanbanMetricsApp
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
      puts "📊 Found #{issues.length} issues, calculating metrics..."

      calculator = Calculators::KanbanMetricsCalculator.new(issues)
      metrics = calculator.overall_metrics
      team_metrics = options[:team_metrics] ? calculator.team_metrics : nil
      timeseries = options[:timeseries] ? Timeseries::TicketTimeseries.new(issues) : nil
      issues_for_report = options[:ticket_details] ? issues : nil

      Reports::KanbanReport.new(metrics, team_metrics, timeseries, issues_for_report).display(options[:format] || 'table')
    end
  end

  # Application entry point
  class ApplicationRunner
    def initialize(args)
      @args = args
    end

    def run
      validate_api_token
      options = OptionsParser.parse(@args)
      app = KanbanMetricsApp.new(ENV.fetch('LINEAR_API_TOKEN', nil))
      app.run(options)
    end

    private

    def validate_api_token
      api_token = ENV.fetch('LINEAR_API_TOKEN', nil)
      return if api_token && !api_token.empty?

      puts '❌ LINEAR_API_TOKEN environment variable not set'
      puts '   Please create a .env file with your Linear API token'
      puts '   Get your token from: https://linear.app/settings/api'
      exit 1
    end
  end
end
