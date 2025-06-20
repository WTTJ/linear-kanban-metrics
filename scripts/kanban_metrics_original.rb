#!/usr/bin/env ruby
# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'
require 'dotenv/load'
require 'optparse'
require 'date'
require 'terminal-table'
require 'csv'
require 'digest'
require 'fileutils'

# Value object for API query options
class QueryOptions
  attr_reader :team_id, :start_date, :end_date, :page_size, :no_cache, :include_archived

  def initialize(options = {})
    @team_id = options[:team_id]
    @start_date = options[:start_date]
    @end_date = options[:end_date]
    @page_size = normalize_page_size(options[:page_size])
    @no_cache = options[:no_cache]
    @include_archived = options[:include_archived]
  end

  def cache_key_data
    {
      team_id: team_id,
      start_date: start_date,
      end_date: end_date,
      include_archived: include_archived
    }.compact
  end

  private

  def normalize_page_size(size)
    return 250 unless size

    [size, 250].min
  end
end

# Handles HTTP requests to Linear API
class LinearHttpClient
  API_BASE_URL = 'https://api.linear.app'

  def initialize(api_token)
    @api_token = api_token
  end

  def post_graphql(query)
    http = create_http_client
    request = create_post_request(query)
    http.request(request)
  end

  private

  def create_http_client
    uri = URI("#{API_BASE_URL}/graphql")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http
  end

  def create_post_request(query)
    uri = URI("#{API_BASE_URL}/graphql")
    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = @api_token
    request['Content-Type'] = 'application/json'
    request.body = { query: query }.to_json
    request
  end
end

# Builds GraphQL queries for Linear API
class LinearQueryBuilder
  def build_issues_query(options, after_cursor = nil)
    filters = build_filters(options)
    pagination = build_pagination(options, after_cursor)

    log_query(filters, pagination) if ENV['DEBUG']

    <<~GRAPHQL
      query {
        issues(#{filters}#{pagination}) {
          pageInfo { hasNextPage endCursor }
          nodes {
            id identifier title
            state { id name type }
            team { id name }
            assignee { id name }
            priority estimate createdAt updatedAt completedAt startedAt archivedAt
            history(first: 50) {
              nodes {
                id createdAt
                fromState { id name type }
                toState { id name type }
              }
            }
          }
        }
      }
    GRAPHQL
  end

  private

  def build_filters(options)
    filters = []
    filters << team_filter(options.team_id) if options.team_id
    filters << date_filter(options.start_date, options.end_date) if date_filters_needed?(options)

    # Handle archived filter separately since it's a top-level parameter
    filter_string = filters.empty? ? '' : "filter: { #{filters.join(', ')} }, "

    # Add includeArchived as a separate parameter if needed
    if options.include_archived
      archive_param = 'includeArchived: true'
      filter_string += "#{archive_param}, "
    end

    filter_string
  end

  def build_pagination(options, after_cursor)
    args = ["first: #{options.page_size}"]
    args << "after: \"#{after_cursor}\"" if after_cursor
    args.join(', ')
  end

  def team_filter(team_id)
    "team: { id: { eq: \"#{team_id}\" } }"
  end

  def date_filter(start_date, end_date)
    conditions = []
    conditions << "gte: \"#{start_date}T00:00:00.000Z\"" if start_date
    conditions << "lte: \"#{end_date}T23:59:59.999Z\"" if end_date
    "updatedAt: { #{conditions.join(', ')} }"
  end

  def date_filters_needed?(options)
    options.start_date || options.end_date
  end

  def log_query(filters, pagination)
    puts "🔍 GraphQL Query: issues(#{filters}#{pagination})"
  end
end

# Handles caching of API responses
class LinearCache
  CACHE_DIR = '.linear_cache'

  def initialize
    setup_cache_directory
  end

  def fetch_cached_issues(cache_key)
    return nil unless cached_data_exists?(cache_key)

    cached_data = read_from_cache(cache_key)
    return nil unless cached_data
    return nil if cache_expired?(cached_data[:timestamp])

    log_cache_hit(cached_data[:issues], cache_key)
    cached_data[:issues]
  end

  def save_issues_to_cache(cache_key, issues)
    save_to_cache(cache_key, issues)
  end

  def generate_cache_key(options)
    Digest::MD5.hexdigest(options.cache_key_data.to_json)
  end

  private

  def setup_cache_directory
    FileUtils.mkdir_p(CACHE_DIR)
  end

  def cached_data_exists?(cache_key)
    File.exist?(cache_file_path(cache_key))
  end

  def cache_file_path(cache_key)
    File.join(CACHE_DIR, "#{cache_key}.json")
  end

  def read_from_cache(cache_key)
    content = File.read(cache_file_path(cache_key))
    data = JSON.parse(content)
    {
      issues: data['issues'],
      timestamp: Time.parse(data['timestamp'])
    }
  rescue StandardError => e
    log_cache_error("Cache read error: #{e.message}")
    nil
  end

  def save_to_cache(cache_key, issues)
    cache_data = { issues: issues, timestamp: Time.now.iso8601 }
    File.write(cache_file_path(cache_key), JSON.pretty_generate(cache_data))
    log_cache_save(issues.length)
  rescue StandardError => e
    log_cache_error("Cache write error: #{e.message}")
  end

  def cache_expired?(timestamp)
    timestamp.to_date < Time.now.to_date
  end

  def log_cache_hit(issues, cache_key)
    return unless ENV['DEBUG'] || !ENV['QUIET']

    puts "✅ Using cached data (#{issues.length} issues) - cache key: #{cache_key[0..7]}..."
  end

  def log_cache_save(count)
    puts "💾 Saved #{count} issues to cache" if ENV['DEBUG']
  end

  def log_cache_error(message)
    puts "⚠️ #{message}" if ENV['DEBUG']
  end
end

# Handles Linear API interactions with caching
class LinearClient
  def initialize(api_token)
    @http_client = LinearHttpClient.new(api_token)
    @query_builder = LinearQueryBuilder.new
    @cache = LinearCache.new
  end

  def fetch_issues(options_hash = {})
    options = QueryOptions.new(options_hash)

    if options.no_cache
      fetch_from_api(options)
    else
      fetch_with_caching(options)
    end
  end

  private

  def fetch_with_caching(options)
    cache_key = @cache.generate_cache_key(options)
    cached_issues = @cache.fetch_cached_issues(cache_key)

    return cached_issues if cached_issues

    log_cache_miss
    issues = fetch_from_api(options)
    @cache.save_issues_to_cache(cache_key, issues)
    issues
  end

  def fetch_from_api(options)
    log_api_fetch_start(options.no_cache)

    issues = paginated_fetch(options)

    log_api_fetch_complete(issues.length)
    issues
  end

  def paginated_fetch(options)
    paginator = ApiPaginator.new(@http_client, @query_builder)
    paginator.fetch_all_pages(options)
  end

  def log_cache_miss
    return unless ENV['DEBUG'] || !ENV['QUIET']

    puts '🔄 Cache miss or expired, fetching from API...'
  end

  def log_api_fetch_start(cache_disabled)
    message = cache_disabled ? 'Cache disabled, fetching from API...' : 'Fetching from API...'
    puts "🔄 #{message}" if ENV['DEBUG']
  end

  def log_api_fetch_complete(count)
    return unless ENV['DEBUG'] || count > 250

    puts "✅ Successfully fetched #{count} total issues from Linear API"
  end
end

# Handles paginated API requests
class ApiPaginator
  MAX_PAGES = 100

  def initialize(http_client, query_builder)
    @http_client = http_client
    @query_builder = query_builder
  end

  def fetch_all_pages(options)
    all_issues = []
    page_state = PageState.new

    while page_state.has_next_page?
      log_page_fetch(page_state.current_page, all_issues.length)

      page_result = fetch_single_page(options, page_state.after_cursor)
      return [] if page_result.nil?

      all_issues.concat(page_result[:issues])
      page_state.update(page_result[:page_info])

      break if page_state.safety_limit_reached?
    end

    all_issues
  end

  private

  def fetch_single_page(options, after_cursor)
    query = @query_builder.build_issues_query(options, after_cursor)
    response = @http_client.post_graphql(query)
    ApiResponseParser.new(response).parse
  end

  def log_page_fetch(page, total_issues)
    return unless ENV['DEBUG'] || total_issues > 250

    puts "📄 Fetching page #{page}..."
  end
end

# Tracks pagination state
class PageState
  MAX_PAGES = 100

  attr_reader :current_page, :after_cursor

  def initialize
    @current_page = 1
    @has_next_page = true
    @after_cursor = nil
  end

  def has_next_page?
    @has_next_page
  end

  def update(page_info)
    @has_next_page = page_info[:has_next_page]
    @after_cursor = page_info[:end_cursor]
    @current_page += 1
  end

  def safety_limit_reached?
    @current_page > MAX_PAGES
  end
end

# Parses API responses
class ApiResponseParser
  def initialize(response)
    @response = response
  end

  def parse
    return nil unless response_successful?

    data = parse_json_response
    return nil if data.nil?
    return nil if graphql_errors_present?(data)

    extract_issues_data(data)
  end

  private

  def response_successful?
    if @response.code != '200'
      log_http_error
      return false
    end
    true
  end

  def parse_json_response
    JSON.parse(@response.body)
  rescue JSON::ParserError => e
    log_json_error(e)
    nil
  end

  def graphql_errors_present?(data)
    return false unless data['errors']

    log_graphql_errors(data['errors'])
    true
  end

  def extract_issues_data(data)
    issues_data = data.dig('data', 'issues')
    return nil unless issues_data

    {
      issues: issues_data['nodes'] || [],
      page_info: normalize_page_info(issues_data['pageInfo'] || {})
    }
  end

  def normalize_page_info(page_info)
    {
      has_next_page: page_info['hasNextPage'] || false,
      end_cursor: page_info['endCursor']
    }
  end

  def log_http_error
    puts "❌ HTTP Error: #{@response.code} - #{@response.message}"
    puts "Response body: #{@response.body}" if ENV['DEBUG']
  end

  def log_json_error(error)
    puts "❌ JSON Parse Error: #{error.message}" if ENV['DEBUG']
  end

  def log_graphql_errors(errors)
    puts '❌ GraphQL errors:'
    errors.each { |error| puts "  - #{error['message']}" }
  end
end

# Handles issue partitioning by status
class IssuePartitioner
  def self.partition(issues)
    completed = issues.select { |i| completed_status?(i) }
    in_progress = issues.select { |i| in_progress_status?(i) }
    backlog = issues.select { |i| backlog_status?(i) }
    [completed, in_progress, backlog]
  end

  private_class_method def self.completed_status?(issue)
    issue.dig('state', 'type') == 'completed'
  end

  private_class_method def self.in_progress_status?(issue)
    issue.dig('state', 'type') == 'started'
  end

  private_class_method def self.backlog_status?(issue)
    %w[backlog unstarted].include?(issue.dig('state', 'type'))
  end
end

# Calculates time-based metrics
class TimeMetricsCalculator
  def initialize(issues)
    @issues = issues
  end

  def cycle_time_stats
    times = calculate_cycle_times
    build_time_stats(times)
  end

  def lead_time_stats
    times = calculate_lead_times
    build_time_stats(times)
  end

  private

  def calculate_cycle_times
    @issues.filter_map do |issue|
      started_at = find_start_time(issue)
      completed_at = issue['completedAt']
      next unless started_at && completed_at

      calculate_time_difference(started_at, completed_at)
    end
  end

  def calculate_lead_times
    @issues.filter_map do |issue|
      created_at = issue['createdAt']
      completed_at = issue['completedAt']
      next unless created_at && completed_at

      calculate_time_difference(created_at, completed_at)
    end
  end

  def find_start_time(issue)
    issue['startedAt'] || find_history_time(issue, 'started')
  end

  def find_history_time(issue, state_type)
    event = issue.dig('history', 'nodes')&.find do |e|
      e.dig('toState', 'type') == state_type
    end
    event&.dig('createdAt')
  end

  def calculate_time_difference(start_time, end_time)
    (DateTime.parse(end_time) - DateTime.parse(start_time)).to_f
  end

  def build_time_stats(times)
    {
      average: calculate_average(times),
      median: calculate_median(times),
      p95: calculate_percentile(times, 95)
    }
  end

  def calculate_average(arr)
    return 0 if arr.empty?

    (arr.sum.to_f / arr.size).round(2)
  end

  def calculate_median(arr)
    return 0 if arr.empty?

    sorted = arr.sort
    len = sorted.size
    if len.odd?
      sorted[len / 2].round(2)
    else
      ((sorted[(len / 2) - 1] + sorted[len / 2]) / 2.0).round(2)
    end
  end

  def calculate_percentile(arr, percentile)
    return 0 if arr.empty?

    sorted = arr.sort
    idx = (percentile / 100.0 * (sorted.size - 1)).round
    sorted[idx].round(2)
  end
end

# Calculates throughput metrics
class ThroughputCalculator
  def initialize(completed_issues)
    @completed_issues = completed_issues
  end

  def stats
    return default_stats if @completed_issues.empty?

    weekly_counts = calculate_weekly_counts
    {
      weekly_avg: calculate_average(weekly_counts),
      total_completed: @completed_issues.size
    }
  end

  private

  def default_stats
    { weekly_avg: 0, total_completed: 0 }
  end

  def calculate_weekly_counts
    weeks = group_by_week
    weeks.values.map(&:size)
  end

  def group_by_week
    @completed_issues.group_by do |issue|
      Date.parse(issue['completedAt']).strftime('%Y-W%U')
    end
  end

  def calculate_average(arr)
    return 0 if arr.empty?

    (arr.sum.to_f / arr.size).round(2)
  end
end

# Calculates flow efficiency metrics
class FlowEfficiencyCalculator
  def initialize(issues)
    @issues = issues
  end

  def calculate
    return 0 if @issues.empty?

    total_efficiency = @issues.sum { |issue| calculate_issue_efficiency(issue) }
    ((total_efficiency / @issues.size) * 100).round(2)
  end

  private

  def calculate_issue_efficiency(issue)
    history = issue.dig('history', 'nodes') || []
    return 0 if history.empty?

    active_time, total_time = calculate_times(history)
    total_time.zero? ? 0 : active_time / total_time
  end

  def calculate_times(history)
    active_time = 0
    total_time = 0

    history.each_cons(2) do |from_event, to_event|
      duration = calculate_duration(from_event, to_event)
      total_time += duration
      active_time += duration if active_state?(from_event)
    end

    [active_time, total_time]
  end

  def calculate_duration(from_event, to_event)
    from_time = DateTime.parse(from_event['createdAt'])
    to_time = DateTime.parse(to_event['createdAt'])
    (to_time - from_time).to_f
  end

  def active_state?(event)
    to_state_type = event.dig('toState', 'type')
    %w[started unstarted].include?(to_state_type)
  end
end

# Main metrics calculator that orchestrates all calculations
class KanbanMetricsCalculator
  def initialize(issues)
    @issues = issues
  end

  def overall_metrics
    completed, in_progress, backlog = IssuePartitioner.partition(@issues)
    time_calculator = TimeMetricsCalculator.new(completed)

    {
      total_issues: @issues.size,
      completed_issues: completed.size,
      in_progress_issues: in_progress.size,
      backlog_issues: backlog.size,
      cycle_time: time_calculator.cycle_time_stats,
      lead_time: time_calculator.lead_time_stats,
      throughput: ThroughputCalculator.new(completed).stats,
      flow_efficiency: FlowEfficiencyCalculator.new(completed).calculate
    }
  end

  def team_metrics
    team_groups = group_issues_by_team
    team_groups.transform_values { |issues| calculate_team_stats(issues) }
  end

  private

  def group_issues_by_team
    @issues.group_by { |issue| issue.dig('team', 'name') || 'Unknown Team' }
  end

  def calculate_team_stats(team_issues)
    completed, in_progress, backlog = IssuePartitioner.partition(team_issues)
    time_calculator = TimeMetricsCalculator.new(completed)

    {
      total_issues: team_issues.size,
      completed_issues: completed.size,
      in_progress_issues: in_progress.size,
      backlog_issues: backlog.size,
      cycle_time: time_calculator.cycle_time_stats,
      lead_time: time_calculator.lead_time_stats,
      throughput: ThroughputCalculator.new(completed).stats[:total_completed]
    }
  end
end

# Builds timeline events for issues
class TimelineBuilder
  def build_timeline(issue)
    events = []
    events << create_creation_event(issue)
    events.concat(extract_history_events(issue))
    events.sort_by { |event| DateTime.parse(event[:date]) }
  end

  private

  def create_creation_event(issue)
    {
      date: issue['createdAt'],
      from_state: nil,
      to_state: 'created',
      event_type: 'created'
    }
  end

  def extract_history_events(issue)
    history_nodes = issue.dig('history', 'nodes') || []

    history_nodes.filter_map do |event|
      next unless event['toState']

      {
        date: event['createdAt'],
        from_state: event.dig('fromState', 'name'),
        to_state: event.dig('toState', 'name'),
        event_type: 'status_change'
      }
    end
  end
end

# Analyzes timeseries data
class TimeseriesAnalyzer
  def initialize(issues)
    @issues = issues
    @timeline_builder = TimelineBuilder.new
  end

  def status_flow_analysis
    transitions = collect_transitions
    transitions.sort_by { |_, count| -count }.to_h
  end

  def average_time_in_status
    status_durations = collect_status_durations
    status_durations.transform_values { |durations| calculate_average(durations) }
  end

  def daily_status_counts
    events = collect_all_events
    events_by_date = group_events_by_date(events)
    events_by_date.transform_values { |daily_events| count_by_status(daily_events) }
  end

  private

  def collect_transitions
    transitions = Hash.new(0)

    @issues.each do |issue|
      timeline = @timeline_builder.build_timeline(issue)
      timeline.each_cons(2) do |from_event, to_event|
        transition_key = "#{from_event[:to_state]} → #{to_event[:to_state]}"
        transitions[transition_key] += 1
      end
    end

    transitions
  end

  def collect_status_durations
    status_durations = Hash.new { |h, k| h[k] = [] }

    @issues.each do |issue|
      timeline = @timeline_builder.build_timeline(issue)
      timeline.each_cons(2) do |current, next_event|
        duration = calculate_days_between(current[:date], next_event[:date])
        status_durations[current[:to_state]] << duration
      end
    end

    status_durations
  end

  def collect_all_events
    events = []

    @issues.each do |issue|
      timeline = @timeline_builder.build_timeline(issue)
      timeline.each do |event|
        events << {
          issue_id: issue['identifier'],
          date: event[:date],
          to_state: event[:to_state],
          event_type: event[:event_type]
        }
      end
    end

    events.sort_by { |event| DateTime.parse(event[:date]) }
  end

  def group_events_by_date(events)
    events.group_by { |event| Date.parse(event[:date]) }.sort.to_h
  end

  def count_by_status(events)
    events.group_by { |event| event[:to_state] }.transform_values(&:count)
  end

  def calculate_days_between(start_date, end_date)
    (Date.parse(end_date) - Date.parse(start_date)).to_f
  end

  def calculate_average(durations)
    return 0 if durations.empty?

    (durations.sum / durations.size).round(2)
  end
end

# Main timeseries class
class TicketTimeseries < TimeseriesAnalyzer
  def generate_timeseries
    @issues.map do |issue|
      {
        id: issue['identifier'],
        title: issue['title'],
        team: issue.dig('team', 'name'),
        timeline: @timeline_builder.build_timeline(issue)
      }
    end
  end
end

# Handles table formatting
class TableFormatter
  KPI_DESCRIPTIONS = {
    total_issues: 'Total number of issues in the dataset',
    completed_issues: 'Issues that have been finished/delivered',
    in_progress_issues: 'Issues currently being worked on',
    backlog_issues: 'Issues waiting to be started',
    flow_efficiency: 'Percentage of time spent on active work vs waiting',
    average_cycle_time: 'Average time from start to completion',
    median_cycle_time: '50% of items complete faster than this',
    p95_cycle_time: '95% of items complete faster than this',
    average_lead_time: 'Average time from creation to completion',
    median_lead_time: '50% of items delivered faster than this',
    p95_lead_time: '95% of items delivered faster than this',
    weekly_avg: 'Average items completed per week',
    total_completed: 'Total items delivered in time period'
  }.freeze

  def initialize(metrics, team_metrics)
    @metrics = metrics
    @team_metrics = team_metrics
  end

  def print_summary
    table = build_summary_table
    puts "\n📈 SUMMARY"
    puts table
  end

  def print_cycle_time
    table = build_cycle_time_table
    puts "\n⏱️  CYCLE TIME"
    puts table
  end

  def print_lead_time
    table = build_lead_time_table
    puts "\n📏 LEAD TIME"
    puts table
  end

  def print_throughput
    table = build_throughput_table
    puts "\n🚀 THROUGHPUT"
    puts table
  end

  def print_team_metrics
    return unless team_metrics_available?

    print_individual_teams
    print_team_comparison
  end

  def print_kpi_definitions
    table = build_definitions_table
    puts "\n📚 KPI DEFINITIONS"
    puts '=' * 80
    puts table
  end

  private

  def build_summary_table
    Terminal::Table.new do |tab|
      tab.headings = %w[Metric Value Description]
      tab.add_row ['Total Issues', @metrics[:total_issues], KPI_DESCRIPTIONS[:total_issues]]
      tab.add_row ['Completed Issues', @metrics[:completed_issues], KPI_DESCRIPTIONS[:completed_issues]]
      tab.add_row ['In Progress Issues', @metrics[:in_progress_issues], KPI_DESCRIPTIONS[:in_progress_issues]]
      tab.add_row ['Backlog Issues', @metrics[:backlog_issues], KPI_DESCRIPTIONS[:backlog_issues]]
      tab.add_row ['Flow Efficiency', "#{@metrics[:flow_efficiency]}%", KPI_DESCRIPTIONS[:flow_efficiency]]
    end
  end

  def build_cycle_time_table
    Terminal::Table.new do |tab|
      tab.headings = %w[Metric Days Description]
      tab.add_row ['Average Cycle Time', @metrics[:cycle_time][:average], KPI_DESCRIPTIONS[:average_cycle_time]]
      tab.add_row ['Median Cycle Time', @metrics[:cycle_time][:median], KPI_DESCRIPTIONS[:median_cycle_time]]
      tab.add_row ['95th Percentile', @metrics[:cycle_time][:p95], KPI_DESCRIPTIONS[:p95_cycle_time]]
    end
  end

  def build_lead_time_table
    Terminal::Table.new do |tab|
      tab.headings = %w[Metric Days Description]
      tab.add_row ['Average Lead Time', @metrics[:lead_time][:average], KPI_DESCRIPTIONS[:average_lead_time]]
      tab.add_row ['Median Lead Time', @metrics[:lead_time][:median], KPI_DESCRIPTIONS[:median_lead_time]]
      tab.add_row ['95th Percentile', @metrics[:lead_time][:p95], KPI_DESCRIPTIONS[:p95_lead_time]]
    end
  end

  def build_throughput_table
    Terminal::Table.new do |tab|
      tab.headings = %w[Metric Value Description]
      tab.add_row ['Weekly Average', @metrics[:throughput][:weekly_avg], KPI_DESCRIPTIONS[:weekly_avg]]
      tab.add_row ['Total Completed', @metrics[:throughput][:total_completed], KPI_DESCRIPTIONS[:total_completed]]
    end
  end

  def build_definitions_table
    Terminal::Table.new do |tab|
      tab.headings = ['KPI', 'Definition', 'What it tells you']
      tab.add_row ['Cycle Time', 'Time from when work starts to completion',
                   'How efficient your team is at executing work']
      tab.add_row ['Lead Time', 'Time from request/creation to delivery', 'How responsive you are to customer needs']
      tab.add_row ['Throughput', 'Number of items completed per time period', 'Team productivity and delivery capacity']
      tab.add_row ['Flow Efficiency', '% of time spent on active work vs waiting',
                   'How much waste exists in your process']
      tab.add_row ['WIP (Work in Progress)', 'Number of items currently being worked on',
                   'Process load and potential bottlenecks']
      tab.add_row ['95th Percentile', '95% of items complete faster than this',
                   'Worst-case scenario for delivery predictions']
    end
  end

  def team_metrics_available?
    @team_metrics && !@team_metrics.empty?
  end

  def print_individual_teams
    puts "\n👥 TEAM METRICS"
    puts '=' * 80

    @team_metrics.sort.each do |team, stats|
      puts "\n🏷️  #{team.upcase}"
      puts build_team_table(stats)
    end
  end

  def print_team_comparison
    puts "\n📊 TEAM COMPARISON"
    puts build_team_comparison_table
  end

  def build_team_table(stats)
    Terminal::Table.new do |tab|
      tab.headings = %w[Metric Value Description]
      add_basic_metrics_rows(tab, stats)
      add_time_metrics_rows(tab, stats)
      add_throughput_row(tab, stats)
    end
  end

  def build_team_comparison_table
    Terminal::Table.new do |tab|
      tab.headings = ['Team', 'Total', 'Completed', 'In Progress', 'Backlog', 'Avg Cycle', 'Median Cycle', 'Avg Lead',
                      'Median Lead', 'Throughput']
      @team_metrics.sort.each do |team, stats|
        tab.add_row [
          team,
          stats[:total_issues],
          stats[:completed_issues],
          stats[:in_progress_issues],
          stats[:backlog_issues],
          stats[:cycle_time][:average],
          stats[:cycle_time][:median],
          stats[:lead_time][:average],
          stats[:lead_time][:median],
          stats[:throughput]
        ]
      end
    end
  end

  def add_basic_metrics_rows(table, stats)
    table.add_row ['Total Issues', stats[:total_issues], KPI_DESCRIPTIONS[:total_issues]]
    table.add_row ['Completed Issues', stats[:completed_issues], KPI_DESCRIPTIONS[:completed_issues]]
    table.add_row ['In Progress Issues', stats[:in_progress_issues], KPI_DESCRIPTIONS[:in_progress_issues]]
    table.add_row ['Backlog Issues', stats[:backlog_issues], KPI_DESCRIPTIONS[:backlog_issues]]
  end

  def add_time_metrics_rows(table, stats)
    table.add_row ['Avg Cycle Time', "#{stats[:cycle_time][:average]} days", KPI_DESCRIPTIONS[:average_cycle_time]]
    table.add_row ['Median Cycle Time', "#{stats[:cycle_time][:median]} days", KPI_DESCRIPTIONS[:median_cycle_time]]
    table.add_row ['Avg Lead Time', "#{stats[:lead_time][:average]} days", KPI_DESCRIPTIONS[:average_lead_time]]
    table.add_row ['Median Lead Time', "#{stats[:lead_time][:median]} days", KPI_DESCRIPTIONS[:median_lead_time]]
  end

  def add_throughput_row(table, stats)
    table.add_row ['Throughput', "#{stats[:throughput]} completed", KPI_DESCRIPTIONS[:total_completed]]
  end
end

# Handles CSV output formatting
class CsvFormatter
  def initialize(metrics, team_metrics, timeseries)
    @metrics = metrics
    @team_metrics = team_metrics
    @timeseries = timeseries
  end

  def generate
    CSV.generate do |csv|
      add_overall_metrics(csv)
      add_team_metrics(csv) if @team_metrics
      add_timeseries_data(csv) if @timeseries
    end
  end

  private

  def add_overall_metrics(csv)
    csv << %w[Metric Value Unit]
    add_issue_count_metrics(csv)
    add_cycle_time_metrics(csv)
    add_lead_time_metrics(csv)
    add_throughput_metrics(csv)
    add_flow_efficiency_metric(csv)
  end

  def add_issue_count_metrics(csv)
    csv << ['Total Issues', @metrics[:total_issues], 'count']
    csv << ['Completed Issues', @metrics[:completed_issues], 'count']
    csv << ['In Progress Issues', @metrics[:in_progress_issues], 'count']
    csv << ['Backlog Issues', @metrics[:backlog_issues], 'count']
  end

  def add_cycle_time_metrics(csv)
    csv << ['Average Cycle Time', @metrics[:cycle_time][:average], 'days']
    csv << ['Median Cycle Time', @metrics[:cycle_time][:median], 'days']
    csv << ['95th Percentile Cycle Time', @metrics[:cycle_time][:p95], 'days']
  end

  def add_lead_time_metrics(csv)
    csv << ['Average Lead Time', @metrics[:lead_time][:average], 'days']
    csv << ['Median Lead Time', @metrics[:lead_time][:median], 'days']
    csv << ['95th Percentile Lead Time', @metrics[:lead_time][:p95], 'days']
  end

  def add_throughput_metrics(csv)
    csv << ['Weekly Throughput Average', @metrics[:throughput][:weekly_avg], 'issues/week']
    csv << ['Total Completed', @metrics[:throughput][:total_completed], 'count']
  end

  def add_flow_efficiency_metric(csv)
    csv << ['Flow Efficiency', @metrics[:flow_efficiency], 'percentage']
  end

  def add_team_metrics(csv)
    csv << []
    csv << ['TEAM METRICS']
    csv << ['Team', 'Total Issues', 'Completed Issues', 'In Progress Issues', 'Backlog Issues', 'Avg Cycle Time',
            'Median Cycle Time', 'Avg Lead Time', 'Median Lead Time', 'Throughput']

    @team_metrics.sort.each do |team, stats|
      csv << [
        team,
        stats[:total_issues],
        stats[:completed_issues],
        stats[:in_progress_issues],
        stats[:backlog_issues],
        stats[:cycle_time][:average],
        stats[:cycle_time][:median],
        stats[:lead_time][:average],
        stats[:lead_time][:median],
        stats[:throughput]
      ]
    end
  end

  def add_timeseries_data(csv)
    csv << []
    csv << ['TIMESERIES ANALYSIS']
    add_status_transitions(csv)
    add_time_in_status(csv)
  end

  def add_status_transitions(csv)
    csv << []
    csv << ['STATUS TRANSITIONS']
    csv << %w[Transition Count]
    @timeseries.status_flow_analysis.each do |transition, count|
      csv << [transition, count]
    end
  end

  def add_time_in_status(csv)
    csv << []
    csv << ['AVERAGE TIME IN STATUS']
    csv << ['Status', 'Average Days']
    @timeseries.average_time_in_status.each do |status, days|
      csv << [status, days]
    end
  end
end

# Handles JSON output formatting
class JsonFormatter
  def initialize(metrics, team_metrics, timeseries)
    @metrics = metrics
    @team_metrics = team_metrics
    @timeseries = timeseries
  end

  def generate
    output = { overall: @metrics }
    output[:by_team] = @team_metrics.sort.to_h if @team_metrics
    output[:timeseries] = build_timeseries_data if @timeseries
    JSON.pretty_generate(output)
  end

  private

  def build_timeseries_data
    {
      status_transitions: @timeseries.status_flow_analysis,
      average_time_in_status: @timeseries.average_time_in_status,
      daily_activity: @timeseries.daily_status_counts,
      ticket_timelines: @timeseries.generate_timeseries
    }
  end
end

# Handles timeseries table formatting
class TimeseriesTableFormatter
  def initialize(timeseries)
    @timeseries = timeseries
  end

  def print_timeseries
    puts "\n� TIMESERIES ANALYSIS"
    puts '=' * 80

    print_status_transitions
    print_time_in_status
    print_recent_activity
  end

  private

  def print_status_transitions
    flow_analysis = @timeseries.status_flow_analysis
    return if flow_analysis.empty?

    puts "\n� STATUS TRANSITIONS (Most Common)"
    table = build_transitions_table(flow_analysis)
    puts table
  end

  def print_time_in_status
    time_in_status = @timeseries.average_time_in_status
    return if time_in_status.empty?

    puts "\n⏰ AVERAGE TIME IN STATUS"
    table = build_time_in_status_table(time_in_status)
    puts table
  end

  def print_recent_activity
    daily_counts = @timeseries.daily_status_counts
    return if daily_counts.empty?

    puts "\n📊 RECENT ACTIVITY (Last 10 Days)"
    table = build_activity_table(daily_counts)
    puts table
  end

  def build_transitions_table(flow_analysis)
    Terminal::Table.new do |tab|
      tab.headings = %w[Transition Count Description]
      flow_analysis.first(10).each do |transition, count|
        tab.add_row [transition, count, 'Number of times this transition occurred']
      end
    end
  end

  def build_time_in_status_table(time_in_status)
    Terminal::Table.new do |tab|
      tab.headings = ['Status', 'Average Days', 'Description']
      time_in_status.sort_by { |_, days| -days }.each do |status, days|
        tab.add_row [status, days, 'Average time issues spend in this status']
      end
    end
  end

  def build_activity_table(daily_counts)
    recent_days = daily_counts.keys.last(10)

    Terminal::Table.new do |tab|
      tab.headings = ['Date', 'Status Changes', 'Description']
      recent_days.each do |date|
        changes = daily_counts[date]
        total_changes = changes.values.sum
        status_summary = changes.map { |status, count| "#{status}(#{count})" }.join(', ')
        tab.add_row [date.strftime('%Y-%m-%d'), "#{total_changes} total: #{status_summary}",
                     'Daily status change activity']
      end
    end
  end
end

# Main report orchestrator
class KanbanReport
  def initialize(metrics, team_metrics, timeseries = nil)
    @metrics = metrics
    @team_metrics = team_metrics
    @timeseries = timeseries
  end

  def display(format = 'table')
    case format.downcase
    when 'json'
      display_json
    when 'csv'
      display_csv
    else
      display_table
    end
  end

  private

  def display_json
    formatter = JsonFormatter.new(@metrics, @team_metrics, @timeseries)
    puts formatter.generate
  end

  def display_csv
    formatter = CsvFormatter.new(@metrics, @team_metrics, @timeseries)
    puts formatter.generate
  end

  def display_table
    print_header
    table_formatter = TableFormatter.new(@metrics, @team_metrics)

    table_formatter.print_summary
    table_formatter.print_cycle_time
    table_formatter.print_lead_time
    table_formatter.print_throughput
    table_formatter.print_team_metrics

    print_timeseries_tables if @timeseries
    table_formatter.print_kpi_definitions
  end

  def print_header
    puts "\n#{'=' * 60}"
    puts '📊 LINEAR KANBAN METRICS REPORT'
    puts '=' * 60
  end

  def print_timeseries_tables
    timeseries_formatter = TimeseriesTableFormatter.new(@timeseries)
    timeseries_formatter.print_timeseries
  end
end

# Handles CLI option parsing
class OptionsParser
  def self.parse(args)
    options = {}

    parser = OptionParser.new do |opts|
      opts.banner = 'Usage: ruby kanban_metrics.rb [options]'

      add_filter_options(opts, options)
      add_output_options(opts, options)
      add_feature_options(opts, options)
      add_help_option(opts)
    end

    parser.parse!(args)
    validate_and_set_defaults(options)
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

# Handles timeline display for individual issues
class TimelineDisplay
  def initialize(issues)
    @issues = issues
  end

  def show_timeline(issue_id)
    timeline_data = find_timeline_data(issue_id)

    if timeline_data
      print_timeline(timeline_data)
    else
      puts "❌ Issue #{issue_id} not found"
    end
  end

  private

  def find_timeline_data(issue_id)
    timeseries = TicketTimeseries.new(@issues)
    timeseries.generate_timeseries.find { |t| t[:id] == issue_id }
  end

  def print_timeline(timeline_data)
    puts "\n📈 TIMELINE FOR #{timeline_data[:id]}: #{timeline_data[:title]}"
    puts "Team: #{timeline_data[:team]}"
    puts '=' * 80

    timeline_data[:timeline].each do |event|
      date_str = DateTime.parse(event[:date]).strftime('%Y-%m-%d %H:%M')
      transition = event[:from_state] ? "#{event[:from_state]} →" : 'Created →'
      puts "#{date_str} | #{transition} #{event[:to_state]}"
    end
  end
end

# Main application orchestrator
class KanbanMetricsApp
  def initialize(api_token)
    @client = LinearClient.new(api_token)
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
    TimelineDisplay.new(issues).show_timeline(issue_id)
  end

  def show_metrics(issues, options)
    puts "📊 Found #{issues.length} issues, calculating metrics..."

    calculator = KanbanMetricsCalculator.new(issues)
    metrics = calculator.overall_metrics
    team_metrics = options[:team_metrics] ? calculator.team_metrics : nil
    timeseries = options[:timeseries] ? TicketTimeseries.new(issues) : nil

    KanbanReport.new(metrics, team_metrics, timeseries).display(options[:format] || 'table')
  end
end

# Application entry point
class ApplicationRunner
  def self.run
    validate_api_token
    options = OptionsParser.parse(ARGV)
    app = KanbanMetricsApp.new(ENV.fetch('LINEAR_API_TOKEN', nil))
    app.run(options)
  end

  private_class_method def self.validate_api_token
    api_token = ENV.fetch('LINEAR_API_TOKEN', nil)
    return if api_token && !api_token.empty?

    puts '❌ LINEAR_API_TOKEN environment variable not set'
    puts '   Please create a .env file with your Linear API token'
    puts '   Get your token from: https://linear.app/settings/api'
    exit 1
  end
end

# Run the application
ApplicationRunner.run if __FILE__ == $PROGRAM_NAME
