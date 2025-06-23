# frozen_string_literal: true

require 'json'

module KanbanMetrics
  module Linear
    # Configuration for API response handling
    module ResponseConfig
      SUCCESS_CODE = '200'
    end

    # Validates HTTP response status
    class HttpResponseValidator
      include ResponseConfig

      def initialize(response)
        @response = response
      end

      def valid?
        return true if success_response?

        ErrorLogger.log_http_error(@response)
        false
      end

      private

      def success_response?
        @response.code == SUCCESS_CODE
      end
    end

    # Parses JSON response bodies
    class JsonResponseParser
      def self.parse(response_body)
        JSON.parse(response_body)
      rescue JSON::ParserError => e
        ErrorLogger.log_json_error(e)
        nil
      end
    end

    # Validates GraphQL responses for errors
    class GraphqlErrorValidator
      def self.valid?(data)
        return true unless errors_present?(data)

        ErrorLogger.log_graphql_errors(data['errors'])
        false
      end

      private_class_method def self.errors_present?(data)
        data['errors']&.any?
      end
    end

    # Extracts and normalizes issues data from GraphQL response
    class IssuesDataExtractor
      def self.extract(data)
        issues_data = data.dig('data', 'issues')
        return nil unless issues_data

        {
          issues: issues_data['nodes'] || [],
          page_info: PageInfoNormalizer.normalize(issues_data['pageInfo'] || {})
        }
      end
    end

    # Normalizes GraphQL pageInfo structure
    class PageInfoNormalizer
      def self.normalize(page_info)
        {
          has_next_page: page_info['hasNextPage'] || false,
          end_cursor: page_info['endCursor']
        }
      end
    end

    # Handles error logging with consistent formatting
    class ErrorLogger
      def self.log_http_error(response)
        puts "❌ HTTP Error: #{response.code} - #{response.message}"
        puts "Response body: #{response.body}" if debug_mode?
      end

      def self.log_json_error(error)
        puts "❌ JSON Parse Error: #{error.message}" if debug_mode?
      end

      def self.log_graphql_errors(errors)
        puts '❌ GraphQL errors:'
        errors.each { |error| puts "  - #{error['message']}" }
      end

      private_class_method def self.debug_mode?
        ENV.fetch('DEBUG', nil)
      end
    end

    # Main orchestrator for API response parsing
    class ApiResponseParser
      def initialize(response)
        @response = response
        @validator = HttpResponseValidator.new(response)
      end

      def parse
        return nil unless @validator.valid?

        data = JsonResponseParser.parse(@response.body)
        return nil unless data
        return nil unless GraphqlErrorValidator.valid?(data)

        IssuesDataExtractor.extract(data)
      end
    end
  end
end
