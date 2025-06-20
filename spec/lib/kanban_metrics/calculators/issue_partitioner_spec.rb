# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../../lib/kanban_metrics/calculators/issue_partitioner'

RSpec.describe KanbanMetrics::Calculators::IssuePartitioner do
  # Arrange - Test data setup
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
      it 'correctly partitions issues into completed, in_progress, and backlog' do
        # Arrange
        issues = all_issues

        # Act
        completed, in_progress, backlog = described_class.partition(issues)

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

      it 'correctly identifies completed issues' do
        # Arrange
        issues = all_issues

        # Act
        completed, = described_class.partition(issues)

        # Assert
        aggregate_failures 'completed issues validation' do
          expect(completed).not_to be_empty
          completed.each do |issue|
            expect(issue['state']['type']).to eq('completed')
            expect(issue).to have_key('completedAt')
          end
        end
      end

      it 'correctly identifies in progress issues' do
        # Arrange
        issues = all_issues

        # Act
        _, in_progress, = described_class.partition(issues)

        # Assert
        aggregate_failures 'in progress issues validation' do
          expect(in_progress).not_to be_empty
          in_progress.each do |issue|
            expect(issue['state']['type']).to eq('started')
            expect(issue).to have_key('startedAt')
          end
        end
      end

      it 'correctly identifies backlog issues' do
        # Arrange
        issues = all_issues

        # Act
        _, _, backlog = described_class.partition(issues)

        # Assert
        aggregate_failures 'backlog issues validation' do
          expect(backlog).not_to be_empty
          backlog.each do |issue|
            expect(issue['state']['type']).to eq('backlog')
            expect(issue).not_to have_key('completedAt')
            expect(issue).not_to have_key('startedAt')
          end
        end
      end
    end

    context 'when handling edge cases' do
      it 'handles empty issue list' do
        # Arrange
        empty_issues = []

        # Act
        completed, in_progress, backlog = described_class.partition(empty_issues)

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

      it 'handles issues with unknown state types' do
        # Arrange
        unknown_issue = build(:linear_issue)
        unknown_issue['state']['type'] = 'unknown'
        issues_with_unknown = [unknown_issue]

        # Act
        completed, in_progress, backlog = described_class.partition(issues_with_unknown)

        # Assert
        aggregate_failures 'unknown state handling' do
          expect(completed).to eq([])
          expect(in_progress).to eq([])
          expect(backlog).to eq([unknown_issue])
          expect(backlog.first['state']['type']).to eq('unknown')
        end
      end

      it 'handles mixed known and unknown state types' do
        # Arrange
        known_issue = build(:linear_issue, :completed)
        unknown_issue = build(:linear_issue)
        unknown_issue['state']['type'] = 'custom_status'
        mixed_issues = [known_issue, unknown_issue]

        # Act
        completed, in_progress, backlog = described_class.partition(mixed_issues)

        # Assert
        aggregate_failures 'mixed state types handling' do
          expect(completed).to eq([known_issue])
          expect(in_progress).to eq([])
          expect(backlog).to eq([unknown_issue])
          expect(completed.size + in_progress.size + backlog.size).to eq(mixed_issues.size)
        end
      end
    end
  end

  describe 'private methods' do
    describe '.completed_status?' do
      context 'when checking completed status' do
        it 'returns true for completed issues' do
          # Arrange
          issue = build(:linear_issue, :completed)

          # Act
          result = described_class.send(:completed_status?, issue)

          # Assert
          aggregate_failures 'completed status validation' do
            expect(result).to be true
            expect(issue['state']['type']).to eq('completed')
          end
        end

        it 'returns false for non-completed issues' do
          # Arrange
          in_progress_issue = build(:linear_issue, :in_progress)
          backlog_issue = build(:linear_issue, :backlog)

          # Act
          in_progress_result = described_class.send(:completed_status?, in_progress_issue)
          backlog_result = described_class.send(:completed_status?, backlog_issue)

          # Assert
          aggregate_failures 'non-completed status validation' do
            expect(in_progress_result).to be false
            expect(backlog_result).to be false
            expect(in_progress_issue['state']['type']).not_to eq('completed')
            expect(backlog_issue['state']['type']).not_to eq('completed')
          end
        end
      end
    end

    describe '.in_progress_status?' do
      context 'when checking in progress status' do
        it 'returns true for in progress issues' do
          # Arrange
          issue = build(:linear_issue, :in_progress)

          # Act
          result = described_class.send(:in_progress_status?, issue)

          # Assert
          aggregate_failures 'in progress status validation' do
            expect(result).to be true
            expect(issue['state']['type']).to eq('started')
          end
        end

        it 'returns false for non-in-progress issues' do
          # Arrange
          completed_issue = build(:linear_issue, :completed)
          backlog_issue = build(:linear_issue, :backlog)

          # Act
          completed_result = described_class.send(:in_progress_status?, completed_issue)
          backlog_result = described_class.send(:in_progress_status?, backlog_issue)

          # Assert
          aggregate_failures 'non-in-progress status validation' do
            expect(completed_result).to be false
            expect(backlog_result).to be false
            expect(completed_issue['state']['type']).not_to eq('started')
            expect(backlog_issue['state']['type']).not_to eq('started')
          end
        end
      end
    end

    describe '.backlog_status?' do
      context 'when checking backlog status' do
        it 'returns true for backlog issues' do
          # Arrange
          issue = build(:linear_issue, :backlog)

          # Act
          result = described_class.send(:backlog_status?, issue)

          # Assert
          aggregate_failures 'backlog status validation' do
            expect(result).to be true
            expect(issue['state']['type']).to eq('backlog')
          end
        end

        it 'returns false for non-backlog issues' do
          # Arrange
          completed_issue = build(:linear_issue, :completed)
          in_progress_issue = build(:linear_issue, :in_progress)

          # Act
          completed_result = described_class.send(:backlog_status?, completed_issue)
          in_progress_result = described_class.send(:backlog_status?, in_progress_issue)

          # Assert
          aggregate_failures 'non-backlog status validation' do
            expect(completed_result).to be false
            expect(in_progress_result).to be false
            expect(completed_issue['state']['type']).not_to eq('backlog')
            expect(in_progress_issue['state']['type']).not_to eq('backlog')
          end
        end
      end
    end
  end
end
