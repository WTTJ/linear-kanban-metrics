# frozen_string_literal: true

module KanbanMetrics
  module Linear
    # Handles API interaction logging
    class ApiLogger
      def self.log_cache_miss
        return unless debug_mode? || !quiet_mode?

        puts '🔄 Cache miss or expired, fetching from API...'
      end

      def self.log_api_fetch_start(cache_disabled)
        message = cache_disabled ? 'Cache disabled, fetching from API...' : 'Fetching from API...'
        puts "🔄 #{message}" if debug_mode?
      end

      def self.log_api_fetch_complete(count)
        return unless debug_mode? || count > 250

        puts "✅ Successfully fetched #{count} total issues from Linear API"
      end

      private_class_method def self.debug_mode?
        ENV.fetch('DEBUG', nil)
      end

      private_class_method def self.quiet_mode?
        ENV.fetch('QUIET', nil)
      end
    end

    # Handles caching strategy for API requests
    class CachingStrategy
      def initialize(cache)
        @cache = cache
      end

      def fetch_with_cache(options)
        cache_key = @cache.generate_cache_key(options)
        cached_issues = @cache.fetch_cached_issues(cache_key)

        return cached_issues if cached_issues

        ApiLogger.log_cache_miss
        issues = yield
        @cache.save_issues_to_cache(cache_key, issues)
        issues
      end
    end

    # Handles API request orchestration
    class ApiRequestOrchestrator
      def initialize(http_client, query_builder)
        @http_client = http_client
        @query_builder = query_builder
      end

      def fetch_issues(options)
        ApiLogger.log_api_fetch_start(options.no_cache)

        issues = paginated_fetch(options)

        ApiLogger.log_api_fetch_complete(issues.length)
        issues
      end

      private

      def paginated_fetch(options)
        paginator = Linear::ApiPaginator.new(@http_client, @query_builder)
        paginator.fetch_all_pages(options)
      end
    end

    # Handles Linear API interactions with caching
    class Client
      def initialize(api_token)
        @orchestrator = ApiRequestOrchestrator.new(
          HttpClient.new(api_token),
          QueryBuilder.new
        )
        @caching_strategy = CachingStrategy.new(Cache.new)
      end

      def fetch_issues(options_hash = {})
        options = KanbanMetrics::QueryOptions.new(options_hash)

        if options.no_cache
          @orchestrator.fetch_issues(options)
        else
          @caching_strategy.fetch_with_cache(options) do
            @orchestrator.fetch_issues(options)
          end
        end
      end
    end
  end
end
