# frozen_string_literal: true

module KanbanMetrics
  module Linear
    # Configuration constants for pagination
    module PaginationConfig
      MAX_PAGES = 100
      DEBUG_LOG_THRESHOLD = 250
    end

    # Handles paginated API requests
    class ApiPaginator
      include PaginationConfig

      def initialize(http_client, query_builder)
        @http_client = http_client
        @query_builder = query_builder
      end

      def fetch_all_pages(options)
        collector = IssueCollector.new
        page_state = PageState.new

        while should_continue_pagination?(page_state)
          log_page_fetch(page_state.current_page, collector.total_count)

          page_result = fetch_single_page(options, page_state.after_cursor)
          break unless handle_page_result(page_result, collector, page_state)
        end

        collector.all_issues
      end

      private

      def should_continue_pagination?(page_state)
        page_state.has_next_page? && !page_state.safety_limit_reached?
      end

      def handle_page_result(page_result, collector, page_state)
        return false if page_result.nil?

        collector.add_issues(page_result[:issues])
        page_state.update(page_result[:page_info])
        true
      end

      def fetch_single_page(options, after_cursor)
        query = @query_builder.build_issues_query(options, after_cursor)
        response_data = @http_client.post_graphql(query)

        ResponseParser.parse(response_data)
      end

      def log_page_fetch(page, total_issues)
        return unless should_log_progress?(total_issues)

        puts "📄 Fetching page #{page}..."
      end

      def should_log_progress?(total_issues)
        debug_mode_enabled? || high_volume_request?(total_issues)
      end

      def debug_mode_enabled?
        ENV['DEBUG']
      end

      def high_volume_request?(total_issues)
        total_issues > DEBUG_LOG_THRESHOLD
      end
    end

    # Collects issues across multiple pages
    class IssueCollector
      attr_reader :all_issues

      def initialize
        @all_issues = []
      end

      def add_issues(issues)
        @all_issues.concat(issues)
      end

      def total_count
        @all_issues.length
      end
    end

    # Parses GraphQL API responses
    class ResponseParser
      def self.parse(response_data)
        return nil if response_data.nil?

        issues_data = response_data.dig('data', 'issues')
        return nil unless issues_data

        {
          issues: issues_data['nodes'] || [],
          page_info: normalize_page_info(issues_data['pageInfo'] || {})
        }
      end

      private_class_method def self.normalize_page_info(page_info)
        {
          has_next_page: page_info['hasNextPage'] || false,
          end_cursor: page_info['endCursor']
        }
      end
    end

    # Tracks pagination state
    class PageState
      include PaginationConfig

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
  end
end
