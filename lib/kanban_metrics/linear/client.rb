# frozen_string_literal: true

module KanbanMetrics
  module Linear
    # Handles Linear API interactions with caching
    class Client
      def initialize(api_token)
        @http_client = HttpClient.new(api_token)
        @query_builder = QueryBuilder.new
        @cache = Cache.new
      end

      def fetch_issues(options_hash = {})
        options = KanbanMetrics::QueryOptions.new(options_hash)

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
        paginator = Linear::ApiPaginator.new(@http_client, @query_builder)
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
  end
end
