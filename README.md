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
./bin/kanban_metrics
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
- `--ticket-details` - Include individual ticket details in output (disabled by default, works with all formats)

### Examples

```bash
# Basic usage (overall metrics only)
./bin/kanban_metrics

# Fetch all issues with automatic pagination
./bin/kanban_metrics --page-size 500  # Larger pages for faster fetching

# Include team metrics breakdown
./bin/kanban_metrics --team-metrics

# Filter by team and date range with team metrics
./bin/kanban_metrics --team-id "TEAM123" --start-date "2024-01-01" --end-date "2024-12-31" --team-metrics

# Output as JSON
./bin/kanban_metrics --format json

# Output as CSV with team metrics
./bin/kanban_metrics --format csv --team-metrics

# Output with individual ticket details (available in all formats)
./bin/kanban_metrics --ticket-details                           # Table format with ticket details
./bin/kanban_metrics --format json --ticket-details             # JSON format with ticket details
./bin/kanban_metrics --format csv --ticket-details              # CSV format with ticket details

# Combine team metrics and ticket details
./bin/kanban_metrics --format csv --team-metrics --ticket-details

# Include archived tickets in the analysis
./bin/kanban_metrics --include-archived

# Include archived tickets with team metrics
./bin/kanban_metrics --include-archived --team-metrics

# Filter by date range and include archived tickets
./bin/kanban_metrics --start-date "2024-01-01" --end-date "2024-12-31" --include-archived
```

## Metrics Collected

- **Cycle Time**: Time from when work starts to when it's completed
- **Lead Time**: Time from when work is requested to when it's completed
- **Throughput**: Number of items completed per time period
- **Work in Progress (WIP)**: Number of items currently in progress
- **Flow Efficiency**: Percentage of time spent on active work vs waiting

## Automatic Pagination

The script now supports automatic pagination to fetch **all issues** from your Linear workspace, not just the first 250. The script will automatically fetch multiple pages until all issues matching your criteria are retrieved.

```bash
# Automatically fetches all issues (may be thousands!)
./bin/kanban_metrics

# The script will show pagination progress for large datasets
### 📄 Pagination Support

The script automatically fetches all issues from Linear using pagination. Linear's API has a maximum page size of 250 issues per request:

```bash
# Use default page size (250)
./bin/kanban_metrics

# Custom page size (automatically capped at 250)
./bin/kanban_metrics --page-size 100

# Attempting to use >250 will show a warning and use 250
./bin/kanban_metrics --page-size 1000
# ⚠️  Warning: Linear API maximum page size is 250. Using 250 instead of 1000.
```

With debug mode enabled, you can see the pagination in action:

```bash
DEBUG=true ./bin/kanban_metrics
# 📄 Fetching page 1...
# 📄 Fetching page 2...
# 📄 Fetching page 3...
# ✅ Successfully fetched 5015 total issues from Linear API
```

## 👥 Team Metrics (Optional)

By default, the script shows only overall metrics for improved performance and cleaner output. Use the `--team-metrics` flag to include detailed team breakdowns:

```bash
# Show team-specific metrics and comparisons
./bin/kanban_metrics --team-metrics

# Export team metrics as CSV
./bin/kanban_metrics --team-metrics --format csv
```

Team metrics include per-team cycle time, lead time, throughput, and a comparison table across all teams.

## 📦 Archived Tickets

By default, the Linear API excludes archived tickets from the results. Use the `--include-archived` flag to include archived tickets in your analysis:

```bash
# Default behavior - excludes archived tickets
./bin/kanban_metrics

# Include archived tickets in the analysis
./bin/kanban_metrics --include-archived

# Include archived tickets with specific date range
./bin/kanban_metrics --include-archived --start-date "2024-01-01" --end-date "2024-12-31"
```

**Note**: Including archived tickets may significantly increase the number of results and processing time, as archived tickets can accumulate over long periods.

**Cache Behavior**: Requests with and without archived tickets are cached separately, so you can switch between modes without cache conflicts.

## Smart Caching

The script includes intelligent caching to avoid unnecessary API calls and improve performance:

### How It Works
- **Automatic Caching**: API responses are cached in `tmp/.linear_cache` directory
- **Cache Key**: Based on search criteria (team, dates, etc.)
- **Cache Expiry**: Cached data expires at the start of the next day
- **Cache Hit**: Shows "✅ Using cached data" when cache is used
- **Cache Miss**: Shows "🔄 Cache miss or expired" when fetching fresh data

### Usage Examples

```bash
# First run - fetches from API and caches the response
./bin/kanban_metrics --start-date "2025-01-01"

# Second run - uses cached data (much faster!)
./bin/kanban_metrics --start-date "2025-01-01"
# ✅ Using cached data (5015 issues)

# Force fresh data (bypass cache)
./bin/kanban_metrics --start-date "2025-01-01" --no-cache

# Different search criteria = different cache
./bin/kanban_metrics --start-date "2025-02-01"  # New API call
```

### Cache Debugging

```bash
# See cache operations in detail
DEBUG=1 ./bin/kanban_metrics
📄 Fetching page 1...
🔍 GraphQL Query: issues(first: 250)
📄 Fetching page 2...
```

## 📈 Timeseries Analysis

The script now includes powerful timeseries analysis capabilities to track status changes over time:

### Usage Examples

```bash
# Include timeseries analysis in the report
./bin/kanban_metrics --timeseries

# View detailed timeline for a specific issue
./bin/kanban_metrics --timeline "ISSUE-123"

# Export timeseries data as JSON
./bin/kanban_metrics --timeseries --format json

# Export timeseries data as CSV
./bin/kanban_metrics --timeseries --format csv
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

## Export Features with Individual Ticket Details

The `--ticket-details` flag enables detailed export of individual ticket data in **all output formats** (table, JSON, CSV).

### Output Format Examples

**Table Format** (`--format table --ticket-details`):
```
🎫 INDIVIDUAL TICKET DETAILS
+----------+---------------------------+------+----------+----------+
| ID       | Title                     | State| Created  | Completed|
+----------+---------------------------+------+----------+----------+
| PROJ-123 | User authentication       | Done | 2024-06-01| 2024-06-08|
| PROJ-124 | Login bug fix             | Done | 2024-06-02| 2024-06-07|
+----------+---------------------------+------+----------+----------+
```

**JSON Format** (`--format json --ticket-details`):
```json
{
  "overall_metrics": { ... },
  "team_metrics": { ... },
  "individual_tickets": [
    {
      "identifier": "PROJ-123", 
      "title": "User authentication",
      "state": { "name": "Done" },
      "calculated_metrics": {
        "cycle_time_days": 6.25,
        "lead_time_days": 7.29
      }
    }
  ]
}
```

**CSV Format** (`--format csv --ticket-details`):
```csv
ID,Identifier,Title,State,Team,Assignee,Priority,Cycle Time (days),Lead Time (days)
abc123,PROJ-123,User authentication,Done,Backend Team,John Doe,1,6.25,7.29
def456,PROJ-124,Login bug fix,Done,Frontend Team,Jane Smith,0,1.1,1.9
```

### Key Features

**Individual ticket details include:**
- All Linear ticket fields (ID, identifier, title, state, team, assignee, priority, estimate)
- Timestamps (created, updated, started, completed, archived)
- **Calculated cycle time** (started → completed) 
- **Calculated lead time** (created → completed)
- Proper handling of incomplete tickets (empty time fields for in-progress/backlog items)

**Note**: Individual tickets are only included when using the `--ticket-details` flag. Without this flag, output contains only aggregated metrics.

Perfect for:
- 📊 **Data analysis** in Excel, Google Sheets, or BI tools
- 📈 **Trend analysis** across individual tickets over time
- 🔍 **Outlier detection** for tickets with unusual cycle/lead times
- 📋 **Detailed reporting** with ticket-level granularity

## Development

### Testing & Quality Assurance

This project maintains high code quality with comprehensive testing and automated checks:

- **546 RSpec tests** with **91.17% code coverage**
- **Zero RuboCop offenses** (style and quality checks)
- **Brakeman security analysis** (no vulnerabilities found)

```bash
# Run tests
bundle exec rspec

# Run tests with coverage
COVERAGE=true bundle exec rspec

# Run code style checks
bundle exec rubocop

# Run security analysis
bundle exec brakeman --force

# Run all checks locally (like CI)
./bin/ci-local

# Test GitHub Actions workflows locally
./bin/github-actions-test
```

### Continuous Integration & Pull Request Analysis

The project includes comprehensive CI/CD with both CircleCI and GitHub Actions:

#### GitHub Actions (Immediate PR Feedback)
- **🔍 Inline code review** with RuboCop violations in PR comments
- **⚡ Fast feedback** (< 2 minutes) on pull requests
- **🎯 Targeted testing** for changed files only
- **💬 Automated summaries** for security and quality issues
- **📊 Coverage impact** analysis

#### CircleCI (Comprehensive Pipeline)
- **Automated testing** on every commit
- **Code coverage reporting** with detailed HTML reports
- **Security scanning** with Brakeman (multiple formats)
- **Code quality checks** with RuboCop
- **Nightly comprehensive audits**

See [`.github/ACTIONS.md`](.github/ACTIONS.md) and [CIRCLECI.md](CIRCLECI.md) for detailed setup instructions.

See [CIRCLECI.md](CIRCLECI.md) for detailed setup instructions and configuration details.

### Contributing

1. Fork the repository
2. Create a feature branch
3. Run tests locally: `./bin/ci-local`
4. Commit your changes
5. Push and create a pull request

All pull requests must pass the CI pipeline before merging.
