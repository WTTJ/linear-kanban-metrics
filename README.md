# Kanban Metrics Collector for Linear

This Ruby script collects kanban metrics from the Linear API, including cycle time, lead time, throughput, and work in progress (WIP).

## Setup

1. Install Ruby dependencies:
```bash
bundle install
```

2. Create a `.env` file from the example:
```bash
cp config/.env.example config/.env
```

3. Get your Linear API token from [Linear Settings](https://linear.app/settings/api) and add it to your `.env` file:
```
LINEAR_API_TOKEN=your_actual_token_here
```

## Usage

Run the script to collect metrics:
```bash
ruby kanban_metrics.rb
```

### Options

- `--team-id TEAM_ID` - Filter by specific team ID
- `--start-date YYYY-MM-DD` - Start date for metrics collection
- `--end-date YYYY-MM-DD` - End date for metrics collection
- `--format FORMAT` - Output format (table, json, csv) - default: table
- `--page-size SIZE` - Number of issues per page for API pagination (default: 250)
- `--no-cache` - Disable API response caching (fetch fresh data)
- `--team-metrics` - Include team-based metrics breakdown (disabled by default)
- `--include-archived` - Include archived tickets in the analysis (disabled by default)

### Examples

```bash
# Basic usage (overall metrics only)
ruby kanban_metrics.rb

# Fetch all issues with automatic pagination
ruby kanban_metrics.rb --page-size 500  # Larger pages for faster fetching

# Include team metrics breakdown
ruby kanban_metrics.rb --team-metrics

# Filter by team and date range with team metrics
ruby kanban_metrics.rb --team-id "TEAM123" --start-date "2024-01-01" --end-date "2024-12-31" --team-metrics

# Output as JSON
ruby kanban_metrics.rb --format json

# Output as CSV with team metrics
ruby kanban_metrics.rb --format csv --team-metrics

# Include archived tickets in the analysis
ruby kanban_metrics.rb --include-archived

# Include archived tickets with team metrics
ruby kanban_metrics.rb --include-archived --team-metrics

# Filter by date range and include archived tickets
ruby kanban_metrics.rb --start-date "2024-01-01" --end-date "2024-12-31" --include-archived
```

## Metrics Collected

- **Cycle Time**: Time from when work starts to when it's completed
- **Lead Time**: Time from when work is requested to when it's completed
- **Throughput**: Number of items completed per time period
- **Work in Progress (WIP)**: Number of items currently in progress
- **Flow Efficiency**: Percentage of time spent on active work vs waiting

## � Automatic Pagination

The script now supports automatic pagination to fetch **all issues** from your Linear workspace, not just the first 250. The script will automatically fetch multiple pages until all issues matching your criteria are retrieved.

```bash
# Automatically fetches all issues (may be thousands!)
ruby kanban_metrics.rb

# The script will show pagination progress for large datasets
### 📄 Pagination Support

The script automatically fetches all issues from Linear using pagination. Linear's API has a maximum page size of 250 issues per request:

```bash
# Use default page size (250)
ruby kanban_metrics.rb

# Custom page size (automatically capped at 250)
ruby kanban_metrics.rb --page-size 100

# Attempting to use >250 will show a warning and use 250
ruby kanban_metrics.rb --page-size 1000
# ⚠️  Warning: Linear API maximum page size is 250. Using 250 instead of 1000.
```

With debug mode enabled, you can see the pagination in action:

```bash
DEBUG=true ruby kanban_metrics.rb
# 📄 Fetching page 1...
# 📄 Fetching page 2...
# 📄 Fetching page 3...
# ✅ Successfully fetched 5015 total issues from Linear API
```

## 👥 Team Metrics (Optional)

By default, the script shows only overall metrics for improved performance and cleaner output. Use the `--team-metrics` flag to include detailed team breakdowns:

```bash
# Show team-specific metrics and comparisons
ruby kanban_metrics.rb --team-metrics

# Export team metrics as CSV
ruby kanban_metrics.rb --team-metrics --format csv
```

Team metrics include per-team cycle time, lead time, throughput, and a comparison table across all teams.

## 📦 Archived Tickets

By default, the Linear API excludes archived tickets from the results. Use the `--include-archived` flag to include archived tickets in your analysis:

```bash
# Default behavior - excludes archived tickets
ruby kanban_metrics.rb

# Include archived tickets in the analysis
ruby kanban_metrics.rb --include-archived

# Include archived tickets with specific date range
ruby kanban_metrics.rb --include-archived --start-date "2024-01-01" --end-date "2024-12-31"
```

**Note**: Including archived tickets may significantly increase the number of results and processing time, as archived tickets can accumulate over long periods.

**Cache Behavior**: Requests with and without archived tickets are cached separately, so you can switch between modes without cache conflicts.

## Smart Caching

The script includes intelligent caching to avoid unnecessary API calls and improve performance:

### How It Works
- **Automatic Caching**: API responses are cached in `.linear_cache/` directory
- **Cache Key**: Based on search criteria (team, dates, etc.)
- **Cache Expiry**: Cached data expires at the start of the next day
- **Cache Hit**: Shows "✅ Using cached data" when cache is used
- **Cache Miss**: Shows "🔄 Cache miss or expired" when fetching fresh data

### Usage Examples

```bash
# First run - fetches from API and caches the response
ruby kanban_metrics.rb --start-date "2025-01-01"

# Second run - uses cached data (much faster!)
ruby kanban_metrics.rb --start-date "2025-01-01"
# ✅ Using cached data (5015 issues)

# Force fresh data (bypass cache)
ruby kanban_metrics.rb --start-date "2025-01-01" --no-cache

# Different search criteria = different cache
ruby kanban_metrics.rb --start-date "2025-02-01"  # New API call
```

### Cache Debugging

```bash
# See cache operations in detail
DEBUG=true ruby kanban_metrics.rb
# ✅ Using cached data (513 issues)
# 💾 Saved 513 issues to cache
```

## 📈 Timeseries Analysis

The script now includes powerful timeseries analysis capabilities to track status changes over time:

### Usage Examples

```bash
# Include timeseries analysis in the report
ruby kanban_metrics.rb --timeseries

# View detailed timeline for a specific issue
ruby kanban_metrics.rb --timeline "ISSUE-123"

# Export timeseries data as JSON
ruby kanban_metrics.rb --timeseries --format json

# Export timeseries data as CSV
ruby kanban_metrics.rb --timeseries --format csv
```

### Timeseries Features

1. **Status Transitions**: Most common state changes across all tickets
2. **Average Time in Status**: How long tickets typically spend in each status
3. **Daily Activity**: Recent status change activity by date
4. **Individual Timelines**: Complete history for specific tickets

### Sample Output

The timeseries analysis provides:
- **Status Flow**: `created → In Progress (47 times)`, `To test → Done (38 times)`
- **Time Analysis**: `In Review: 5.65 days average`, `Todo: 1.54 days average`
- **Activity Tracking**: Daily breakdown of all status changes
- **Individual History**: Complete timeline for any ticket: `2025-06-19 15:08 | Backlog → In Progress`

This helps identify:
- 🔍 **Bottlenecks**: Statuses where work gets stuck longest
- 📊 **Flow Patterns**: Most common paths through your workflow  
- ⚡ **Process Issues**: Unusual transitions or delays
- 📈 **Trend Analysis**: How activity changes over time

## Requirements

- Ruby 3.0+
- Linear API access token
- Internet connection
