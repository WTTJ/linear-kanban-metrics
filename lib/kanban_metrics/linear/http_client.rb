# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'
require 'timeout'

module KanbanMetrics
  module Linear
    # Handles HTTP requests to Linear API
    class HttpClient
      API_BASE_URL = 'https://api.linear.app'

      def initialize(api_token)
        @api_token = api_token
      end

      def post(query, variables = {})
        uri = URI("#{API_BASE_URL}/graphql")
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true

        request = Net::HTTP::Post.new(uri)
        request['Authorization'] = @api_token
        request['Content-Type'] = 'application/json'
        request.body = build_request_body(query, variables)

        response = http.request(request)
        handle_response(response)
      rescue Timeout::Error, Errno::ECONNREFUSED, Errno::EHOSTUNREACH, SocketError => e
        raise KanbanMetrics::ApiError, "Network error: #{e.message}"
      end

      # Backward compatibility method for existing application code
      def post_graphql(query, variables = {})
        post(query, variables)
      end

      private

      def build_request_body(query, variables = {})
        body = { query: query }
        body[:variables] = variables unless variables.empty?
        JSON.generate(body)
      end

      def handle_response(response)
        case response.code.to_i
        when 200
          data = JSON.parse(response.body)
          if data['errors']
            error_messages = data['errors'].map { |err| err['message'] }.join(', ')
            raise KanbanMetrics::ApiError, "GraphQL errors: #{error_messages}"
          end
          data
        when 400
          error_details = ''
          begin
            error_data = JSON.parse(response.body)
            error_details = " - #{error_data['errors'].map { |e| e['message'] }.join(', ')}" if error_data['errors']
          rescue JSON::ParserError
            error_details = " - #{response.body}" if ENV['DEBUG']
          end
          raise KanbanMetrics::ApiError, "HTTP #{response.code}: Bad Request#{error_details}"
        when 401
          raise KanbanMetrics::ApiError, "HTTP #{response.code}: Unauthorized - check your API token"
        when 403
          raise KanbanMetrics::ApiError, "HTTP #{response.code}: Forbidden - insufficient permissions"
        when 429
          raise KanbanMetrics::ApiError, "HTTP #{response.code}: Rate limited"
        else
          raise KanbanMetrics::ApiError, "HTTP #{response.code}: #{response.message}"
        end
      rescue JSON::ParserError => e
        raise KanbanMetrics::ApiError, "Invalid JSON response: #{e.message}"
      end
    end
  end
end
