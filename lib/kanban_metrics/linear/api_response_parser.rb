# frozen_string_literal: true

require 'json'

module KanbanMetrics
  module Linear
    # Parses API responses
    class ApiResponseParser
      def initialize(response)
        @response = response
      end

      def parse
        return nil unless response_successful?

        data = parse_json_response
        return nil if data.nil?
        return nil if graphql_errors_present?(data)

        extract_issues_data(data)
      end

      private

      def response_successful?
        if @response.code != '200'
          log_http_error
          return false
        end
        true
      end

      def parse_json_response
        JSON.parse(@response.body)
      rescue JSON::ParserError => e
        log_json_error(e)
        nil
      end

      def graphql_errors_present?(data)
        return false unless data['errors']

        log_graphql_errors(data['errors'])
        true
      end

      def extract_issues_data(data)
        issues_data = data.dig('data', 'issues')
        return nil unless issues_data

        {
          issues: issues_data['nodes'] || [],
          page_info: normalize_page_info(issues_data['pageInfo'] || {})
        }
      end

      def normalize_page_info(page_info)
        {
          has_next_page: page_info['hasNextPage'] || false,
          end_cursor: page_info['endCursor']
        }
      end

      def log_http_error
        puts "❌ HTTP Error: #{@response.code} - #{@response.message}"
        puts "Response body: #{@response.body}" if ENV['DEBUG']
      end

      def log_json_error(error)
        puts "❌ JSON Parse Error: #{error.message}" if ENV['DEBUG']
      end

      def log_graphql_errors(errors)
        puts '❌ GraphQL errors:'
        errors.each { |error| puts "  - #{error['message']}" }
      end
    end
  end
end
