# frozen_string_literal: true

module KanbanMetrics
  module Linear
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
        response_data = @http_client.post_graphql(query)

        # Handle nil response
        return nil if response_data.nil?

        # Extract issues data from the response
        issues_data = response_data.dig('data', 'issues')
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
  end
end
