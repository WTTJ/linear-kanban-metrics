# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'KanbanMetrics Integration' do
  describe 'module loading' do
    context 'when loading the main KanbanMetrics module' do
      it 'loads successfully and defines core structure' do
        # Arrange
        # (KanbanMetrics should be available through autoloading)

        # Act
        # (module loading happens automatically)

        # Assert
        expect(KanbanMetrics).to be_a(Module)

        # Cleanup
        # (no cleanup needed for module loading)
      end
    end

    context 'when checking error class hierarchy' do
      it 'defines proper error class inheritance' do
        # Arrange
        # (error classes should be available through autoloading)

        # Act
        # (class loading happens automatically)

        # Assert
        aggregate_failures 'error class hierarchy' do
          expect(KanbanMetrics::Error).to be < StandardError
          expect(KanbanMetrics::ApiError).to be < KanbanMetrics::Error
          expect(KanbanMetrics::CacheError).to be < KanbanMetrics::Error
        end

        # Cleanup
        # (no cleanup needed for class definitions)
      end
    end
  end

  describe 'Zeitwerk autoloading' do
    context 'when loading core classes' do
      it 'successfully autoloads QueryOptions' do
        # Arrange
        # (Zeitwerk should handle autoloading)

        # Act
        query_options_class = KanbanMetrics::QueryOptions

        # Assert
        expect(query_options_class).to be_a(Class)

        # Cleanup
        # (no cleanup needed for autoloaded classes)
      end
    end

    context 'when loading Linear module classes' do
      it 'successfully autoloads all Linear-related classes' do
        # Arrange
        # (Zeitwerk should handle autoloading)

        # Act & Assert
        aggregate_failures 'Linear module class loading' do
          expect(KanbanMetrics::Linear::HttpClient).to be_a(Class)
          expect(KanbanMetrics::Linear::Cache).to be_a(Class)
          expect(KanbanMetrics::Linear::Client).to be_a(Class)
        end

        # Cleanup
        # (no cleanup needed for autoloaded classes)
      end
    end

    context 'when loading Calculator classes' do
      it 'successfully autoloads all Calculator classes' do
        # Arrange
        # (Zeitwerk should handle autoloading)

        # Act & Assert
        aggregate_failures 'Calculator class loading' do
          expect(KanbanMetrics::Calculators::IssuePartitioner).to be_a(Class)
          expect(KanbanMetrics::Calculators::KanbanMetricsCalculator).to be_a(Class)
        end

        # Cleanup
        # (no cleanup needed for autoloaded classes)
      end
    end

    context 'when loading Formatter classes' do
      it 'successfully autoloads all Formatter classes' do
        # Arrange
        # (Zeitwerk should handle autoloading)

        # Act & Assert
        aggregate_failures 'Formatter class loading' do
          expect(KanbanMetrics::Formatters::TableFormatter).to be_a(Class)
          expect(KanbanMetrics::Formatters::JsonFormatter).to be_a(Class)
          expect(KanbanMetrics::Formatters::CsvFormatter).to be_a(Class)
        end

        # Cleanup
        # (no cleanup needed for autoloaded classes)
      end
    end
  end

  describe 'version information' do
    context 'when checking version constant' do
      it 'defines a version string constant' do
        # Arrange
        # (VERSION constant should be defined)

        # Act
        version = KanbanMetrics::VERSION

        # Assert
        aggregate_failures 'version constant validation' do
          expect(version).to be_a(String)
          expect(version).not_to be_empty
          expect(version).to match(/\A\d+\.\d+\.\d+/)
        end

        # Cleanup
        # (no cleanup needed for constants)
      end
    end
  end
end
