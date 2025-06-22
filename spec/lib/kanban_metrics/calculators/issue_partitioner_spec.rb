# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../../lib/kanban_metrics/calculators/issue_partitioner'

RSpec.describe KanbanMetrics::Calculators::IssuePartitioner do
  # Test data setup using factory-generated hash data
  let(:completed_issues) do
    [
      build(:linear_issue, :completed),
      build(:linear_issue, :completed)
    ]
  end

  let(:in_progress_issues) do
    [
      build(:linear_issue, :in_progress),
      build(:linear_issue, :in_progress)
    ]
  end

  let(:backlog_issues) do
    [
      build(:linear_issue, :backlog),
      build(:linear_issue, :backlog),
      build(:linear_issue, :backlog)
    ]
  end

  let(:all_issues) { completed_issues + in_progress_issues + backlog_issues }

  describe '.partition' do
    context 'when partitioning mixed issues' do
      it 'correctly partitions issues into completed, in_progress, and backlog arrays' do
        # Act
        completed, in_progress, backlog = described_class.partition(all_issues)

        # Assert
        aggregate_failures 'partition sizes and structure' do
          expect(completed).to be_an(Array)
          expect(in_progress).to be_an(Array)
          expect(backlog).to be_an(Array)
          expect(completed.size).to eq(2)
          expect(in_progress.size).to eq(2)
          expect(backlog.size).to eq(3)
        end
      end

      it 'returns Domain::Issue objects in all partitions' do
        # Act
        completed, in_progress, backlog = described_class.partition(all_issues)

        # Assert
        aggregate_failures 'domain object types' do
          expect(completed).to all(be_a(KanbanMetrics::Domain::Issue))
          expect(in_progress).to all(be_a(KanbanMetrics::Domain::Issue))
          expect(backlog).to all(be_a(KanbanMetrics::Domain::Issue))
        end
      end

      it 'correctly partitions completed issues by state type' do
        # Act
        completed, = described_class.partition(all_issues)

        # Assert
        aggregate_failures 'completed issues validation' do
          expect(completed).not_to be_empty
          completed.each do |issue|
            expect(issue.state_type).to eq('completed')
            expect(issue.completed_at).not_to be_nil
          end
        end
      end

      it 'correctly partitions in progress issues by state type' do
        # Act
        _, in_progress, = described_class.partition(all_issues)

        # Assert
        aggregate_failures 'in progress issues validation' do
          expect(in_progress).not_to be_empty
          in_progress.each do |issue|
            expect(issue.state_type).to eq('started')
            expect(issue.started_at).not_to be_nil
          end
        end
      end

      it 'correctly partitions backlog issues by state type' do
        # Act
        _, _, backlog = described_class.partition(all_issues)

        # Assert
        aggregate_failures 'backlog issues validation' do
          expect(backlog).not_to be_empty
          backlog.each do |issue|
            expect(issue.state_type).to eq('backlog')
            expect(issue.completed_at).to be_nil
            expect(issue.started_at).to be_nil
          end
        end
      end

      it 'ensures no issues are lost or duplicated during partitioning' do
        # Act
        completed, in_progress, backlog = described_class.partition(all_issues)

        # Assert
        total_partitioned = completed.size + in_progress.size + backlog.size
        expect(total_partitioned).to eq(all_issues.size)
      end
    end

    context 'when handling edge cases' do
      it 'handles empty issue list gracefully' do
        # Act
        completed, in_progress, backlog = described_class.partition([])

        # Assert
        aggregate_failures 'empty list results' do
          expect(completed).to eq([])
          expect(in_progress).to eq([])
          expect(backlog).to eq([])
          expect(completed).to be_an(Array)
          expect(in_progress).to be_an(Array)
          expect(backlog).to be_an(Array)
        end
      end

      it 'handles nil input gracefully' do
        # Act
        completed, in_progress, backlog = described_class.partition(nil)

        # Assert
        aggregate_failures 'nil input results' do
          expect(completed).to eq([])
          expect(in_progress).to eq([])
          expect(backlog).to eq([])
        end
      end

      it 'treats unknown state types as backlog items' do
        # Arrange
        unknown_issue = build(:linear_issue)
        unknown_issue['state']['type'] = 'unknown'

        # Act
        completed, in_progress, backlog = described_class.partition([unknown_issue])

        # Assert
        aggregate_failures 'unknown state handling' do
          expect(completed).to be_empty
          expect(in_progress).to be_empty
          expect(backlog.size).to eq(1)
          expect(backlog.first.state_type).to eq('unknown')
        end
      end

      it 'correctly handles mixed known and unknown state types' do
        # Arrange
        known_completed = build(:linear_issue, :completed)
        known_in_progress = build(:linear_issue, :in_progress)
        unknown_issue = build(:linear_issue)
        unknown_issue['state']['type'] = 'custom_status'
        mixed_issues = [known_completed, known_in_progress, unknown_issue]

        # Act
        completed, in_progress, backlog = described_class.partition(mixed_issues)

        # Assert
        aggregate_failures 'mixed state types handling' do
          expect(completed.size).to eq(1)
          expect(in_progress.size).to eq(1)
          expect(backlog.size).to eq(1)
          expect(completed.first.state_type).to eq('completed')
          expect(in_progress.first.state_type).to eq('started')
          expect(backlog.first.state_type).to eq('custom_status')
          expect(completed.size + in_progress.size + backlog.size).to eq(mixed_issues.size)
        end
      end

      it 'accepts both raw hash data and Domain::Issue objects as input' do
        # Arrange
        raw_issue = build(:linear_issue, :completed)
        domain_issue = KanbanMetrics::Domain::Issue.new(build(:linear_issue, :in_progress))
        mixed_input = [raw_issue, domain_issue]

        # Act
        completed, in_progress, backlog = described_class.partition(mixed_input)

        # Assert
        aggregate_failures 'mixed input types handling' do
          expect(completed.size).to eq(1)
          expect(in_progress.size).to eq(1)
          expect(backlog).to be_empty
          expect(completed.first).to be_a(KanbanMetrics::Domain::Issue)
          expect(in_progress.first).to be_a(KanbanMetrics::Domain::Issue)
        end
      end
    end

    context 'when validating state classification constants' do
      it 'classifies completed states correctly' do
        # Arrange
        completed_issue = build(:linear_issue, :completed)

        # Act
        completed, = described_class.partition([completed_issue])

        # Assert
        expect(completed.size).to eq(1)
        expect(described_class::COMPLETED_STATES).to include('completed')
      end

      it 'classifies in progress states correctly' do
        # Arrange
        in_progress_issue = build(:linear_issue, :in_progress)

        # Act
        _, in_progress, = described_class.partition([in_progress_issue])

        # Assert
        expect(in_progress.size).to eq(1)
        expect(described_class::IN_PROGRESS_STATES).to include('started')
      end

      it 'classifies backlog states correctly' do
        # Arrange
        backlog_issue = build(:linear_issue, :backlog)

        # Act
        _, _, backlog = described_class.partition([backlog_issue])

        # Assert
        expect(backlog.size).to eq(1)
        expect(described_class::BACKLOG_STATES).to include('backlog')
      end

      it 'has comprehensive state constants' do
        # Assert state constant definitions
        aggregate_failures 'state constants validation' do
          expect(described_class::COMPLETED_STATES).to be_frozen
          expect(described_class::IN_PROGRESS_STATES).to be_frozen
          expect(described_class::BACKLOG_STATES).to be_frozen
          expect(described_class::ALL_KNOWN_STATES).to be_frozen

          expected_all_states = described_class::COMPLETED_STATES +
                                described_class::IN_PROGRESS_STATES +
                                described_class::BACKLOG_STATES
          expect(described_class::ALL_KNOWN_STATES).to eq(expected_all_states)
        end
      end
    end
  end
end
