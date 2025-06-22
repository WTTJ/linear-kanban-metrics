# frozen_string_literal: true

require 'date'

module KanbanMetrics
  module Domain
    # Domain object representing a Linear issue with calculated properties
    class Issue
      attr_reader :raw_data

      def initialize(issue_data)
        # Prevent double-wrapping: if we already have a Domain::Issue, use its raw_data
        @raw_data = issue_data.is_a?(Domain::Issue) ? issue_data.raw_data : issue_data
      end

      # Core Linear fields
      def id
        @raw_data['id']
      end

      def identifier
        @raw_data['identifier']
      end

      def title
        @raw_data['title']
      end

      def priority
        @raw_data['priority']
      end

      def estimate
        @raw_data['estimate']
      end

      # State information
      def state_name
        @raw_data.dig('state', 'name')
      end

      def state_type
        @raw_data.dig('state', 'type')
      end

      # Team and assignee
      def team_name
        @raw_data.dig('team', 'name')
      end

      def assignee_name
        @raw_data.dig('assignee', 'name')
      end

      # Timestamps
      def created_at
        parse_timestamp(@raw_data['createdAt'])
      end

      def updated_at
        parse_timestamp(@raw_data['updatedAt'])
      end

      def started_at
        parse_timestamp(@raw_data['startedAt']) || find_history_start_time
      end

      def completed_at
        parse_timestamp(@raw_data['completedAt'])
      end

      def archived_at
        parse_timestamp(@raw_data['archivedAt'])
      end

      # Calculated properties
      def cycle_time_days
        return nil unless started_at && completed_at

        (completed_at - started_at).to_f.round(2)
      end

      def lead_time_days
        return nil unless created_at && completed_at

        (completed_at - created_at).to_f.round(2)
      end

      # Status checks
      def completed?
        !completed_at.nil?
      end

      def in_progress?
        started_at && !completed_at
      end

      def backlog?
        !started_at && !completed_at
      end

      private

      def parse_timestamp(timestamp_str)
        return nil unless timestamp_str

        DateTime.parse(timestamp_str)
      rescue StandardError
        nil
      end

      def find_history_start_time
        event = @raw_data.dig('history', 'nodes')&.find do |e|
          e.dig('toState', 'type') == 'started'
        end
        parse_timestamp(event&.dig('createdAt'))
      end
    end
  end
end
