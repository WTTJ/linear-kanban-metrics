# frozen_string_literal: true

require 'optparse'

module KanbanMetrics
  # Handles command-line option parsing
  class OptionsParser
    def self.parse(args)
      options = {}

      option_parser = create_option_parser(options)
      option_parser.parse!(args)

      validate_and_set_defaults(options)
    end

    private_class_method def self.create_option_parser(options)
      OptionParser.new do |opts|
        opts.banner = "Usage: #{$PROGRAM_NAME} [options]"

        add_filter_options(opts, options)
        add_output_options(opts, options)
        add_feature_options(opts, options)
        add_help_option(opts)
      end
    end

    private_class_method def self.add_filter_options(opts, options)
      opts.on('--team-id ID', 'Filter by team ID') { |id| options[:team_id] = id }
      opts.on('--start-date DATE', 'Start date (YYYY-MM-DD)') { |date| options[:start_date] = date }
      opts.on('--end-date DATE', 'End date (YYYY-MM-DD)') { |date| options[:end_date] = date }
    end

    private_class_method def self.add_output_options(opts, options)
      opts.on('--format FORMAT', 'Output format (table, json, csv)') { |format| options[:format] = format }
      opts.on('--page-size SIZE', Integer, 'Number of issues per page (max: 250, default: 250)') do |size|
        options[:page_size] = size
      end
    end

    private_class_method def self.add_feature_options(opts, options)
      opts.on('--no-cache', 'Disable API response caching') { options[:no_cache] = true }
      opts.on('--team-metrics', 'Include team-based metrics breakdown') { options[:team_metrics] = true }
      opts.on('--timeseries', 'Include timeseries analysis') { options[:timeseries] = true }
      opts.on('--timeline ISSUE_ID', 'Show detailed timeline for specific issue') { |id| options[:timeline] = id }
      opts.on('--include-archived', 'Include archived tickets in the analysis') { options[:include_archived] = true }
    end

    private_class_method def self.add_help_option(opts)
      opts.on('-h', '--help', 'Show this help message') do
        puts opts
        exit
      end
    end

    private_class_method def self.validate_and_set_defaults(options)
      set_environment_defaults(options)
      validate_page_size(options)
      options
    end

    private_class_method def self.set_environment_defaults(options)
      options[:team_id] ||= ENV.fetch('LINEAR_TEAM_ID', nil)
      options[:start_date] ||= ENV.fetch('METRICS_START_DATE', nil)
      options[:end_date] ||= ENV.fetch('METRICS_END_DATE', nil)
    end

    private_class_method def self.validate_page_size(options)
      return unless options[:page_size] && options[:page_size] > 250

      puts "⚠️  Warning: Linear API maximum page size is 250. Using 250 instead of #{options[:page_size]}."
      options[:page_size] = 250
    end
  end
end
