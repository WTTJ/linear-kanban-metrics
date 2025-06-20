# frozen_string_literal: true

module KanbanMetrics
  module Calculators
    # Handles issue partitioning by status
    class IssuePartitioner
      def self.partition(issues)
        completed = issues.select { |i| completed_status?(i) }
        in_progress = issues.select { |i| in_progress_status?(i) }
        backlog = issues.reject { |i| completed_status?(i) || in_progress_status?(i) }
        [completed, in_progress, backlog]
      end

      private_class_method def self.completed_status?(issue)
        issue.dig('state', 'type') == 'completed'
      end

      private_class_method def self.in_progress_status?(issue)
        issue.dig('state', 'type') == 'started'
      end

      private_class_method def self.backlog_status?(issue)
        %w[backlog unstarted].include?(issue.dig('state', 'type'))
      end
    end
  end
end
