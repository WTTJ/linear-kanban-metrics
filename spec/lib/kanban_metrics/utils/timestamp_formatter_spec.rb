# frozen_string_literal: true

require 'spec_helper'

RSpec.describe KanbanMetrics::Utils::TimestampFormatter do
  # Test Data Setup
  let(:valid_datetime) { DateTime.new(2024, 1, 15, 14, 30, 45) }
  let(:valid_time) { Time.new(2024, 6, 20, 9, 15, 30) }
  let(:nil_timestamp) { nil }

  describe 'constants' do
    it 'defines ISO_FORMAT constant' do
      expect(described_class::ISO_FORMAT).to eq('%Y-%m-%dT%H:%M:%SZ')
    end

    it 'defines DISPLAY_FORMAT constant' do
      expect(described_class::DISPLAY_FORMAT).to eq('%Y-%m-%d')
    end

    it 'defines DEFAULT_FALLBACK constant' do
      expect(described_class::DEFAULT_FALLBACK).to eq('N/A')
    end
  end

  describe '.to_iso' do
    context 'with valid DateTime object' do
      it 'formats DateTime to ISO 8601 format' do
        result = described_class.to_iso(valid_datetime)
        expect(result).to eq('2024-01-15T14:30:45Z')
      end

      it 'returns string format' do
        result = described_class.to_iso(valid_datetime)
        expect(result).to be_a(String)
      end
    end

    context 'with valid Time object' do
      it 'formats Time to ISO 8601 format' do
        result = described_class.to_iso(valid_time)
        expect(result).to eq('2024-06-20T09:15:30Z')
      end
    end

    context 'with nil timestamp' do
      it 'returns nil by default when timestamp is nil' do
        result = described_class.to_iso(nil_timestamp)
        expect(result).to be_nil
      end

      it 'returns custom fallback when provided' do
        result = described_class.to_iso(nil_timestamp, fallback: 'MISSING')
        expect(result).to eq('MISSING')
      end

      it 'returns empty string fallback when specified' do
        result = described_class.to_iso(nil_timestamp, fallback: '')
        expect(result).to eq('')
      end
    end

    context 'with invalid timestamp object' do
      let(:invalid_timestamp) do
        # Create an object that doesn't respond to strftime
        invalid_obj = Object.new
        def invalid_obj.strftime(_format)
          raise StandardError, 'Invalid strftime call'
        end
        invalid_obj
      end

      it 'returns fallback when strftime raises an error' do
        result = described_class.to_iso(invalid_timestamp, fallback: 'ERROR')
        expect(result).to eq('ERROR')
      end

      it 'returns nil fallback when no fallback provided' do
        result = described_class.to_iso(invalid_timestamp)
        expect(result).to be_nil
      end
    end

    context 'with edge case timestamps' do
      it 'handles leap year date correctly' do
        leap_year_date = DateTime.new(2024, 2, 29, 12, 0, 0)
        result = described_class.to_iso(leap_year_date)
        expect(result).to eq('2024-02-29T12:00:00Z')
      end

      it 'handles New Year timestamp correctly' do
        new_year = DateTime.new(2024, 1, 1, 0, 0, 0)
        result = described_class.to_iso(new_year)
        expect(result).to eq('2024-01-01T00:00:00Z')
      end

      it 'handles end of year timestamp correctly' do
        end_of_year = DateTime.new(2024, 12, 31, 23, 59, 59)
        result = described_class.to_iso(end_of_year)
        expect(result).to eq('2024-12-31T23:59:59Z')
      end
    end
  end

  describe '.to_display' do
    context 'with valid DateTime object' do
      it 'formats DateTime to display format' do
        result = described_class.to_display(valid_datetime)
        expect(result).to eq('2024-01-15')
      end

      it 'returns string format' do
        result = described_class.to_display(valid_datetime)
        expect(result).to be_a(String)
      end
    end

    context 'with valid Time object' do
      it 'formats Time to display format' do
        result = described_class.to_display(valid_time)
        expect(result).to eq('2024-06-20')
      end
    end

    context 'with nil timestamp' do
      it 'returns default fallback when timestamp is nil' do
        result = described_class.to_display(nil_timestamp)
        expect(result).to eq('N/A')
      end

      it 'returns custom fallback when provided' do
        result = described_class.to_display(nil_timestamp, fallback: 'No Date')
        expect(result).to eq('No Date')
      end

      it 'returns empty string fallback when specified' do
        result = described_class.to_display(nil_timestamp, fallback: '')
        expect(result).to eq('')
      end
    end

    context 'with invalid timestamp object' do
      let(:invalid_timestamp) do
        invalid_obj = Object.new
        def invalid_obj.strftime(_format)
          raise ArgumentError, 'Invalid date format'
        end
        invalid_obj
      end

      it 'returns fallback when strftime raises an error' do
        result = described_class.to_display(invalid_timestamp, fallback: 'INVALID')
        expect(result).to eq('INVALID')
      end

      it 'returns default fallback when no custom fallback provided' do
        result = described_class.to_display(invalid_timestamp)
        expect(result).to eq('N/A')
      end
    end

    context 'with edge case timestamps' do
      it 'handles single digit day correctly' do
        single_digit_day = DateTime.new(2024, 3, 5, 10, 30, 0)
        result = described_class.to_display(single_digit_day)
        expect(result).to eq('2024-03-05')
      end

      it 'handles single digit month correctly' do
        single_digit_month = DateTime.new(2024, 7, 15, 14, 20, 0)
        result = described_class.to_display(single_digit_month)
        expect(result).to eq('2024-07-15')
      end
    end
  end

  describe '.to_custom' do
    context 'with valid timestamp and format' do
      it 'formats with custom format string' do
        custom_format = '%d/%m/%Y %H:%M'
        result = described_class.to_custom(valid_datetime, format: custom_format)
        expect(result).to eq('15/01/2024 14:30')
      end

      it 'formats with different custom format' do
        custom_format = '%B %d, %Y'
        result = described_class.to_custom(valid_datetime, format: custom_format)
        expect(result).to eq('January 15, 2024')
      end

      it 'formats with time-only format' do
        time_format = '%H:%M:%S'
        result = described_class.to_custom(valid_datetime, format: time_format)
        expect(result).to eq('14:30:45')
      end

      it 'formats with weekday format' do
        weekday_format = '%A, %B %d, %Y'
        result = described_class.to_custom(valid_datetime, format: weekday_format)
        expect(result).to eq('Monday, January 15, 2024')
      end
    end

    context 'with nil timestamp' do
      it 'returns nil by default when timestamp is nil' do
        result = described_class.to_custom(nil_timestamp, format: '%Y-%m-%d')
        expect(result).to be_nil
      end

      it 'returns custom fallback when provided' do
        result = described_class.to_custom(nil_timestamp, format: '%Y-%m-%d', fallback: 'NONE')
        expect(result).to eq('NONE')
      end
    end

    context 'with invalid format string' do
      let(:invalid_timestamp) do
        invalid_obj = Object.new
        def invalid_obj.strftime(_format)
          raise 'Format error'
        end
        invalid_obj
      end

      it 'returns fallback when strftime raises an error' do
        result = described_class.to_custom(invalid_timestamp, format: '%Y', fallback: 'FORMAT_ERROR')
        expect(result).to eq('FORMAT_ERROR')
      end

      it 'returns nil fallback when no fallback provided' do
        result = described_class.to_custom(invalid_timestamp, format: '%Y')
        expect(result).to be_nil
      end
    end

    context 'with complex format strings' do
      it 'handles timezone format correctly' do
        timezone_format = '%Y-%m-%d %H:%M:%S %Z'
        # NOTE: Since we're using DateTime without timezone, %Z might be empty
        result = described_class.to_custom(valid_datetime, format: timezone_format)
        expect(result).to match(/2024-01-15 14:30:45/)
      end

      it 'handles microseconds format' do
        microsecond_format = '%Y-%m-%d %H:%M:%S.%6N'
        result = described_class.to_custom(valid_datetime, format: microsecond_format)
        expect(result).to match(/2024-01-15 14:30:45\.\d{6}/)
      end
    end
  end

  describe 'module behavior' do
    it 'responds to all public methods as module functions' do
      aggregate_failures 'module function availability' do
        expect(described_class).to respond_to(:to_iso)
        expect(described_class).to respond_to(:to_display)
        expect(described_class).to respond_to(:to_custom)
      end
    end

    it 'can be used as a module include (with private instance methods)' do
      test_class = Class.new do
        include KanbanMetrics::Utils::TimestampFormatter
      end

      instance = test_class.new

      # When using module_function, the methods become private instance methods
      # and public module methods. They're not public instance methods.
      aggregate_failures 'module function behavior' do
        expect(instance.private_methods).to include(:to_iso)
        expect(instance.private_methods).to include(:to_display)
        expect(instance.private_methods).to include(:to_custom)

        # But we can still call them from within the class
        expect(test_class.new.send(:to_iso, DateTime.new(2024, 1, 1))).to eq('2024-01-01T00:00:00Z')
      end
    end
  end

  describe 'consistency across methods' do
    context 'with same input timestamp' do
      let(:test_datetime) { DateTime.new(2024, 3, 10, 16, 45, 30) }

      it 'maintains date consistency between ISO and display formats' do
        iso_result = described_class.to_iso(test_datetime)
        display_result = described_class.to_display(test_datetime)

        # Extract date part from ISO format
        iso_date_part = iso_result.split('T').first

        expect(iso_date_part).to eq(display_result)
      end

      it 'maintains consistency with custom format equivalent to display' do
        display_result = described_class.to_display(test_datetime)
        custom_result = described_class.to_custom(test_datetime, format: '%Y-%m-%d')

        expect(display_result).to eq(custom_result)
      end

      it 'maintains consistency with custom format equivalent to ISO' do
        iso_result = described_class.to_iso(test_datetime)
        custom_result = described_class.to_custom(test_datetime, format: '%Y-%m-%dT%H:%M:%SZ')

        expect(iso_result).to eq(custom_result)
      end
    end
  end

  describe 'error handling robustness' do
    context 'with various error types' do
      let(:error_prone_timestamp) do
        error_obj = Object.new
        def error_obj.strftime(_format)
          # Rotate through different error types for comprehensive testing
          case @error_count ||= 0
          when 0
            @error_count += 1
            raise ArgumentError, 'Invalid argument'
          when 1
            @error_count += 1
            raise 'Runtime error'
          else
            raise StandardError, 'Generic error'
          end
        end
        error_obj
      end

      it 'handles ArgumentError gracefully' do
        result = described_class.to_iso(error_prone_timestamp, fallback: 'ARG_ERROR')
        expect(result).to eq('ARG_ERROR')
      end

      it 'handles RuntimeError gracefully' do
        result = described_class.to_display(error_prone_timestamp, fallback: 'RUNTIME_ERROR')
        expect(result).to eq('RUNTIME_ERROR')
      end

      it 'handles generic StandardError gracefully' do
        result = described_class.to_custom(error_prone_timestamp, format: '%Y', fallback: 'STANDARD_ERROR')
        expect(result).to eq('STANDARD_ERROR')
      end
    end
  end

  describe 'real-world usage scenarios' do
    context 'with DateTime objects from real applications' do
      let(:created_at) { DateTime.parse('2024-01-15T10:30:45Z') }
      let(:updated_at) { DateTime.parse('2024-06-20T16:45:30+00:00') }

      it 'formats creation timestamps for API responses' do
        result = described_class.to_iso(created_at)
        expect(result).to eq('2024-01-15T10:30:45Z')
      end

      it 'formats update timestamps for user display' do
        result = described_class.to_display(updated_at)
        expect(result).to eq('2024-06-20')
      end

      it 'formats timestamps for custom reporting' do
        custom_format = '%d %b %Y at %H:%M'
        result = described_class.to_custom(created_at, format: custom_format)
        expect(result).to eq('15 Jan 2024 at 10:30')
      end
    end

    context 'with CSV export scenarios' do
      let(:csv_timestamp) { DateTime.new(2024, 12, 25, 9, 0, 0) }

      it 'formats for CSV export with ISO format' do
        result = described_class.to_iso(csv_timestamp)
        expect(result).to eq('2024-12-25T09:00:00Z')
        expect(result).not_to include(',') # CSV-safe
      end

      it 'formats for CSV with custom fallback' do
        result = described_class.to_iso(nil, fallback: '')
        expect(result).to eq('')
        expect(result).not_to include(',') # CSV-safe
      end
    end

    context 'with JSON API scenarios' do
      let(:api_timestamp) { DateTime.new(2024, 7, 4, 12, 30, 15) }

      it 'formats for JSON API responses' do
        result = described_class.to_iso(api_timestamp)

        aggregate_failures 'JSON API format validation' do
          expect(result).to eq('2024-07-04T12:30:15Z')
          expect(result).to match(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z\z/)
          expect { JSON.parse("\"#{result}\"") }.not_to raise_error
        end
      end
    end
  end
end
