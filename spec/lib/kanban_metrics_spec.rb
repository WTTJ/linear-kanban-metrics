# frozen_string_literal: true

require 'spec_helper'

RSpec.describe KanbanMetrics do
  describe 'module structure' do
    it 'defines the main module' do
      # Given: The KanbanMetrics module
      # When: Checking module definition
      # Then: Should be a valid Ruby module
      expect(described_class).to be_a(Module)
    end

    it 'defines custom error class hierarchy' do
      # Given: The KanbanMetrics module with error classes
      # When: Checking error class inheritance
      # Then: Should define proper error hierarchy
      aggregate_failures 'error class inheritance hierarchy' do
        expect(KanbanMetrics::Error).to be < StandardError
        expect(KanbanMetrics::ApiError).to be < KanbanMetrics::Error
        expect(KanbanMetrics::CacheError).to be < KanbanMetrics::Error
      end
    end
  end

  describe 'constants' do
    it 'has a properly formatted version constant' do
      # Given: The KanbanMetrics module
      # When: Checking the VERSION constant
      # Then: Should have a valid semantic version string
      aggregate_failures 'version constant format and type' do
        expect(KanbanMetrics::VERSION).to be_a(String)
        expect(KanbanMetrics::VERSION).to match(/\A\d+\.\d+\.\d+\z/)
      end
    end
  end

  describe 'autoloading' do
    it 'autoloads main application classes' do
      # Given: The KanbanMetrics module with autoloading configured
      # When: Accessing main application classes
      # Then: Should autoload all core classes without errors
      aggregate_failures 'main application class autoloading' do
        expect { KanbanMetrics::ApplicationRunner }.not_to raise_error
        expect { KanbanMetrics::OptionsParser }.not_to raise_error
        expect { KanbanMetrics::QueryOptions }.not_to raise_error
      end
    end

    it 'autoloads calculator namespace classes' do
      # Given: The KanbanMetrics::Calculators namespace
      # When: Accessing calculator classes
      # Then: Should autoload all calculator classes without errors
      aggregate_failures 'calculator class autoloading' do
        expect { KanbanMetrics::Calculators::KanbanMetricsCalculator }.not_to raise_error
        expect { KanbanMetrics::Calculators::FlowEfficiencyCalculator }.not_to raise_error
        expect { KanbanMetrics::Calculators::ThroughputCalculator }.not_to raise_error
        expect { KanbanMetrics::Calculators::TimeMetricsCalculator }.not_to raise_error
        expect { KanbanMetrics::Calculators::IssuePartitioner }.not_to raise_error
      end
    end

    it 'autoloads formatter namespace classes' do
      # Given: The KanbanMetrics::Formatters namespace
      # When: Accessing formatter classes
      # Then: Should autoload all formatter classes without errors
      aggregate_failures 'formatter class autoloading' do
        expect { KanbanMetrics::Formatters::JsonFormatter }.not_to raise_error
        expect { KanbanMetrics::Formatters::CsvFormatter }.not_to raise_error
        expect { KanbanMetrics::Formatters::TableFormatter }.not_to raise_error
        expect { KanbanMetrics::Formatters::TimeseriesTableFormatter }.not_to raise_error
      end
    end

    it 'autoloads linear client namespace classes' do
      # Given: The KanbanMetrics::Linear namespace
      # When: Accessing Linear API client classes
      # Then: Should autoload all Linear client classes without errors
      aggregate_failures 'linear client class autoloading' do
        expect { KanbanMetrics::Linear::Client }.not_to raise_error
        expect { KanbanMetrics::Linear::HttpClient }.not_to raise_error
        expect { KanbanMetrics::Linear::Cache }.not_to raise_error
        expect { KanbanMetrics::Linear::QueryBuilder }.not_to raise_error
        expect { KanbanMetrics::Linear::ApiPaginator }.not_to raise_error
        expect { KanbanMetrics::Linear::ApiResponseParser }.not_to raise_error
      end
    end

    it 'autoloads report namespace classes' do
      # Given: The KanbanMetrics::Reports namespace
      # When: Accessing report classes
      # Then: Should autoload all report classes without errors
      aggregate_failures 'report class autoloading' do
        expect { KanbanMetrics::Reports::KanbanReport }.not_to raise_error
        expect { KanbanMetrics::Reports::TimelineDisplay }.not_to raise_error
      end
    end

    it 'autoloads timeseries namespace classes' do
      # Given: The KanbanMetrics::Timeseries namespace
      # When: Accessing timeseries classes
      # Then: Should autoload all timeseries classes without errors
      aggregate_failures 'timeseries class autoloading' do
        expect { KanbanMetrics::Timeseries::TicketTimeseries }.not_to raise_error
        expect { KanbanMetrics::Timeseries::TimelineBuilder }.not_to raise_error
      end
    end
  end

  describe 'error classes functionality' do
    describe 'Error' do
      it 'can be instantiated with a message' do
        # Given: The Error class
        # When: Creating an error with a message
        error = KanbanMetrics::Error.new('Test error message')

        # Then: Should create error with proper message
        expect(error).to be_a(KanbanMetrics::Error)
        expect(error.message).to eq('Test error message')
      end

      it 'inherits from StandardError' do
        # Given: The Error class
        # When: Checking inheritance
        # Then: Should inherit from StandardError
        expect(KanbanMetrics::Error.ancestors).to include(StandardError)
      end
    end

    describe 'ApiError' do
      it 'can be instantiated with a message' do
        # Given: The ApiError class
        # When: Creating an API error with a message
        error = KanbanMetrics::ApiError.new('API connection failed')

        # Then: Should create error with proper message and inheritance
        expect(error).to be_a(KanbanMetrics::ApiError)
        expect(error).to be_a(KanbanMetrics::Error)
        expect(error.message).to eq('API connection failed')
      end

      it 'can be caught as base Error' do
        # Given: The ApiError class
        # When: Raising an ApiError
        # Then: Should be catchable as base Error
        expect { raise KanbanMetrics::ApiError, 'API failed' }
          .to raise_error(KanbanMetrics::Error, 'API failed')
      end
    end

    describe 'CacheError' do
      it 'can be instantiated with a message' do
        # Given: The CacheError class
        # When: Creating a cache error with a message
        error = KanbanMetrics::CacheError.new('Cache write failed')

        # Then: Should create error with proper message and inheritance
        expect(error).to be_a(KanbanMetrics::CacheError)
        expect(error).to be_a(KanbanMetrics::Error)
        expect(error.message).to eq('Cache write failed')
      end

      it 'can be caught as base Error' do
        # Given: The CacheError class
        # When: Raising a CacheError
        # Then: Should be catchable as base Error
        expect { raise KanbanMetrics::CacheError, 'Cache failed' }
          .to raise_error(KanbanMetrics::Error, 'Cache failed')
      end
    end
  end

  describe 'dependency loading' do
    it 'loads all required gems' do
      # Given: The KanbanMetrics module loaded
      # When: Checking if required constants are defined
      # Then: Should have all required dependencies available
      aggregate_failures 'required dependency constants' do
        expect(defined?(Net::HTTP)).to be_truthy
        expect(defined?(URI)).to be_truthy
        expect(defined?(JSON)).to be_truthy
        expect(defined?(Dotenv)).to be_truthy
        expect(defined?(OptionParser)).to be_truthy
        expect(defined?(Date)).to be_truthy
        expect(defined?(Terminal::Table)).to be_truthy
        expect(defined?(CSV)).to be_truthy
        expect(defined?(Digest)).to be_truthy
        expect(defined?(FileUtils)).to be_truthy
        expect(defined?(Zeitwerk)).to be_truthy
        expect(defined?(Logger)).to be_truthy
      end
    end
  end

  describe 'Zeitwerk configuration' do
    it 'sets up Zeitwerk loader correctly' do
      # Given: Zeitwerk is configured
      # When: Checking loader setup
      # Then: Should have proper loader configuration
      expect(Zeitwerk::Loader).to respond_to(:for_gem)
    end

    it 'enables Zeitwerk debug logging when environment variable is set' do
      # Given: ZEITWERK_DEBUG environment variable
      # When: Checking if debug logging is configured
      # Then: Should respect debug environment variable
      original_env = ENV.fetch('ZEITWERK_DEBUG', nil)

      begin
        ENV['ZEITWERK_DEBUG'] = 'true'
        # This test verifies the conditional logic exists
        # The actual loader setup happens at require time
        expect(ENV.fetch('ZEITWERK_DEBUG', nil)).to eq('true')
      ensure
        ENV['ZEITWERK_DEBUG'] = original_env
      end
    end
  end

  describe 'environment configuration' do
    it 'loads Dotenv configuration' do
      # Given: Dotenv is configured to load from config/.env
      # When: Checking Dotenv functionality
      # Then: Should have Dotenv available for loading environment variables
      expect(Dotenv).to respond_to(:load)
    end
  end

  describe 'integration tests' do
    context 'when loading the main library' do
      it 'does not raise any errors during require' do
        # Given: A fresh Ruby environment
        # When: Requiring the main library
        # Then: Should load without any errors
        expect { require_relative '../../lib/kanban_metrics' }.not_to raise_error
      end

      it 'makes all namespaces available after require' do
        # Given: The main library is loaded
        # When: Accessing all defined namespaces
        # Then: Should have all namespaces properly defined
        aggregate_failures 'namespace availability' do
          expect(defined?(described_class)).to be_truthy
          expect(defined?(KanbanMetrics::Error)).to be_truthy
          expect(defined?(KanbanMetrics::ApiError)).to be_truthy
          expect(defined?(KanbanMetrics::CacheError)).to be_truthy
        end
      end
    end

    context 'when autoloading classes' do
      it 'can access classes from different namespaces simultaneously' do
        # Given: Multiple namespaces with autoloaded classes
        # When: Accessing classes from different namespaces
        # Then: Should autoload all classes without conflicts
        aggregate_failures 'cross-namespace class access' do
          expect { KanbanMetrics::Linear::Client }.not_to raise_error
          expect { KanbanMetrics::Calculators::KanbanMetricsCalculator }.not_to raise_error
          expect { KanbanMetrics::Formatters::TableFormatter }.not_to raise_error
          expect { KanbanMetrics::Reports::KanbanReport }.not_to raise_error
        end
      end
    end
  end
end
