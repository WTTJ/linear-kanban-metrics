# frozen_string_literal: true

module KanbanMetrics
  module Linear
    # Configuration for GraphQL query defaults
    class QueryConfig
      HISTORY_LIMIT = 50

      def self.debug_enabled?
        ENV.fetch('DEBUG', nil)
      end
    end

    # Builds team-related filters for GraphQL queries
    class TeamFilter
      UUID_PATTERN = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i

      def self.build(team_identifier)
        return nil unless team_identifier

        if uuid?(team_identifier)
          "team: { id: { eq: \"#{team_identifier}\" } }"
        else
          "team: { key: { eq: \"#{team_identifier}\" } }"
        end
      end

      private_class_method def self.uuid?(identifier)
        identifier.match?(UUID_PATTERN)
      end
    end

    # Builds date-related filters for GraphQL queries
    class DateFilter
      def self.build(start_date, end_date)
        return nil unless start_date || end_date

        conditions = []
        conditions << "gte: \"#{start_date}T00:00:00.000Z\"" if start_date
        conditions << "lte: \"#{end_date}T23:59:59.999Z\"" if end_date
        "updatedAt: { #{conditions.join(', ')} }"
      end
    end

    # Handles query parameter building for GraphQL
    class QueryParameterBuilder
      def initialize(options)
        @options = options
      end

      def build_filter_parameters
        filters = collect_filters
        filter_part = build_filter_clause(filters)
        archive_part = build_archive_clause

        "#{filter_part}#{archive_part}"
      end

      def build_pagination_parameters(after_cursor)
        args = ["first: #{@options.page_size}"]
        args << "after: \"#{after_cursor}\"" if after_cursor
        args.join(', ')
      end

      private

      def collect_filters
        [
          TeamFilter.build(@options.team_id),
          DateFilter.build(@options.start_date, @options.end_date)
        ].compact
      end

      def build_filter_clause(filters)
        return '' if filters.empty?

        "filter: { #{filters.join(', ')} }, "
      end

      def build_archive_clause
        return '' unless @options.include_archived

        'includeArchived: true, '
      end
    end

    # Logs GraphQL query information for debugging
    class QueryLogger
      def self.log_if_enabled(filters, pagination)
        return unless QueryConfig.debug_enabled?

        puts "🔍 GraphQL Query: issues(#{filters}#{pagination})"
      end
    end

    # Builds GraphQL queries for Linear API
    class QueryBuilder
      def build_issues_query(options, after_cursor = nil)
        parameter_builder = QueryParameterBuilder.new(options)
        filters = parameter_builder.build_filter_parameters
        pagination = parameter_builder.build_pagination_parameters(after_cursor)

        QueryLogger.log_if_enabled(filters, pagination)

        build_graphql_query(filters, pagination)
      end

      private

      def build_graphql_query(filters, pagination)
        <<~GRAPHQL
          query {
            issues(#{filters}#{pagination}) {
              #{page_info_fields}
              #{issue_node_fields}
            }
          }
        GRAPHQL
      end

      def page_info_fields
        'pageInfo { hasNextPage endCursor }'
      end

      def issue_node_fields
        <<~FIELDS.strip
          nodes {
            #{basic_issue_fields}
            #{relationship_fields}
            #{timestamp_fields}
            #{history_fields}
          }
        FIELDS
      end

      def basic_issue_fields
        'id identifier title priority estimate'
      end

      def relationship_fields
        <<~FIELDS.strip
          state { id name type }
          team { id name }
          assignee { id name }
        FIELDS
      end

      def timestamp_fields
        'createdAt updatedAt completedAt startedAt archivedAt'
      end

      def history_fields
        <<~FIELDS.strip
          history(first: #{QueryConfig::HISTORY_LIMIT}) {
            nodes {
              id createdAt
              fromState { id name type }
              toState { id name type }
            }
          }
        FIELDS
      end
    end
  end
end
