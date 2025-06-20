# frozen_string_literal: true

require 'digest'
require 'fileutils'
require 'json'
require 'time'

module KanbanMetrics
  module Linear
    # Handles caching of Linear API responses
    class Cache
      DEFAULT_CACHE_DIR = 'tmp/.linear_cache'

      attr_reader :cache_dir

      def initialize(cache_dir = nil)
        @cache_dir = cache_dir || environment_cache_dir
        setup_cache_directory
      end

      def fetch_cached_issues(cache_key)
        return nil unless cached_data_exists?(cache_key)

        cached_data = read_from_cache(cache_key)
        return nil unless cached_data
        return nil if cache_expired?(cached_data[:timestamp])

        log_cache_hit(cached_data[:issues], cache_key)
        cached_data[:issues]
      end

      def save_issues_to_cache(cache_key, issues)
        save_to_cache(cache_key, issues)
      end

      def generate_cache_key(options)
        Digest::MD5.hexdigest(options.cache_key_data.to_json)
      end

      def set(cache_key, data)
        setup_cache_directory
        cache_data = {
          data: data,
          cached_at: Time.now.to_i,
          expires_at: end_of_day.to_i # Expire at end of day (midnight)
        }
        File.write(cache_file_path(cache_key), JSON.pretty_generate(cache_data))
      rescue StandardError => e
        log_cache_error("Cache write error: #{e.message}")
        false
      end

      def get(cache_key)
        return nil unless cached_data_exists?(cache_key)

        content = File.read(cache_file_path(cache_key))
        cached_data = JSON.parse(content)

        # Check if cache has expired (after midnight of the next day)
        if cached_data['expires_at']
          return nil if Time.now.to_i > cached_data['expires_at']
        elsif cached_data['cached_at']
          # Fallback for old cache format - expire at end of day when cached
          cached_time = Time.at(cached_data['cached_at'])
          expires_at = Time.new(cached_time.year, cached_time.month, cached_time.day, 23, 59, 59)
          return nil if Time.now > expires_at
        end

        cached_data['data']
      rescue JSON::ParserError => e
        log_cache_error("Cache read error - corrupted data: #{e.message}")
        nil
      rescue StandardError => e
        log_cache_error("Cache read error: #{e.message}")
        nil
      end

      private

      def setup_cache_directory
        FileUtils.mkdir_p(@cache_dir)
      end

      def cached_data_exists?(cache_key)
        File.exist?(cache_file_path(cache_key))
      end

      def cache_file_path(cache_key)
        File.join(@cache_dir, "#{cache_key}.json")
      end

      def read_from_cache(cache_key)
        content = File.read(cache_file_path(cache_key))
        data = JSON.parse(content)
        {
          issues: data['issues'],
          timestamp: Time.parse(data['timestamp'])
        }
      rescue StandardError => e
        log_cache_error("Cache read error: #{e.message}")
        nil
      end

      def save_to_cache(cache_key, issues)
        cache_data = { issues: issues, timestamp: Time.now.iso8601 }
        File.write(cache_file_path(cache_key), JSON.pretty_generate(cache_data))
        log_cache_save(issues.length)
      rescue StandardError => e
        log_cache_error("Cache write error: #{e.message}")
      end

      def cache_expired?(timestamp)
        timestamp.to_date < Time.now.to_date
      end

      def log_cache_hit(issues, cache_key)
        return unless ENV['DEBUG'] || !ENV['QUIET']

        puts "✅ Using cached data (#{issues.length} issues) - cache key: #{cache_key[0..7]}..."
      end

      def log_cache_save(count)
        puts "💾 Saved #{count} issues to cache" if ENV['DEBUG']
      end

      def log_cache_error(message)
        puts "⚠️ #{message}" if ENV['DEBUG']
      end

      def end_of_day
        now = Time.now
        Time.new(now.year, now.month, now.day, 23, 59, 59)
      end

      def environment_cache_dir
        env = current_environment
        case env
        when 'test'
          'tmp/.linear_cache_test'
        when 'development'
          'tmp/.linear_cache_development'
        when 'production'
          'tmp/.linear_cache_production'
        else
          DEFAULT_CACHE_DIR
        end
      end

      def current_environment
        ENV['RACK_ENV'] || ENV['RAILS_ENV'] || 'development'
      end
    end
  end
end
