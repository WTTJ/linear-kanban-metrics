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
end
