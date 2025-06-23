# frozen_string_literal: true

require 'digest'
require 'fileutils'
require 'json'
require 'time'

module KanbanMetrics
  module Linear
    # Configuration constants for cache behavior
    module CacheConfig
      DEFAULT_CACHE_DIR = 'tmp/.linear_cache'
      ENVIRONMENT_DIRS = {
        'test' => 'tmp/.linear_cache_test',
        'development' => 'tmp/.linear_cache_development',
        'production' => 'tmp/.linear_cache_production'
      }.freeze
    end

    # Handles cache key generation
    class CacheKeyGenerator
      def self.generate(options)
        Digest::MD5.hexdigest(options.cache_key_data.to_json)
      end
    end

    # Handles cache file operations
    class CacheFileManager
      include CacheConfig

      def initialize(cache_dir)
        @cache_dir = cache_dir
        setup_directory
      end

      def file_exists?(cache_key)
        File.exist?(file_path(cache_key))
      end

      def file_path(cache_key)
        File.join(@cache_dir, "#{cache_key}.json")
      end

      def read_file(cache_key)
        File.read(file_path(cache_key))
      end

      def write_file(cache_key, content)
        File.write(file_path(cache_key), content)
      end

      private

      def setup_directory
        FileUtils.mkdir_p(@cache_dir)
      end
    end

    # Handles cache data serialization/deserialization
    class CacheDataSerializer
      def self.serialize(data)
        JSON.pretty_generate(data)
      end

      def self.deserialize(content)
        JSON.parse(content)
      rescue JSON::ParserError => e
        raise CacheError, "Corrupted cache data: #{e.message}"
      end
    end

    # Handles cache expiration logic
    class CacheExpirationValidator
      def self.expired?(cached_data)
        return true unless cached_data

        if cached_data['expires_at']
          Time.now.to_i > cached_data['expires_at']
        elsif cached_data['cached_at']
          legacy_expired?(cached_data['cached_at'])
        else
          true
        end
      end

      def self.legacy_expired?(cached_at)
        cached_time = Time.at(cached_at)
        expires_at = Time.new(cached_time.year, cached_time.month, cached_time.day, 23, 59, 59)
        Time.now > expires_at
      end

      def self.end_of_day_timestamp
        now = Time.now
        Time.new(now.year, now.month, now.day, 23, 59, 59).to_i
      end
    end

    # Handles cache logging
    class CacheLogger
      def self.log_hit(issues_count, cache_key)
        return unless debug_mode? || !quiet_mode?

        puts "✅ Using cached data (#{issues_count} issues) - cache key: #{cache_key[0..7]}..."
      end

      def self.log_save(count)
        puts "💾 Saved #{count} issues to cache" if debug_mode?
      end

      def self.log_error(message)
        puts "⚠️ #{message}" if debug_mode?
      end

      private_class_method def self.debug_mode?
        ENV.fetch('DEBUG', nil)
      end

      private_class_method def self.quiet_mode?
        ENV.fetch('QUIET', nil)
      end
    end

    # Determines cache directory based on environment
    class CacheDirectoryResolver
      include CacheConfig

      def self.resolve(custom_dir = nil)
        return custom_dir if custom_dir

        environment = current_environment
        ENVIRONMENT_DIRS[environment] || DEFAULT_CACHE_DIR
      end

      private_class_method def self.current_environment
        ENV['RACK_ENV'] || 'development'
      end
    end

    # Main cache class - orchestrates cache operations
    class Cache
      attr_reader :cache_dir

      def initialize(cache_dir = nil)
        resolved_dir = CacheDirectoryResolver.resolve(cache_dir)
        @file_manager = CacheFileManager.new(resolved_dir)
        @cache_dir = resolved_dir
      end

      def fetch_cached_issues(cache_key)
        return nil unless @file_manager.file_exists?(cache_key)

        cached_data = read_legacy_format(cache_key)
        return nil unless cached_data
        return nil if legacy_expired?(cached_data[:timestamp])

        CacheLogger.log_hit(cached_data[:issues].length, cache_key)
        cached_data[:issues]
      end

      def save_issues_to_cache(cache_key, issues)
        save_legacy_format(cache_key, issues)
      end

      def generate_cache_key(options)
        CacheKeyGenerator.generate(options)
      end

      def set(cache_key, data)
        cache_data = build_cache_data(data)
        content = CacheDataSerializer.serialize(cache_data)
        @file_manager.write_file(cache_key, content)
        true
      rescue StandardError => e
        CacheLogger.log_error("Cache write error: #{e.message}")
        false
      end

      def get(cache_key)
        return nil unless @file_manager.file_exists?(cache_key)

        content = @file_manager.read_file(cache_key)
        cached_data = CacheDataSerializer.deserialize(content)

        return nil if CacheExpirationValidator.expired?(cached_data)

        cached_data['data']
      rescue StandardError => e
        CacheLogger.log_error("Cache read error: #{e.message}")
        nil
      end

      private

      def build_cache_data(data)
        {
          data: data,
          cached_at: Time.now.to_i,
          expires_at: CacheExpirationValidator.end_of_day_timestamp
        }
      end

      def read_legacy_format(cache_key)
        content = @file_manager.read_file(cache_key)
        data = CacheDataSerializer.deserialize(content)
        {
          issues: data['issues'],
          timestamp: Time.parse(data['timestamp'])
        }
      rescue StandardError => e
        CacheLogger.log_error("Cache read error: #{e.message}")
        nil
      end

      def save_legacy_format(cache_key, issues)
        cache_data = { issues: issues, timestamp: Time.now.iso8601 }
        content = CacheDataSerializer.serialize(cache_data)
        @file_manager.write_file(cache_key, content)
        CacheLogger.log_save(issues.length)
      rescue StandardError => e
        CacheLogger.log_error("Cache write error: #{e.message}")
      end

      def legacy_expired?(timestamp)
        timestamp.to_date < Time.now.to_date
      end
    end
  end
end
