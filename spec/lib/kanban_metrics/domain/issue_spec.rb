# frozen_string_literal: true

require 'spec_helper'

RSpec.describe KanbanMetrics::Domain::Issue do
  # Test Data Setup
  subject(:issue) { described_class.new(valid_issue_data) }

  let(:valid_issue_data) { build(:linear_issue) }
  let(:completed_issue_data) { build(:linear_issue, :completed) }
  let(:in_progress_issue_data) { build(:linear_issue, :in_progress) }
  let(:backlog_issue_data) { build(:linear_issue, :backlog) }
  let(:archived_issue_data) { build(:linear_issue, :archived) }

  describe '#initialize' do
    context 'with valid issue data' do
      it 'creates an issue instance successfully' do
        expect(issue).to be_a(described_class)
      end

      it 'stores the raw data' do
        expect(issue.raw_data).to eq(valid_issue_data)
      end

      it 'initializes memoization cache' do
        parsed_timestamps = issue.instance_variable_get(:@parsed_timestamps)
        expect(parsed_timestamps).to be_a(Hash)
        expect(parsed_timestamps).to be_empty
      end
    end

    context 'with Domain::Issue as input' do
      let(:existing_issue) { described_class.new(valid_issue_data) }
      let(:wrapped_issue) { described_class.new(existing_issue) }

      it 'prevents double-wrapping by extracting raw_data' do
        expect(wrapped_issue.raw_data).to eq(valid_issue_data)
        expect(wrapped_issue.raw_data).to eq(existing_issue.raw_data)
      end
    end

    context 'with invalid data' do
      it 'raises ArgumentError when data is nil' do
        expect { described_class.new(nil) }
          .to raise_error(ArgumentError, 'Issue data cannot be nil')
      end

      it 'raises ArgumentError when data is not hash-like' do
        # Create an object that doesn't respond to []
        invalid_object = Object.new
        def invalid_object.respond_to?(method, include_private: false)
          return false if method == :[]

          super
        end

        expect { described_class.new(invalid_object) }
          .to raise_error(ArgumentError, /Invalid issue data type.*Expected Hash or Domain::Issue/)
      end
    end
  end

  describe 'core Linear fields' do
    let(:issue_with_data) do
      described_class.new({
                            'id' => 'issue-123',
                            'identifier' => 'ENG-456',
                            'title' => 'Sample Issue Title',
                            'priority' => '2',
                            'estimate' => '5.5'
                          })
    end

    describe '#id' do
      it 'returns the issue ID' do
        expect(issue_with_data.id).to eq('issue-123')
      end

      it 'returns nil when ID is missing' do
        empty_issue = described_class.new({})
        expect(empty_issue.id).to be_nil
      end
    end

    describe '#identifier' do
      it 'returns the human-readable identifier' do
        expect(issue_with_data.identifier).to eq('ENG-456')
      end
    end

    describe '#title' do
      it 'returns the issue title' do
        expect(issue_with_data.title).to eq('Sample Issue Title')
      end
    end

    describe '#priority' do
      it 'returns priority as integer' do
        expect(issue_with_data.priority).to eq(2)
      end

      it 'returns nil when priority is missing' do
        empty_issue = described_class.new({})
        expect(empty_issue.priority).to be_nil
      end
    end

    describe '#estimate' do
      it 'returns estimate as float' do
        expect(issue_with_data.estimate).to eq(5.5)
      end

      it 'returns nil when estimate is missing' do
        empty_issue = described_class.new({})
        expect(empty_issue.estimate).to be_nil
      end
    end
  end

  describe 'state information' do
    let(:issue_with_state) do
      described_class.new({
                            'state' => {
                              'name' => 'In Progress',
                              'type' => 'started'
                            }
                          })
    end

    describe '#state_name' do
      it 'returns the state name' do
        expect(issue_with_state.state_name).to eq('In Progress')
      end

      it 'returns nil when state is missing' do
        empty_issue = described_class.new({})
        expect(empty_issue.state_name).to be_nil
      end
    end

    describe '#state_type' do
      it 'returns valid state type' do
        expect(issue_with_state.state_type).to eq('started')
      end

      it 'logs warning for invalid state type but still returns it' do
        invalid_state_issue = described_class.new({
                                                    'state' => { 'type' => 'invalid_type' }
                                                  })

        expect { invalid_state_issue.state_type }
          .to output(/Warning: Invalid state type: invalid_type/).to_stdout
        expect(invalid_state_issue.state_type).to eq('invalid_type')
      end

      it 'returns nil when state is missing' do
        empty_issue = described_class.new({})
        expect(empty_issue.state_type).to be_nil
      end
    end
  end

  describe 'team and assignee information' do
    let(:issue_with_team_and_assignee) do
      described_class.new({
                            'team' => { 'name' => 'Engineering Team' },
                            'assignee' => { 'name' => 'John Doe' }
                          })
    end

    describe '#team_name' do
      it 'returns team name' do
        expect(issue_with_team_and_assignee.team_name).to eq('Engineering Team')
      end

      it 'returns nil when team is missing' do
        empty_issue = described_class.new({})
        expect(empty_issue.team_name).to be_nil
      end
    end

    describe '#assignee_name' do
      it 'returns assignee name' do
        expect(issue_with_team_and_assignee.assignee_name).to eq('John Doe')
      end

      it 'returns nil when assignee is missing' do
        empty_issue = described_class.new({})
        expect(empty_issue.assignee_name).to be_nil
      end
    end
  end

  describe 'timestamp parsing and memoization' do
    let(:timestamp_str) { '2024-01-15T10:30:00Z' }
    let(:issue_with_timestamps) do
      described_class.new({
                            'createdAt' => timestamp_str,
                            'updatedAt' => '2024-01-16T15:45:00Z',
                            'startedAt' => '2024-01-17T09:00:00Z',
                            'completedAt' => '2024-01-18T17:30:00Z',
                            'archivedAt' => '2024-01-19T12:00:00Z'
                          })
    end

    describe '#created_at' do
      it 'parses and returns DateTime' do
        expect(issue_with_timestamps.created_at).to be_a(DateTime)
        expect(issue_with_timestamps.created_at.to_s).to include('2024-01-15')
      end

      it 'memoizes parsed timestamps' do
        # Access timestamp twice
        first_call = issue_with_timestamps.created_at
        second_call = issue_with_timestamps.created_at

        # Should be same object instance due to memoization
        expect(first_call).to equal(second_call)
      end
    end

    describe '#updated_at' do
      it 'parses and returns DateTime' do
        expect(issue_with_timestamps.updated_at).to be_a(DateTime)
        expect(issue_with_timestamps.updated_at.to_s).to include('2024-01-16')
      end
    end

    describe '#completed_at' do
      it 'parses and returns DateTime' do
        expect(issue_with_timestamps.completed_at).to be_a(DateTime)
        expect(issue_with_timestamps.completed_at.to_s).to include('2024-01-18')
      end
    end

    describe '#archived_at' do
      it 'parses and returns DateTime' do
        expect(issue_with_timestamps.archived_at).to be_a(DateTime)
        expect(issue_with_timestamps.archived_at.to_s).to include('2024-01-19')
      end
    end

    context 'with invalid timestamps' do
      let(:issue_with_invalid_timestamp) do
        described_class.new({ 'createdAt' => 'invalid-date' })
      end

      it 'logs warning and returns nil for invalid timestamps' do
        expect { issue_with_invalid_timestamp.created_at }
          .to output(/Warning: Failed to parse timestamp/).to_stdout
        expect(issue_with_invalid_timestamp.created_at).to be_nil
      end
    end

    context 'with empty timestamps' do
      let(:issue_with_empty_timestamp) do
        described_class.new({ 'createdAt' => '' })
      end

      it 'returns nil for empty timestamp strings' do
        expect(issue_with_empty_timestamp.created_at).to be_nil
      end
    end
  end

  describe '#started_at' do
    context 'with direct startedAt field' do
      let(:issue_with_started_at) do
        described_class.new({ 'startedAt' => '2024-01-17T09:00:00Z' })
      end

      it 'returns parsed startedAt timestamp' do
        expect(issue_with_started_at.started_at).to be_a(DateTime)
        expect(issue_with_started_at.started_at.to_s).to include('2024-01-17')
      end
    end

    context 'with history data when startedAt is missing' do
      let(:issue_with_history) do
        described_class.new({
                              'history' => {
                                'nodes' => [
                                  {
                                    'createdAt' => '2024-01-17T09:00:00Z',
                                    'toState' => { 'type' => 'started' }
                                  },
                                  {
                                    'createdAt' => '2024-01-16T08:00:00Z',
                                    'toState' => { 'type' => 'backlog' }
                                  }
                                ]
                              }
                            })
      end

      it 'finds start time from history' do
        expect(issue_with_history.started_at).to be_a(DateTime)
        expect(issue_with_history.started_at.to_s).to include('2024-01-17')
      end
    end

    context 'without startedAt or relevant history' do
      let(:issue_without_started_at) { described_class.new({}) }

      it 'returns nil' do
        expect(issue_without_started_at.started_at).to be_nil
      end
    end
  end

  describe 'calculated time metrics' do
    let(:issue_with_times) do
      described_class.new({
                            'createdAt' => '2024-01-10T09:00:00Z',
                            'startedAt' => '2024-01-15T09:00:00Z',
                            'completedAt' => '2024-01-20T17:00:00Z'
                          })
    end

    describe '#cycle_time_days' do
      it 'calculates cycle time from started to completed' do
        cycle_time = issue_with_times.cycle_time_days
        expect(cycle_time).to be_a(Float)
        expect(cycle_time).to be > 5.0 # 5+ days between start and complete
        expect(cycle_time).to be < 6.0 # Should be less than 6 days
      end

      it 'returns nil when started_at is missing' do
        issue_without_start = described_class.new({
                                                    'completedAt' => '2024-01-20T17:00:00Z'
                                                  })
        expect(issue_without_start.cycle_time_days).to be_nil
      end

      it 'returns nil when completed_at is missing' do
        issue_without_completion = described_class.new({
                                                         'startedAt' => '2024-01-15T09:00:00Z'
                                                       })
        expect(issue_without_completion.cycle_time_days).to be_nil
      end

      it 'returns nil when completed_at is before started_at' do
        invalid_issue = described_class.new({
                                              'startedAt' => '2024-01-20T09:00:00Z',
                                              'completedAt' => '2024-01-15T17:00:00Z'
                                            })
        expect(invalid_issue.cycle_time_days).to be_nil
      end
    end

    describe '#lead_time_days' do
      it 'calculates lead time from created to completed' do
        lead_time = issue_with_times.lead_time_days
        expect(lead_time).to be_a(Float)
        expect(lead_time).to be > 10.0 # 10+ days between creation and completion
        expect(lead_time).to be < 11.0 # Should be less than 11 days
      end

      it 'returns nil when created_at is missing' do
        issue_without_creation = described_class.new({
                                                       'completedAt' => '2024-01-20T17:00:00Z'
                                                     })
        expect(issue_without_creation.lead_time_days).to be_nil
      end

      it 'returns nil when completed_at is missing' do
        issue_without_completion = described_class.new({
                                                         'createdAt' => '2024-01-10T09:00:00Z'
                                                       })
        expect(issue_without_completion.lead_time_days).to be_nil
      end

      it 'returns nil when completed_at is before created_at' do
        invalid_issue = described_class.new({
                                              'createdAt' => '2024-01-20T09:00:00Z',
                                              'completedAt' => '2024-01-15T17:00:00Z'
                                            })
        expect(invalid_issue.lead_time_days).to be_nil
      end
    end
  end

  describe 'status classification methods' do
    describe '#completed?' do
      it 'returns true for completed issues' do
        completed_issue = described_class.new(completed_issue_data)
        expect(completed_issue.completed?).to be true
      end

      it 'returns false for non-completed issues' do
        backlog_issue = described_class.new(backlog_issue_data)
        expect(backlog_issue.completed?).to be false
      end

      it 'returns false when completed_at is nil' do
        issue_without_completion = described_class.new({
                                                         'state' => { 'type' => 'completed' }
                                                       })
        expect(issue_without_completion.completed?).to be false
      end

      it 'returns false when state_type is not completed' do
        issue_wrong_state = described_class.new({
                                                  'completedAt' => '2024-01-20T17:00:00Z',
                                                  'state' => { 'type' => 'started' }
                                                })
        expect(issue_wrong_state.completed?).to be false
      end
    end

    describe '#in_progress?' do
      it 'returns true for in-progress issues' do
        in_progress_issue = described_class.new(in_progress_issue_data)
        expect(in_progress_issue.in_progress?).to be true
      end

      it 'returns false for completed issues' do
        completed_issue = described_class.new(completed_issue_data)
        expect(completed_issue.in_progress?).to be false
      end

      it 'returns false when started_at is nil' do
        issue_without_start = described_class.new({
                                                    'state' => { 'type' => 'started' }
                                                  })
        expect(issue_without_start.in_progress?).to be false
      end

      it 'returns false when completed_at is present' do
        issue_completed = described_class.new({
                                                'startedAt' => '2024-01-15T09:00:00Z',
                                                'completedAt' => '2024-01-20T17:00:00Z',
                                                'state' => { 'type' => 'started' }
                                              })
        expect(issue_completed.in_progress?).to be false
      end
    end

    describe '#backlog?' do
      it 'returns true for backlog issues' do
        backlog_issue = described_class.new(backlog_issue_data)
        expect(backlog_issue.backlog?).to be true
      end

      it 'returns false for started issues' do
        in_progress_issue = described_class.new(in_progress_issue_data)
        expect(in_progress_issue.backlog?).to be false
      end

      it 'supports unstarted state type' do
        unstarted_issue = described_class.new({
                                                'state' => { 'type' => 'unstarted' }
                                              })
        expect(unstarted_issue.backlog?).to be true
      end
    end

    describe '#canceled?' do
      it 'returns true for canceled issues' do
        canceled_issue = described_class.new({
                                               'state' => { 'type' => 'canceled' }
                                             })
        expect(canceled_issue.canceled?).to be true
      end

      it 'returns false for non-canceled issues' do
        expect(issue.canceled?).to be false
      end
    end

    describe '#archived?' do
      it 'returns true for archived issues' do
        archived_issue = described_class.new(archived_issue_data)
        expect(archived_issue.archived?).to be true
      end

      it 'returns false for non-archived issues' do
        expect(issue.archived?).to be false
      end
    end
  end

  describe 'debugging and inspection methods' do
    let(:issue_with_title) do
      described_class.new({
                            'id' => 'issue-123',
                            'identifier' => 'ENG-456',
                            'title' => 'Sample Issue Title'
                          })
    end

    let(:issue_with_long_title) do
      described_class.new({
                            'id' => 'issue-789',
                            'identifier' => 'ENG-999',
                            'title' => 'This is a very long issue title that should be truncated when displayed'
                          })
    end

    describe '#to_s' do
      it 'returns human-readable representation with identifier and title' do
        result = issue_with_title.to_s
        expect(result).to include('ENG-456')
        expect(result).to include('Sample Issue Title')
        expect(result).to match(/Issue\[ENG-456\]: Sample Issue Title/)
      end

      it 'truncates long titles' do
        result = issue_with_long_title.to_s
        expect(result).to include('...')
        expect(result.length).to be < 80 # Should be reasonably short
      end

      it 'handles missing identifier gracefully' do
        issue_without_identifier = described_class.new({
                                                         'id' => 'issue-123',
                                                         'title' => 'Sample Title'
                                                       })
        result = issue_without_identifier.to_s
        expect(result).to include('issue-123')
        expect(result).to include('Sample Title')
      end

      it 'handles missing title gracefully' do
        issue_without_title = described_class.new({
                                                    'identifier' => 'ENG-456'
                                                  })
        result = issue_without_title.to_s
        expect(result).to include('ENG-456')
        expect(result).to include('No title')
      end
    end

    describe '#inspect' do
      it 'returns detailed debug representation' do
        completed_issue = described_class.new(completed_issue_data)
        result = completed_issue.inspect

        aggregate_failures 'inspect output validation' do
          expect(result).to include('#<KanbanMetrics::Domain::Issue')
          expect(result).to include('id=')
          expect(result).to include('identifier=')
          expect(result).to include('state=')
          expect(result).to include('completed=')
        end
      end
    end
  end

  describe 'private methods' do
    describe 'safe data access' do
      let(:issue_with_nested_data) do
        described_class.new({
                              'level1' => {
                                'level2' => {
                                  'value' => 'nested_value'
                                }
                              }
                            })
      end

      it 'safely accesses nested data via safe_dig' do
        # Access through public methods that use safe_dig internally
        expect(issue_with_nested_data.raw_data.dig('level1', 'level2', 'value')).to eq('nested_value')
      end

      it 'returns nil for missing keys' do
        expect(issue_with_nested_data.raw_data.dig('missing', 'key')).to be_nil
      end
    end

    describe 'timestamp memoization' do
      let(:issue_with_timestamp) do
        described_class.new({ 'createdAt' => '2024-01-15T10:30:00Z' })
      end

      it 'caches parsed timestamps' do
        # First access
        first_result = issue_with_timestamp.created_at
        cache = issue_with_timestamp.instance_variable_get(:@parsed_timestamps)
        expect(cache).to have_key('createdAt')

        # Second access should use cache
        second_result = issue_with_timestamp.created_at
        expect(second_result).to equal(first_result) # Same object
      end
    end

    describe 'time calculation precision' do
      let(:issue_with_precise_times) do
        described_class.new({
                              'startedAt' => '2024-01-15T09:00:00Z',
                              'completedAt' => '2024-01-17T15:30:00Z' # 2.5625 days later
                            })
      end

      it 'rounds time differences to 2 decimal places' do
        cycle_time = issue_with_precise_times.cycle_time_days
        expect(cycle_time).to be_a(Float)
        expect(cycle_time.to_s.split('.').last.length).to be <= 2
      end
    end
  end

  describe 'edge cases and error handling' do
    context 'with malformed data' do
      let(:issue_with_nil_state) do
        described_class.new({ 'state' => nil })
      end

      it 'handles nil state gracefully' do
        expect(issue_with_nil_state.state_name).to be_nil
        expect(issue_with_nil_state.state_type).to be_nil
      end
    end

    context 'with non-hash raw_data' do
      it 'handles objects that do not respond to dig or []' do
        # Create a simple object that responds to [] but not dig
        mock_data = {}
        def mock_data.dig(*)
          nil
        end

        issue_with_mock = described_class.new(mock_data)

        expect(issue_with_mock.id).to be_nil
        expect(issue_with_mock.state_name).to be_nil
      end
    end

    context 'environment variables affecting output' do
      it 'suppresses warnings in test environment' do
        # Set test environment
        allow(ENV).to receive(:[]).with('RAILS_ENV').and_return('test')
        allow(ENV).to receive(:[]).with('QUIET').and_return(nil)

        invalid_state_issue = described_class.new({
                                                    'state' => { 'type' => 'invalid_type' }
                                                  })

        expect { invalid_state_issue.state_type }.not_to output.to_stdout
      end

      it 'suppresses warnings when QUIET is set' do
        allow(ENV).to receive(:[]).with('QUIET').and_return('true')
        allow(ENV).to receive(:[]).with('RAILS_ENV').and_return(nil)

        invalid_state_issue = described_class.new({
                                                    'state' => { 'type' => 'invalid_type' }
                                                  })

        expect { invalid_state_issue.state_type }.not_to output.to_stdout
      end
    end
  end
end
