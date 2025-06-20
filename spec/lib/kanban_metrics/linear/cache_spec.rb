# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../../lib/kanban_metrics/linear/cache'

RSpec.describe KanbanMetrics::Linear::Cache do
  # === TEST DATA ===
  let(:cache_dir) { 'tmp/test_cache' }
  let(:cache) { described_class.new(cache_dir) }
  let(:query_options) { KanbanMetrics::QueryOptions.new(team_id: 'team-123') }
  let(:test_data) { { 'issues' => [{ 'id' => 'issue-1', 'title' => 'Test Issue' }] } }

  # === SETUP & TEARDOWN ===
  before do
    FileUtils.rm_rf(cache_dir)
  end

  after do
    FileUtils.rm_rf(cache_dir)
  end

  describe '#initialize' do
    context 'when initializing with custom cache directory' do
      it 'sets the cache directory correctly' do
        # Arrange
        custom_dir = 'tmp/custom_cache'

        # Act
        custom_cache = described_class.new(custom_dir)

        # Assert
        expect(custom_cache.instance_variable_get(:@cache_dir)).to eq(custom_dir)

        # Cleanup
        # (handled by after hook)
      end
    end

    context 'when initializing with default settings' do
      it 'uses the environment-specific cache directory' do
        # Arrange
        # (no specific setup needed - test environment is already set)

        # Act
        default_cache = described_class.new

        # Assert
        expect(default_cache.instance_variable_get(:@cache_dir)).to eq('tmp/.linear_cache_test')

        # Cleanup
        # (automatic - default cache uses different directory)
      end
    end
  end

  describe 'environment-specific cache directories' do
    context 'when environment variables control cache directory' do
      it 'uses test-specific cache directory in test environment' do
        # Arrange
        # (test environment is already set in spec/support/environment.rb)

        # Act
        cache = described_class.new

        # Assert
        expect(cache.cache_dir).to eq('tmp/.linear_cache_test')
      end

      it 'uses development cache directory when RACK_ENV is development' do
        # Arrange
        original_env = ENV.fetch('RACK_ENV', nil)
        ENV['RACK_ENV'] = 'development'

        # Act
        cache = described_class.new

        # Assert
        expect(cache.cache_dir).to eq('tmp/.linear_cache_development')

        # Cleanup
        ENV['RACK_ENV'] = original_env
      end

      it 'uses production cache directory when RACK_ENV is production' do
        # Arrange
        original_env = ENV.fetch('RACK_ENV', nil)
        ENV['RACK_ENV'] = 'production'

        # Act
        cache = described_class.new

        # Assert
        expect(cache.cache_dir).to eq('tmp/.linear_cache_production')

        # Cleanup
        ENV['RACK_ENV'] = original_env
      end

      it 'falls back to default cache directory for unknown environments' do
        # Arrange
        original_env = ENV.fetch('RACK_ENV', nil)
        ENV['RACK_ENV'] = 'staging'

        # Act
        cache = described_class.new

        # Assert
        expect(cache.cache_dir).to eq('tmp/.linear_cache')

        # Cleanup
        ENV['RACK_ENV'] = original_env
      end
    end
  end

  describe '#generate_cache_key' do
    context 'when generating cache keys for consistent options' do
      it 'produces deterministic and consistent cache keys' do
        # Arrange
        # (query_options set up in let block)

        # Act
        key1 = cache.generate_cache_key(query_options)
        key2 = cache.generate_cache_key(query_options)

        # Assert
        aggregate_failures 'cache key generation consistency' do
          expect(key1).to be_a(String)
          expect(key1.length).to be > 0
          expect(key1).to eq(key2)
        end

        # Cleanup
        # (automatic with let blocks)
      end
    end

    context 'when generating cache keys for different options' do
      it 'produces different keys for different query parameters' do
        # Arrange
        options1 = KanbanMetrics::QueryOptions.new(team_id: 'team-123')
        options2 = KanbanMetrics::QueryOptions.new(team_id: 'team-456')

        # Act
        key1 = cache.generate_cache_key(options1)
        key2 = cache.generate_cache_key(options2)

        # Assert
        expect(key1).not_to eq(key2)

        # Cleanup
        # (automatic with let blocks)
      end
    end

    context 'when handling include_archived flag variations' do
      it 'generates different keys based on archived inclusion setting' do
        # Arrange
        options_without_archived = KanbanMetrics::QueryOptions.new(team_id: 'team-123', include_archived: false)
        options_with_archived = KanbanMetrics::QueryOptions.new(team_id: 'team-123', include_archived: true)

        # Act
        key1 = cache.generate_cache_key(options_without_archived)
        key2 = cache.generate_cache_key(options_with_archived)

        # Assert
        expect(key1).not_to eq(key2)

        # Cleanup
        # (automatic with let blocks)
      end
    end
  end

  describe '#set and #get' do
    let(:cache_key) { cache.generate_cache_key(query_options) }

    context 'when storing and retrieving cache data' do
      it 'successfully stores and retrieves data' do
        # Arrange
        # (cache_key and test_data set up in let blocks)

        # Act
        cache.set(cache_key, test_data)
        retrieved_data = cache.get(cache_key)

        # Assert
        expect(retrieved_data).to eq(test_data)

        # Cleanup
        # (handled by after hook)
      end
    end

    context 'when retrieving non-existent cache data' do
      it 'returns nil for missing cache keys' do
        # Arrange
        non_existent_key = 'non-existent-cache-key'

        # Act
        result = cache.get(non_existent_key)

        # Assert
        expect(result).to be_nil

        # Cleanup
        # (no cleanup needed for non-existent data)
      end
    end

    context 'when cache directory does not exist' do
      it 'creates the cache directory automatically' do
        # Arrange
        expect(Dir.exist?(cache_dir)).to be false

        # Act
        cache.set(cache_key, test_data)

        # Assert
        expect(Dir.exist?(cache_dir)).to be true

        # Cleanup
        # (handled by after hook)
      end
    end

    context 'when examining cache metadata' do
      it 'stores comprehensive metadata with cached data' do
        # Arrange
        # (cache_key and test_data set up in let blocks)

        # Act
        cache.set(cache_key, test_data)

        # Assert
        cache_file = File.join(cache_dir, "#{cache_key}.json")
        expect(File.exist?(cache_file)).to be true

        stored_data = JSON.parse(File.read(cache_file))
        aggregate_failures 'cache metadata validation' do
          expect(stored_data).to have_key('data')
          expect(stored_data).to have_key('cached_at')
          expect(stored_data).to have_key('expires_at')
          expect(stored_data['data']).to eq(test_data)

          # Verify expires_at is set to end of day
          expires_at = Time.at(stored_data['expires_at'])
          expect(expires_at.hour).to eq(23)
          expect(expires_at.min).to eq(59)
          expect(expires_at.sec).to eq(59)
        end

        # Cleanup
        # (handled by after hook)
      end
    end
  end

  describe 'cache TTL (Time To Live)' do
    let(:cache_key) { cache.generate_cache_key(query_options) }

    context 'when cache is within TTL' do
      it 'returns cached data successfully' do
        # Arrange
        cache.set(cache_key, test_data)

        # Act
        retrieved_data = cache.get(cache_key)

        # Assert
        expect(retrieved_data).to eq(test_data)

        # Cleanup
        # (handled by after hook)
      end
    end

    context 'when verifying cache persistence throughout same day' do
      it 'maintains cache validity until end of day' do
        # Arrange
        cache.set(cache_key, test_data)

        # Act
        result = cache.get(cache_key)
        cache_file = File.join(cache_dir, "#{cache_key}.json")
        cached_data = JSON.parse(File.read(cache_file))

        # Assert
        aggregate_failures 'same-day cache persistence' do
          expect(result).to eq(test_data)

          # Verify expires_at is set to end of today
          expires_at = Time.at(cached_data['expires_at'])
          today = Time.now
          expect(expires_at.year).to eq(today.year)
          expect(expires_at.month).to eq(today.month)
          expect(expires_at.day).to eq(today.day)
          expect(expires_at.hour).to eq(23)
          expect(expires_at.min).to eq(59)
          expect(expires_at.sec).to eq(59)
        end

        # Cleanup
        # (handled by after hook)
      end
    end

    context 'when cache is expired' do
      it 'returns nil for expired cache entries' do
        # Arrange
        cache.set(cache_key, test_data)

        # Simulate expired cache by setting expires_at to yesterday
        cache_file = File.join(cache_dir, "#{cache_key}.json")
        cached_data = JSON.parse(File.read(cache_file))
        yesterday_end = Time.now - (24 * 60 * 60)
        cached_data['expires_at'] =
          Time.new(yesterday_end.year, yesterday_end.month, yesterday_end.day, 23, 59, 59).to_i
        File.write(cache_file, JSON.pretty_generate(cached_data))

        # Act
        result = cache.get(cache_key)

        # Assert
        expect(result).to be_nil

        # Cleanup
        # (handled by after hook)
      end
    end
  end

  describe 'error handling' do
    let(:cache_key) { cache.generate_cache_key(query_options) }

    context 'when dealing with corrupted cache files' do
      it 'handles corrupted cache files gracefully' do
        # Arrange
        cache_file = File.join(cache_dir, "#{cache_key}.json")
        FileUtils.mkdir_p(cache_dir)
        File.write(cache_file, 'invalid json content')

        # Act
        result = cache.get(cache_key)

        # Assert
        expect(result).to be_nil

        # Cleanup
        # (handled by after hook)
      end
    end

    context 'when encountering permission errors' do
      it 'handles file permission errors gracefully' do
        # Arrange
        cache.set(cache_key, test_data)
        cache_file = File.join(cache_dir, "#{cache_key}.json")
        File.chmod(0o000, cache_file)

        # Act
        result = cache.get(cache_key)

        # Assert
        expect(result).to be_nil

        # Cleanup
        File.chmod(0o644, cache_file) # Restore permissions for cleanup
      end
    end
  end
end
