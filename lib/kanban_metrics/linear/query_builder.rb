# frozen_string_literal: true

module KanbanMetrics
  module Linear
    # Builds GraphQL queries for Linear API
    class QueryBuilder
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

      def team_filter(team_identifier)
        # Check if the identifier looks like a UUID (contains hyphens and is longer)
        # UUIDs are 36 characters with hyphens, team keys are typically short (2-5 chars)
        if team_identifier.match?(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i)
          # Use ID filter for UUIDs
          "team: { id: { eq: \"#{team_identifier}\" } }"
        else
          # Use key filter for team keys (like "ROI", "FRONT", etc.)
          "team: { key: { eq: \"#{team_identifier}\" } }"
        end
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
  end
end
