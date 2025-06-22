# frozen_string_literal: true

module KanbanMetrics
  module Calculators
    # Partitions issues into different categories based on their workflow state
    #
    # This class provides functionality to categorize issues into:
    # - Completed: Issues that have been finished
    # - In Progress: Issues currently being worked on
    # - Backlog: Issues waiting to be started or in preliminary states
    class IssuePartitioner
      # State types for different workflow stages
      COMPLETED_STATES = %w[completed].freeze
      IN_PROGRESS_STATES = %w[started].freeze
      BACKLOG_STATES = %w[backlog unstarted].freeze

      # All known state types for validation
      ALL_KNOWN_STATES = (COMPLETED_STATES + IN_PROGRESS_STATES + BACKLOG_STATES).freeze

      # Partitions a collection of issues into workflow categories
      #
      # @param issues [Array] Collection of issue data (raw hashes or Domain::Issue objects)
      # @return [Array<Array, Array, Array>] Tuple of [completed, in_progress, backlog] arrays
      def self.partition(issues)
        return [[], [], []] if issues.nil? || issues.empty?

        domain_issues = normalize_to_domain_objects(issues)

        PartitionResult.new(domain_issues).to_arrays
      end

      private_class_method def self.normalize_to_domain_objects(issues)
        issues.map { |issue| ensure_domain_object(issue) }
      end

      private_class_method def self.ensure_domain_object(issue)
        issue.is_a?(Domain::Issue) ? issue : Domain::Issue.new(issue)
      end

      # Result object that encapsulates partitioning logic
      class PartitionResult
        def initialize(domain_issues)
          @issues = domain_issues
        end

        def to_arrays
          [completed_issues, in_progress_issues, backlog_issues]
        end

        def completed_issues
          @completed_issues ||= select_by_state_types(COMPLETED_STATES)
        end

        def in_progress_issues
          @in_progress_issues ||= select_by_state_types(IN_PROGRESS_STATES)
        end

        def backlog_issues
          @backlog_issues ||= @issues.reject { |issue| completed?(issue) || in_progress?(issue) }
        end

        private

        def select_by_state_types(state_types)
          @issues.select { |issue| state_types.include?(extract_state_type(issue)) }
        end

        def completed?(issue)
          COMPLETED_STATES.include?(extract_state_type(issue))
        end

        def in_progress?(issue)
          IN_PROGRESS_STATES.include?(extract_state_type(issue))
        end

        def extract_state_type(issue)
          issue.state_type || 'unknown'
        end
      end
    end
  end
end
