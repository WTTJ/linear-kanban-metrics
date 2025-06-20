# Kanban Metrics Script - Technical Documentation

This document provides a comprehensive technical overview of the refactored kanban metrics script, explaining the modular architecture, Zeitwerk autoloading, and each class, method, and design pattern used.

## Table of Contents

1. [Project Structure](#project-structure)
2. [Zeitwerk Autoloading](#zeitwerk-autoloading)
3. [Architecture Overview](#architecture-overview)
4. [Core Value Objects](#core-value-objects)
5. [API Client Layer](#api-client-layer)
6. [Metrics Calculation Layer](#metrics-calculation-layer)
7. [Timeseries Analysis Layer](#timeseries-analysis-layer)
8. [Output Formatting Layer](#output-formatting-layer)
9. [Reports Layer](#reports-layer)
10. [Application Control Layer](#application-control-layer)
11. [Design Patterns Used](#design-patterns-used)
12. [SOLID Principles Applied](#solid-principles-applied)

## Project Structure

The project follows a professional Ruby gem structure with Zeitwerk autoloading:

```
kanban-script/
├── bin/
│   └── kanban_metrics                    # Executable script
├── lib/
│   ├── kanban_metrics.rb                # Main entry point with Zeitwerk setup
│   └── kanban_metrics/
│       ├── version.rb                   # Version constant
│       ├── application_runner.rb        # Application entry point
│       ├── options_parser.rb            # CLI option parsing
│       ├── query_options.rb            # Query configuration value object
│       ├── calculators/                # Metrics calculation classes
│       │   ├── flow_efficiency_calculator.rb
│       │   ├── issue_partitioner.rb
│       │   ├── kanban_metrics_calculator.rb
│       │   ├── throughput_calculator.rb
│       │   └── time_metrics_calculator.rb
│       ├── formatters/                 # Output formatting classes
│       │   ├── csv_formatter.rb
│       │   ├── json_formatter.rb
│       │   ├── table_formatter.rb
│       │   └── timeseries_table_formatter.rb
│       ├── linear/                     # Linear API client classes
│       │   ├── api_paginator.rb
│       │   ├── api_response_parser.rb
│       │   ├── cache.rb
│       │   ├── client.rb
│       │   ├── http_client.rb
│       │   └── query_builder.rb
│       ├── reports/                    # Report generation classes
│       │   ├── kanban_report.rb
│       │   └── timeline_display.rb
│       ├── timeseries/                 # Time series analysis classes
│       │   ├── ticket_timeseries.rb
│       │   └── timeline_builder.rb
│       └── utils/                      # Utility classes (currently empty)
├── config/
│   └── .env.example                    # Environment variables template
├── tmp/
│   └── .linear_cache/                  # API response cache directory
├── Gemfile                             # Ruby dependencies
├── README.md                           # User documentation
└── TECHNICAL_DOCUMENTATION.md          # This file
```

## Zeitwerk Autoloading

The project uses Zeitwerk for modern Ruby autoloading, eliminating manual `require_relative` statements:

### Configuration (`lib/kanban_metrics.rb`)
```ruby
require 'zeitwerk'

# Set up Zeitwerk autoloader
loader = Zeitwerk::Loader.for_gem
loader.logger = Logger.new($stdout) if ENV['ZEITWERK_DEBUG']
loader.setup

module KanbanMetrics
  class Error < StandardError; end
  class ApiError < Error; end
  class CacheError < Error; end
end
```

### Benefits
- **Lazy Loading**: Classes are only loaded when first referenced
- **Convention-based**: File names automatically map to class names
- **Maintainable**: No manual require statements to maintain
- **Performance**: Faster startup time and reduced memory footprint
- **Debug Support**: Set `ZEITWERK_DEBUG=1` to see loading activity

### Naming Conventions
- `api_paginator.rb` → `KanbanMetrics::Linear::ApiPaginator`
- `kanban_metrics_calculator.rb` → `KanbanMetrics::Calculators::KanbanMetricsCalculator`
- `table_formatter.rb` → `KanbanMetrics::Formatters::TableFormatter`

## Architecture Overview

The script follows a layered architecture with clear separation of concerns, organized into Zeitwerk-autoloaded modules:

```
┌─────────────────────────────────────────────────┐
│           Application Control Layer             │
│  ApplicationRunner, OptionsParser               │
│  (KanbanMetrics::ApplicationRunner)             │
├─────────────────────────────────────────────────┤
│             Reports Layer                       │
│  KanbanReport, TimelineDisplay                  │
│  (KanbanMetrics::Reports::*)                    │
├─────────────────────────────────────────────────┤
│             Output Formatting Layer             │
│  TableFormatter, JsonFormatter, CsvFormatter    │
│  (KanbanMetrics::Formatters::*)                 │
├─────────────────────────────────────────────────┤
│           Metrics Calculation Layer             │
│  KanbanMetricsCalculator, TimeMetrics, etc.    │
│  (KanbanMetrics::Calculators::*)                │
├─────────────────────────────────────────────────┤
│           Timeseries Analysis Layer             │
│  TicketTimeseries, TimelineBuilder              │
│  (KanbanMetrics::Timeseries::*)                 │
├─────────────────────────────────────────────────┤
│              API Client Layer                   │
│  LinearClient, LinearHttpClient, etc.           │
│  (KanbanMetrics::Linear::*)                     │
├─────────────────────────────────────────────────┤
│             Core Value Objects                  │
│  QueryOptions                                   │
│  (KanbanMetrics::QueryOptions)                  │
└─────────────────────────────────────────────────┘
```

### Module Organization

- **`KanbanMetrics`**: Root module containing core value objects and application runner
- **`KanbanMetrics::Linear`**: Linear API client classes and utilities
- **`KanbanMetrics::Calculators`**: Metrics calculation and business logic
- **`KanbanMetrics::Timeseries`**: Time series analysis and timeline building
- **`KanbanMetrics::Formatters`**: Output formatting strategies
- **`KanbanMetrics::Reports`**: High-level report generation and display

## Core Value Objects

### QueryOptions (`KanbanMetrics::QueryOptions`)

**Purpose**: Encapsulates and validates API query parameters  
**Pattern**: Value Object  
**Location**: `lib/kanban_metrics/query_options.rb`

```ruby
module KanbanMetrics
  class QueryOptions
```

#### Constructor
- **`initialize(options = {})`**: Creates a QueryOptions instance with normalized parameters
  - Validates and normalizes `page_size` (max 250)
  - Sets default values from environment or parameters
  - Handles `include_archived` flag for archived ticket support

#### Public Methods
- **`cache_key_data`**: Returns hash of data used for cache key generation
  - Only includes parameters that affect API results
  - Excludes output formatting options
  - Includes `include_archived` flag to ensure proper cache separation

#### Private Methods
- **`normalize_page_size(size)`**: Ensures page size doesn't exceed Linear API limit of 250

**Design Rationale**: Prevents invalid parameters from propagating through the system and provides a clean interface for query configuration. The inclusion of `include_archived` ensures cached results are properly segregated.

---

## API Client Layer (`KanbanMetrics::Linear`)

The Linear API client layer is organized under the `KanbanMetrics::Linear` module, with each class having a specific responsibility in the API communication chain.

### LinearHttpClient (`KanbanMetrics::Linear::HttpClient`)

**Purpose**: Handles raw HTTP communication with Linear API  
**Pattern**: Adapter Pattern  
**Location**: `lib/kanban_metrics/linear/http_client.rb`

```ruby
module KanbanMetrics
  module Linear
    class HttpClient
```

#### Constructor
- **`initialize(api_token)`**: Sets up HTTP client with authentication
  - Configures headers for GraphQL API
  - Sets up connection parameters

#### Public Methods
- **`post(query, variables = {})`**: Executes GraphQL query
  - Handles request/response cycle
  - Raises `KanbanMetrics::ApiError` on failures
  - Returns parsed JSON response

#### Private Methods
- **`build_request_body(query, variables)`**: Constructs GraphQL request payload
- **`handle_response(response)`**: Processes HTTP response and handles errors

**Design Rationale**: Isolates HTTP concerns and provides a clean interface for GraphQL communication.

---

### LinearQueryBuilder (`KanbanMetrics::Linear::QueryBuilder`)

**Purpose**: Constructs GraphQL queries for Linear API  
**Pattern**: Builder Pattern  
**Location**: `lib/kanban_metrics/linear/query_builder.rb`

```ruby
module KanbanMetrics
  module Linear
    class QueryBuilder
```

#### Constructor
- **`initialize(options)`**: Sets up query builder with configuration options

#### Public Methods
- **`build_issues_query`**: Constructs paginated issues query
  - Includes filters for team, date range, archived status
  - Handles pagination parameters
  - Returns complete GraphQL query string

#### Private Methods
- **`build_filter_conditions`**: Creates filter clause based on options
- **`build_field_selection`**: Selects required fields from API
- **`format_date_filter(start_date, end_date)`**: Formats date range filters

**Design Rationale**: Encapsulates complex GraphQL query construction logic and makes it easy to modify queries without affecting other components.

---

### LinearCache (`KanbanMetrics::Linear::Cache`)

**Purpose**: Manages API response caching with intelligent cache keys  
**Pattern**: Repository Pattern  
**Location**: `lib/kanban_metrics/linear/cache.rb`

```ruby
module KanbanMetrics
  module Linear
    class Cache
```

#### Constructor
- **`initialize(cache_dir = 'tmp/.linear_cache')`**: Sets up cache directory

#### Public Methods
- **`get(cache_key)`**: Retrieves cached response if valid
  - Checks file existence and TTL (24 hours)
  - Returns parsed JSON or nil if cache miss/expired

- **`set(cache_key, data)`**: Stores API response with metadata
  - Creates cache directory if needed
  - Stores data with timestamp for TTL checking

- **`generate_cache_key(query_options)`**: Creates deterministic cache key
  - Uses query parameters that affect API results
  - Includes `include_archived` flag for proper cache separation
  - Excludes formatting options that don't affect API data

#### Private Methods
- **`cache_valid?(file_path)`**: Checks if cached file is within TTL
- **`ensure_cache_directory`**: Creates cache directory structure

**Design Rationale**: Reduces API calls while ensuring data freshness. The cache key includes all parameters that affect API results, ensuring proper cache invalidation.

---

### ApiResponseParser (`KanbanMetrics::Linear::ApiResponseParser`)

**Purpose**: Parses and validates Linear API responses  
**Pattern**: Adapter Pattern  
**Location**: `lib/kanban_metrics/linear/api_response_parser.rb`

```ruby
module KanbanMetrics
  module Linear
    class ApiResponseParser
```

#### Class Methods
- **`parse_issues_response(response)`**: Extracts issues and pagination info
  - Validates response structure
  - Handles API errors gracefully
  - Returns normalized data structure

- **`extract_page_info(response)`**: Extracts pagination metadata
  - Gets cursor information for next page
  - Determines if more pages available

#### Private Class Methods
- **`validate_response(response)`**: Ensures response contains expected fields
- **`handle_api_errors(response)`**: Processes GraphQL errors from API

**Design Rationale**: Centralizes response parsing logic and provides error handling for malformed API responses.

---

### ApiPaginator (`KanbanMetrics::Linear::ApiPaginator`)

**Purpose**: Handles automatic pagination through Linear API results  
**Pattern**: Iterator Pattern  
**Location**: `lib/kanban_metrics/linear/api_paginator.rb`

```ruby
module KanbanMetrics
  module Linear
    class ApiPaginator
```

#### Constructor
- **`initialize(http_client, query_builder)`**: Sets up pagination with dependencies

#### Public Methods
- **`fetch_all_issues(options)`**: Fetches all issues across multiple pages
  - Handles pagination automatically
  - Aggregates results from all pages
  - Implements safety limits to prevent runaway requests

#### Private Methods
- **`fetch_page(query, variables)`**: Fetches a single page of results
- **`should_continue_pagination?(page_info, current_page)`**: Determines if more pages needed
- **`update_pagination_variables(variables, page_info)`**: Updates cursor for next page

**Design Rationale**: Encapsulates pagination complexity and provides a simple interface for fetching all results.

---

### LinearClient (`KanbanMetrics::Linear::Client`)

**Purpose**: Main facade for Linear API operations  
**Pattern**: Facade Pattern  
**Location**: `lib/kanban_metrics/linear/client.rb`

```ruby
module KanbanMetrics
  module Linear
    class Client
```

#### Constructor
- **`initialize(api_token, options = {})`**: Sets up complete Linear API client
  - Initializes all component dependencies
  - Configures caching behavior

#### Public Methods
- **`fetch_issues(query_options)`**: High-level method to fetch issues
  - Checks cache first if caching enabled
  - Delegates to paginator for fresh data
  - Stores results in cache for future use

#### Private Methods
- **`build_cache_key(query_options)`**: Creates cache key for the request
- **`fetch_fresh_data(query_options)`**: Fetches data from API (bypassing cache)

**Design Rationale**: Provides a simple, high-level interface that coordinates all Linear API operations while hiding implementation complexity.
**Pattern**: Adapter Pattern
**Single Responsibility**: HTTP request/response handling

```ruby
class LinearHttpClient
```

#### Constructor
- **`initialize(api_token)`**: Sets up HTTP client with authentication token

#### Public Methods
- **`post(query, variables = {})`**: Modern GraphQL query method with error handling
  - Returns parsed JSON response data
  - Handles network errors, HTTP errors, and GraphQL errors
  - Supports query variables
- **`post_graphql(query, variables = {})`**: Legacy compatibility method
  - Delegates to `post()` method for backward compatibility
  - Maintained for existing application code

#### Private Methods
- **`create_http_client`**: Creates configured Net::HTTP instance
- **`create_post_request(query)`**: Builds HTTP POST request with proper headers

**Design Rationale**: Isolates HTTP concerns from business logic, making it easy to test and modify network behavior.

---

### LinearQueryBuilder

**Purpose**: Constructs GraphQL queries for Linear API
**Pattern**: Builder Pattern
**Single Responsibility**: Query string construction

```ruby
class LinearQueryBuilder
```

#### Public Methods
- **`build_issues_query(options, after_cursor = nil)`**: Creates complete GraphQL query
  - Combines filters, pagination, and field selection
  - Returns ready-to-send GraphQL string

#### Private Methods
- **`build_filters(options)`**: Constructs filter clauses
  - Team filtering: `team: { id: { eq: "TEAM123" } }`
  - Date filtering: `updatedAt: { gte: "...", lte: "..." }`
- **`build_pagination(options, after_cursor)`**: Constructs pagination arguments
- **`team_filter(team_id)`**: Creates team-specific filter
- **`date_filter(start_date, end_date)`**: Creates date range filter
- **`date_filters_needed?(options)`**: Determines if date filtering is required
- **`log_query(filters, pagination)`**: Debug logging for query construction

**Design Rationale**: Separates query construction logic, making it easy to modify GraphQL schema changes without affecting other components.

---

### LinearCache

**Purpose**: Manages file-based caching of API responses
**Pattern**: Repository Pattern
**Single Responsibility**: Cache storage and retrieval

```ruby
class LinearCache
```

#### Constructor
- **`initialize`**: Sets up cache directory structure

#### Public Methods
- **`fetch_cached_issues(cache_key)`**: Retrieves issues from cache if valid
  - Checks file existence and expiry
  - Returns nil if cache miss or expired
- **`save_issues_to_cache(cache_key, issues)`**: Persists issues to cache file
- **`generate_cache_key(options)`**: Creates MD5 hash from query options

#### Private Methods
- **`setup_cache_directory`**: Creates `.linear_cache/` directory if needed
- **`cached_data_exists?(cache_key)`**: Checks if cache file exists
- **`cache_file_path(cache_key)`**: Constructs full path to cache file
- **`read_from_cache(cache_key)`**: Reads and parses cache file
- **`save_to_cache(cache_key, issues)`**: Writes data to cache file
- **`cache_expired?(timestamp)`**: Checks if cache has expired (daily TTL)
- **`log_cache_hit/save/error`**: Various logging methods for cache operations

**Design Rationale**: Encapsulates all caching logic, making it easy to change cache strategies (file → Redis, etc.) without affecting other components.

---

### ApiPaginator

**Purpose**: Handles paginated API requests
**Pattern**: Iterator Pattern
**Single Responsibility**: Pagination logic

```ruby
class ApiPaginator
```

#### Constructor
- **`initialize(http_client, query_builder)`**: Dependency injection of required services

#### Public Methods
- **`fetch_all_pages(options)`**: Orchestrates multi-page data fetching
  - Continues until all pages retrieved or safety limit reached
  - Returns combined results from all pages

#### Private Methods
- **`fetch_single_page(options, after_cursor)`**: Retrieves one page of data
- **`log_page_fetch(page, total_issues)`**: Debug logging for pagination progress

**Design Rationale**: Isolates pagination complexity, allowing other components to work with complete datasets without pagination concerns.

---

### ApiResponseParser

**Purpose**: Parses and validates API responses
**Pattern**: Parser/Validator Pattern
**Single Responsibility**: Response parsing and error handling

```ruby
class ApiResponseParser
```

#### Constructor
- **`initialize(response)`**: Takes raw HTTP response

#### Public Methods
- **`parse`**: Main parsing method that handles all response scenarios
  - Validates HTTP status
  - Parses JSON
  - Checks for GraphQL errors
  - Extracts issues data

#### Private Methods
- **`response_successful?`**: Validates HTTP 200 status
- **`parse_json_response`**: Safely parses JSON with error handling
- **`graphql_errors_present?(data)`**: Checks for GraphQL-level errors
- **`extract_issues_data(data)`**: Extracts issues and pagination info
- **`normalize_page_info(page_info)`**: Standardizes pagination metadata
- **`log_http_error/json_error/graphql_errors`**: Error logging methods

**Design Rationale**: Centralizes all response parsing logic, making error handling consistent and comprehensive.

---

### LinearClient

**Purpose**: Orchestrates API operations with caching
**Pattern**: Facade Pattern
**Single Responsibility**: High-level API coordination

```ruby
class LinearClient
```

#### Constructor
- **`initialize(api_token)`**: Sets up all required service dependencies
  - Creates HTTP client, query builder, cache, etc.

#### Public Methods
- **`fetch_issues(options_hash = {})`**: Main entry point for issue fetching
  - Handles caching logic
  - Delegates to appropriate fetch strategy

#### Private Methods
- **`fetch_with_caching(options)`**: Attempts cache first, then API
- **`fetch_from_api(options)`**: Always fetches fresh data from API
- **`paginated_fetch(options)`**: Delegates to paginator for multi-page requests
- **`log_cache_miss/api_fetch_start/api_fetch_complete`**: Various logging methods

**Design Rationale**: Provides a simple interface for complex API operations while hiding implementation details.

---

## Metrics Calculation Layer (`KanbanMetrics::Calculators`)

The metrics calculation layer contains specialized calculators organized under the `KanbanMetrics::Calculators` module, each responsible for specific types of kanban metrics.

### IssuePartitioner (`KanbanMetrics::Calculators::IssuePartitioner`)

**Purpose**: Groups issues by status type for analysis  
**Pattern**: Strategy Pattern  
**Location**: `lib/kanban_metrics/calculators/issue_partitioner.rb`

```ruby
module KanbanMetrics
  module Calculators
    class IssuePartitioner
```

#### Class Methods
- **`partition(issues)`**: Main partitioning method
  - Returns [completed, in_progress, backlog] arrays
  - Uses private helper methods for classification
  - Handles archived issues when included

#### Private Class Methods
- **`completed_status?(issue)`**: Identifies completed issues
- **`in_progress_status?(issue)`**: Identifies in-progress issues  
- **`backlog_status?(issue)`**: Identifies backlog issues

**Design Rationale**: Encapsulates status classification logic, making it easy to modify status definitions without affecting calculations.

---

### TimeMetricsCalculator (`KanbanMetrics::Calculators::TimeMetricsCalculator`)

**Purpose**: Calculates time-based metrics (cycle time, lead time)  
**Pattern**: Calculator Pattern  
**Location**: `lib/kanban_metrics/calculators/time_metrics_calculator.rb`

```ruby
module KanbanMetrics
  module Calculators
    class TimeMetricsCalculator
```

#### Constructor
- **`initialize(issues)`**: Takes array of issues to analyze

#### Public Methods
- **`cycle_time_stats`**: Returns cycle time statistics (avg, median, p95)
- **`lead_time_stats`**: Returns lead time statistics (avg, median, p95)

#### Private Methods
- **`calculate_cycle_times`**: Computes cycle time for each issue
  - Uses `startedAt` or history to find start time
  - Calculates duration to `completedAt`
- **`calculate_lead_times`**: Computes lead time for each issue
  - Uses `createdAt` to `completedAt` duration
- **`find_start_time(issue)`**: Finds when work actually started
- **`find_history_time(issue, state_type)`**: Searches history for state transitions
- **`calculate_time_difference(start_time, end_time)`**: DateTime math
- **`build_time_stats(times)`**: Creates statistics hash from time array
- **`calculate_average/median/percentile`**: Statistical calculation methods

**Design Rationale**: Separates time calculations from other metrics, allowing for easy modification of time calculation algorithms.

---

### ThroughputCalculator (`KanbanMetrics::Calculators::ThroughputCalculator`)

**Purpose**: Calculates throughput metrics and velocity  
**Pattern**: Calculator Pattern  
**Location**: `lib/kanban_metrics/calculators/throughput_calculator.rb`

```ruby
module KanbanMetrics
  module Calculators
    class ThroughputCalculator
```

#### Constructor
- **`initialize(completed_issues, date_range)`**: Takes completed issues and analysis period

#### Public Methods
- **`weekly_throughput`**: Calculates issues completed per week
- **`daily_throughput`**: Calculates issues completed per day
- **`velocity_trend`**: Analyzes throughput trend over time

**Design Rationale**: Isolates throughput calculations and provides multiple time-based perspectives on team velocity.

---

### FlowEfficiencyCalculator (`KanbanMetrics::Calculators::FlowEfficiencyCalculator`)

**Purpose**: Calculates flow efficiency and waste metrics  
**Pattern**: Calculator Pattern  
**Location**: `lib/kanban_metrics/calculators/flow_efficiency_calculator.rb`

```ruby
module KanbanMetrics
  module Calculators
    class FlowEfficiencyCalculator
```

#### Constructor
- **`initialize(issues)`**: Takes array of issues for analysis

#### Public Methods
- **`calculate_flow_efficiency`**: Calculates ratio of active work time to total time
- **`identify_bottlenecks`**: Identifies states where issues spend most time
- **`waiting_time_analysis`**: Analyzes time spent in non-active states

**Design Rationale**: Provides insights into process efficiency and identifies areas for improvement.

---

### KanbanMetricsCalculator (`KanbanMetrics::Calculators::KanbanMetricsCalculator`)

**Purpose**: Main orchestrator for all metrics calculations  
**Pattern**: Facade Pattern  
**Location**: `lib/kanban_metrics/calculators/kanban_metrics_calculator.rb`

```ruby
module KanbanMetrics
  module Calculators
    class KanbanMetricsCalculator
```

#### Constructor
- **`initialize(issues, options = {})`**: Sets up calculator with issues and configuration

#### Public Methods
- **`calculate_all_metrics`**: Orchestrates all metric calculations
  - Partitions issues by status
  - Calculates time-based metrics
  - Calculates throughput metrics
  - Calculates flow efficiency
  - Returns comprehensive metrics hash

- **`calculate_team_metrics`**: Calculates metrics broken down by team
  - Groups issues by team
  - Calculates metrics for each team separately
  - Returns team-based metrics breakdown

#### Private Methods
- **`partition_issues`**: Delegates to IssuePartitioner
- **`calculate_basic_metrics`**: Calculates counts and percentages
- **`calculate_time_metrics`**: Delegates to TimeMetricsCalculator
- **`calculate_throughput_metrics`**: Delegates to ThroughputCalculator
- **`calculate_flow_metrics`**: Delegates to FlowEfficiencyCalculator

**Design Rationale**: Provides a single interface for all metrics while delegating to specialized calculators, following the Single Responsibility Principle.

### ThroughputCalculator

**Purpose**: Calculates throughput metrics
**Pattern**: Calculator Pattern
**Single Responsibility**: Throughput analysis

```ruby
class ThroughputCalculator
```

#### Constructor
- **`initialize(completed_issues)`**: Takes only completed issues

#### Public Methods
- **`stats`**: Returns throughput statistics
  - `weekly_avg`: Average items completed per week
  - `total_completed`: Total completed items

#### Private Methods
- **`default_stats`**: Returns zero stats for empty datasets
- **`calculate_weekly_counts`**: Groups completions by week
- **`group_by_week`**: Uses completion date to group issues
- **`calculate_average(arr)`**: Computes average with proper rounding

**Design Rationale**: Isolates throughput logic, making it easy to add other time-period calculations (daily, monthly).

---

### FlowEfficiencyCalculator

**Purpose**: Calculates flow efficiency metrics
**Pattern**: Calculator Pattern  
**Single Responsibility**: Flow efficiency analysis

```ruby
class FlowEfficiencyCalculator
```

#### Constructor
- **`initialize(issues)`**: Takes issues with history data

#### Public Methods
- **`calculate`**: Returns overall flow efficiency percentage
  - Analyzes time spent in active vs waiting states
  - Returns percentage (0-100)

#### Private Methods
- **`calculate_issue_efficiency(issue)`**: Efficiency for single issue
- **`calculate_times(history)`**: Analyzes state transition history
- **`calculate_duration(from_event, to_event)`**: Time between events
- **`active_state?(event)`**: Determines if state represents active work

**Design Rationale**: Encapsulates complex flow efficiency calculations, making the algorithm easy to modify or replace.

---

### KanbanMetricsCalculator

**Purpose**: Orchestrates all metric calculations
**Pattern**: Facade Pattern
**Single Responsibility**: Metrics coordination

```ruby
class KanbanMetricsCalculator
```

#### Constructor
- **`initialize(issues)`**: Takes complete issue dataset

#### Public Methods
- **`overall_metrics`**: Calculates metrics for entire dataset
  - Uses all specialized calculators
  - Returns comprehensive metrics hash
- **`team_metrics`**: Calculates metrics grouped by team
  - Groups issues by team name
  - Applies same calculations to team subset

#### Private Methods
- **`group_issues_by_team`**: Creates team-based issue groups
- **`calculate_team_stats(team_issues)`**: Applies calculations to team subset

**Design Rationale**: Provides simple interface for complex calculations while coordinating multiple specialized calculators.

---

## Timeseries Analysis Layer (`KanbanMetrics::Timeseries`)

The timeseries analysis layer provides chronological analysis of issue workflows, organized under the `KanbanMetrics::Timeseries` module.

### TimelineBuilder (`KanbanMetrics::Timeseries::TimelineBuilder`)

**Purpose**: Constructs chronological event timelines for issues  
**Pattern**: Builder Pattern  
**Location**: `lib/kanban_metrics/timeseries/timeline_builder.rb`

```ruby
module KanbanMetrics
  module Timeseries
    class TimelineBuilder
```

#### Public Methods
- **`build_timeline(issue)`**: Creates chronological event list
  - Combines creation and history events
  - Sorts by date
  - Returns structured timeline array
  - Handles both active and archived issues

#### Private Methods
- **`create_creation_event(issue)`**: Builds issue creation event
- **`extract_history_events(issue)`**: Processes history nodes into events
  - Filters for valid state transitions
  - Structures event data consistently
  - Preserves historical context for archived issues

**Design Rationale**: Separates timeline construction from analysis, making it reusable for different timeseries features and supporting both active and archived ticket analysis.

---

### TicketTimeseries (`KanbanMetrics::Timeseries::TicketTimeseries`)

**Purpose**: Main timeseries analysis and data generation  
**Pattern**: Analyzer Pattern  
**Location**: `lib/kanban_metrics/timeseries/ticket_timeseries.rb`

```ruby
module KanbanMetrics
  module Timeseries
    class TicketTimeseries
```

#### Constructor
- **`initialize(issues)`**: Takes issues and creates timeline builder

#### Public Methods
- **`generate_timeseries`**: Creates complete timeseries dataset
  - Includes issue metadata and full timelines
  - Used for detailed analysis and export
  - Supports filtering and grouping options

- **`status_flow_analysis`**: Identifies most common state transitions
  - Analyzes workflow patterns
  - Identifies bottlenecks and inefficiencies

- **`average_time_in_status`**: Calculates average duration per status
  - Provides insights into process timing
  - Helps identify slow stages in workflow

- **`daily_status_counts`**: Groups status changes by date
  - Shows workflow activity over time
  - Useful for identifying patterns and trends

#### Private Methods
- **`collect_transitions`**: Gathers all state transitions across issues
- **`collect_status_durations`**: Measures time spent in each status
- **`collect_all_events`**: Flattens all events across all issues
- **`group_events_by_date`**: Organizes events chronologically
- **`count_by_status`**: Counts events by status type
- **`calculate_days_between`**: Date arithmetic for duration calculations
- **`calculate_average`**: Statistical calculation utilities

**Design Rationale**: Provides comprehensive timeseries analysis capabilities while maintaining clean separation between data collection, analysis, and presentation concerns.

---

## Output Formatting Layer (`KanbanMetrics::Formatters`)

The output formatting layer provides multiple output formats for metrics data, organized under the `KanbanMetrics::Formatters` module using the Strategy pattern.

### TableFormatter (`KanbanMetrics::Formatters::TableFormatter`)

**Purpose**: Formats metrics data as terminal tables  
**Pattern**: Formatter Pattern (Strategy)  
**Location**: `lib/kanban_metrics/formatters/table_formatter.rb`

```ruby
module KanbanMetrics
  module Formatters
    class TableFormatter
```

#### Constructor
- **`initialize(metrics, team_metrics = nil)`**: Takes calculated metrics and optional team data

#### Public Methods
- **`print_summary`**: Displays main metrics summary table
- **`print_cycle_time`**: Shows cycle time statistics table
- **`print_lead_time`**: Shows lead time statistics table
- **`print_throughput`**: Displays throughput metrics table
- **`print_team_metrics`**: Handles team-specific breakdown tables
- **`print_kpi_definitions`**: Shows metric definitions and explanations

#### Private Methods
- **`build_*_table`**: Table construction methods for different metric types
- **`team_metrics_available?`**: Validates team data existence
- **`print_individual_teams`**: Formats individual team metrics
- **`print_team_comparison`**: Creates team comparison table

**Design Rationale**: Separates table formatting from calculations, making it easy to modify output appearance while maintaining consistent table structures.

---

### CsvFormatter (`KanbanMetrics::Formatters::CsvFormatter`)

**Purpose**: Formats metrics data as CSV for data analysis  
**Pattern**: Formatter Pattern (Strategy)  
**Location**: `lib/kanban_metrics/formatters/csv_formatter.rb`

```ruby
module KanbanMetrics
  module Formatters
    class CsvFormatter
```

#### Constructor
- **`initialize(metrics, team_metrics = nil, timeseries = nil)`**: Takes all available data types

#### Public Methods
- **`generate`**: Creates complete CSV output string
  - Includes overall metrics
  - Adds team breakdown if available
  - Includes timeseries data if available

#### Private Methods
- **`add_overall_metrics(csv)`**: Adds main metrics to CSV
- **`add_team_metrics(csv)`**: Adds team breakdown section
- **`add_timeseries_data(csv)`**: Adds timeseries analysis section
- **`add_status_transitions(csv)`**: Adds state transition data
- **`add_time_in_status(csv)`**: Adds time-in-status analysis

**Design Rationale**: Encapsulates CSV-specific formatting logic, making it easy to modify CSV structure while ensuring data integrity for analysis tools.

---

### JsonFormatter (`KanbanMetrics::Formatters::JsonFormatter`)

**Purpose**: Formats metrics data as JSON for API consumption  
**Pattern**: Formatter Pattern (Strategy)  
**Location**: `lib/kanban_metrics/formatters/json_formatter.rb`

```ruby
module KanbanMetrics
  module Formatters
    class JsonFormatter
```

#### Constructor
- **`initialize(metrics, team_metrics = nil, timeseries = nil)`**: Takes all available data types

#### Public Methods
- **`generate`**: Creates formatted JSON string
  - Structures all metrics in a hierarchical JSON format
  - Includes metadata about the analysis
  - Maintains type information for numeric values

#### Private Methods
- **`build_timeseries_data`**: Structures timeseries data for JSON export
- **`sanitize_numeric_values`**: Ensures proper numeric formatting

**Design Rationale**: Provides clean JSON interface for API consumption, data integration, and programmatic access to metrics.

---

### TimeseriesTableFormatter (`KanbanMetrics::Formatters::TimeseriesTableFormatter`)

**Purpose**: Formats timeseries analysis as readable tables  
**Pattern**: Formatter Pattern (Strategy)  
**Location**: `lib/kanban_metrics/formatters/timeseries_table_formatter.rb`

```ruby
module KanbanMetrics
  module Formatters
    class TimeseriesTableFormatter
```

#### Constructor
- **`initialize(timeseries)`**: Takes timeseries analyzer instance

#### Public Methods
- **`print_timeseries`**: Coordinates all timeseries table output
  - Prints status flow analysis
  - Shows average time in status
  - Displays daily activity patterns

#### Private Methods
- **`print_status_flow_analysis`**: Shows most common state transitions
- **`print_time_in_status`**: Displays time spent in each status
- **`print_daily_activity`**: Shows daily workflow patterns
- **`build_flow_table`**: Constructs state transition table
- **`build_status_time_table`**: Creates time-in-status table

**Design Rationale**: Specializes in timeseries data presentation, providing insights into workflow patterns and temporal analysis in an easily readable format.
- **`print_status_transitions/time_in_status/recent_activity`**: Section printers
- **`build_*_table`**: Table construction for each timeseries section

**Design Rationale**: Separates complex timeseries formatting from main table formatter, maintaining single responsibility.

---

### KanbanReport

**Purpose**: Orchestrates all output formatting
**Pattern**: Strategy Pattern + Facade Pattern
**Single Responsibility**: Output coordination

```ruby
class KanbanReport
```

#### Constructor
- **`initialize(metrics, team_metrics, timeseries = nil)`**: Takes all calculated data

#### Public Methods
- **`display(format = 'table')`**: Main output method
  - Routes to appropriate formatter based on format parameter

#### Private Methods
- **`display_json/csv/table`**: Format-specific display methods
- **`print_header`**: Common header for table output
- **`print_timeseries_tables`**: Delegates timeseries formatting

**Design Rationale**: Provides unified interface for multiple output formats while delegating to specialized formatters.

---

## Application Control Layer

### OptionsParser

**Purpose**: Handles command-line argument parsing
**Pattern**: Parser Pattern
**Single Responsibility**: CLI option processing

```ruby
class OptionsParser
```

#### Class Methods
- **`parse(args)`**: Main parsing method
  - Processes ARGV into options hash
  - Validates and sets defaults

#### Private Class Methods
- **`add_filter_options`**: Team and date filtering options
- **`add_output_options`**: Format and pagination options  
- **`add_feature_options`**: Caching, metrics, timeseries toggles
- **`add_help_option`**: Help text display
- **`validate_and_set_defaults`**: Post-processing validation
- **`set_environment_defaults`**: Environment variable integration
- **`validate_page_size`**: Page size bounds checking

**Design Rationale**: Centralizes all CLI parsing logic, making it easy to add new options without affecting other components.

---

### TimelineDisplay

**Purpose**: Handles individual issue timeline display
**Pattern**: Display Pattern
**Single Responsibility**: Timeline visualization

```ruby
class TimelineDisplay
```

#### Constructor
- **`initialize(issues)`**: Takes issue dataset

#### Public Methods
- **`show_timeline(issue_id)`**: Displays timeline for specific issue
  - Finds issue by ID
  - Formats and prints chronological events

#### Private Methods
- **`find_timeline_data(issue_id)`**: Locates specific issue timeline
- **`print_timeline(timeline_data)`**: Formats timeline for display

**Design Rationale**: Separates timeline display from main metrics output, allowing for specialized formatting.

---

### KanbanMetricsApp

**Purpose**: Main application logic coordinator
**Pattern**: Application Service Pattern
**Single Responsibility**: Application flow control

```ruby
class KanbanMetricsApp
## Application Control Layer (`KanbanMetrics`)

The application control layer manages application startup, configuration, and high-level workflow coordination.

### ApplicationRunner (`KanbanMetrics::ApplicationRunner`)

**Purpose**: Application entry point and validation  
**Pattern**: Application Controller Pattern  
**Location**: `lib/kanban_metrics/application_runner.rb`

```ruby
module KanbanMetrics
  class ApplicationRunner
```

#### Class Methods
- **`run`**: Main entry point called from executable script
  - Validates environment (API token presence)
  - Parses command-line options
  - Initializes and starts application with parsed options

#### Private Class Methods
- **`validate_api_token`**: Ensures required `LINEAR_API_TOKEN` environment variable is present
- **`start_application(options)`**: Initializes main application flow

**Design Rationale**: Provides clean separation between script execution and application logic, ensuring proper environment validation before proceeding.

---

### OptionsParser (`KanbanMetrics::OptionsParser`)

**Purpose**: Command-line interface and option parsing  
**Pattern**: Parser Pattern  
**Location**: `lib/kanban_metrics/options_parser.rb`

```ruby
module KanbanMetrics
  class OptionsParser
```

#### Class Methods
- **`parse(args)`**: Parses command-line arguments
  - Handles all CLI flags and options
  - Validates option combinations
  - Returns structured options hash
  - Provides help text and usage information

#### Private Class Methods
- **`setup_option_parser`**: Configures OptionParser with all available options
- **`validate_options(options)`**: Ensures option combinations are valid
- **`build_query_options(options)`**: Creates QueryOptions value object

**Supported Options**:
- `--team-id ID`: Filter by team ID
- `--start-date DATE`: Start date for analysis (YYYY-MM-DD)
- `--end-date DATE`: End date for analysis (YYYY-MM-DD)
- `--format FORMAT`: Output format (table, json, csv)
- `--page-size SIZE`: API page size (max 250, default 250)
- `--no-cache`: Disable API response caching
- `--team-metrics`: Include team-based metrics breakdown
- `--timeseries`: Include timeseries analysis
- `--timeline ISSUE_ID`: Show detailed timeline for specific issue
- `--include-archived`: Include archived tickets in analysis
- `--help`: Show help message

**Design Rationale**: Centralizes all CLI option handling and validation, providing a clean interface between command-line input and application logic.

---

### Application (`KanbanMetrics::Application`)

**Purpose**: Main application coordinator and workflow orchestrator  
**Pattern**: Coordinator Pattern  
**Location**: Integrated within `KanbanMetrics::ApplicationRunner`

#### Constructor
- **`initialize(api_token, options)`**: Sets up application with API token and parsed options

#### Public Methods
- **`run`**: Main application workflow
  - Determines execution path (timeline vs. metrics)
  - Coordinates data fetching and processing
  - Handles error cases gracefully

#### Private Methods
- **`fetch_issues(query_options)`**: Delegates to Linear client for data fetching
- **`handle_no_issues`**: Provides feedback when no issues are found
- **`show_timeline(issues, issue_id)`**: Coordinates timeline display workflow
- **`show_metrics(issues, options)`**: Coordinates metrics analysis workflow

**Design Rationale**: Encapsulates high-level application flow while delegating to specialized components, maintaining clean separation of concerns and clear workflow orchestration.

---

## Design Patterns Used

### 1. **Facade Pattern**
- **`KanbanMetrics::Linear::Client`**: Simplifies complex API operations and coordinates multiple API-related classes
- **`KanbanMetrics::Calculators::KanbanMetricsCalculator`**: Provides simple interface to complex metrics calculations
- **`KanbanMetrics::Reports::KanbanReport`**: Unified interface for report generation across multiple output formats

### 2. **Strategy Pattern**
- **Output Formatters**: Different formatting strategies (`TableFormatter`, `CsvFormatter`, `JsonFormatter`, `TimeseriesTableFormatter`)
- **Metrics Calculators**: Different calculation strategies for various metric types

### 3. **Builder Pattern**
- **`KanbanMetrics::Linear::QueryBuilder`**: Constructs complex GraphQL queries with various filters and options
- **`KanbanMetrics::Timeseries::TimelineBuilder`**: Builds chronological event sequences from issue data

### 4. **Repository Pattern**
- **`KanbanMetrics::Linear::Cache`**: Abstracts data storage and retrieval with intelligent caching logic

### 5. **Value Object Pattern**
- **`KanbanMetrics::QueryOptions`**: Immutable configuration object for API queries

### 6. **Adapter Pattern**
- **`KanbanMetrics::Linear::HttpClient`**: Adapts Ruby HTTP library to Linear API requirements
- **`KanbanMetrics::Linear::ApiResponseParser`**: Adapts API responses to application data structures

### 7. **Iterator Pattern**
- **`KanbanMetrics::Linear::ApiPaginator`**: Iterates through paginated API responses automatically

### 8. **Command Pattern**
- **`KanbanMetrics::ApplicationRunner`**: Encapsulates application execution and environment validation
- **`KanbanMetrics::OptionsParser`**: Encapsulates option processing and validation

### 9. **Module Pattern (Ruby-specific)**
- **Zeitwerk Autoloading**: Convention-based module organization with automatic class loading
- **Namespace Organization**: Clear module hierarchy (`Linear`, `Calculators`, `Formatters`, `Reports`, `Timeseries`)

### 10. **Factory Pattern**
- **Formatter Creation**: Dynamic formatter selection based on output format option
- **Calculator Instantiation**: Dynamic calculator creation based on analysis requirements

### 8. **Command Pattern**
- **ApplicationRunner**: Encapsulates application execution
- **OptionsParser**: Encapsulates option processing

## SOLID Principles Applied

### Single Responsibility Principle (SRP)
- **Each class has one clear purpose and reason to change**:
  - `KanbanMetrics::Linear::HttpClient`: Only HTTP communication concerns
  - `KanbanMetrics::Linear::Cache`: Only caching logic and file operations
  - `KanbanMetrics::Calculators::TimeMetricsCalculator`: Only time-based calculations
  - `KanbanMetrics::Formatters::TableFormatter`: Only table formatting logic

### Open/Closed Principle (OCP)
- **Easy to extend without modifying existing code**:
  - New output formatters can be added to `KanbanMetrics::Formatters` without changing existing formatters
  - New calculators can be added to `KanbanMetrics::Calculators` without modifying the orchestrator
  - New report types can be added to `KanbanMetrics::Reports` without changing existing reports

### Liskov Substitution Principle (LSP)
- **Derived classes can substitute their base classes**:
  - All formatters implement the same interface and can be substituted
  - All calculators follow consistent patterns and interfaces
  - Zeitwerk ensures consistent class loading behavior

### Interface Segregation Principle (ISP)
- **Classes depend only on interfaces they actually use**:
  - `ApiPaginator` only depends on the HTTP client and query builder methods it needs
  - Formatters only depend on the specific data structures they format
  - Each module has minimal dependencies on other modules

### Dependency Inversion Principle (DIP)
- **High-level modules don't depend on low-level modules**:
  - `KanbanMetrics::Linear::Client` depends on abstractions (HTTP client, cache interfaces)
  - `KanbanMetrics::Reports::KanbanReport` depends on formatter interfaces, not concrete implementations
  - Easy to mock dependencies for testing due to clear interfaces

## Benefits of This Architecture

### 1. **Maintainability**
- Each component has a clear, single purpose
- Changes are localized to specific modules
- Zeitwerk eliminates manual dependency management
- Clear module organization makes code easy to navigate

### 2. **Testability**
- Small, focused classes are easy to unit test
- Clear interfaces make mocking straightforward
- Zeitwerk autoloading supports test isolation
- Each module can be tested independently

### 3. **Extensibility**
- New features can be added without modifying existing code
- Module structure supports adding new calculators, formatters, or report types
- Zeitwerk automatically discovers new classes following naming conventions

### 4. **Readability**
- Code is self-documenting with clear class and method names
- Module organization reflects functional boundaries
- Consistent patterns across similar classes
- Zeitwerk conventions make file locations predictable

### 5. **Reusability**
- Components can be used independently
- Clear module boundaries enable selective usage
- Value objects and utilities can be reused across modules

### 6. **Performance**
- Zeitwerk lazy loading improves startup time
- Clear separation allows for targeted optimization
- Caching layer reduces API calls effectively
- Minimal memory footprint for simple operations

### 7. **Debugging and Monitoring**
- Issues can be isolated to specific components
- Clear error boundaries between modules
- Zeitwerk debug mode provides loading visibility
- Structured logging possibilities with clear module boundaries

## Migration and Modernization Benefits

### From Monolithic to Modular
- **Before**: Single 800+ line file difficult to maintain
- **After**: 20+ focused classes with clear responsibilities
- **Result**: Easier to understand, modify, and extend

### From Manual Requires to Zeitwerk
- **Before**: Complex web of `require_relative` statements
- **After**: Convention-based autoloading with Zeitwerk
- **Result**: Simplified dependency management and faster development

### From Procedural to Object-Oriented
- **Before**: Procedural script with mixed concerns
- **After**: Proper object-oriented design with SOLID principles
- **Result**: Better encapsulation, inheritance, and polymorphism

### Professional Ruby Standards
- **Gem-like Structure**: Follows Ruby gem conventions
- **Modern Autoloading**: Uses Zeitwerk (Rails 6+ standard)
- **Clean Architecture**: Layered design with clear boundaries
- **Best Practices**: Follows Ruby style guide and conventions

This architecture transformation makes the kanban metrics script highly maintainable, extensible, and professional while following modern Ruby development practices and standards.
