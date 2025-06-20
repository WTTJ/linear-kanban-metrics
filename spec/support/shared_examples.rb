# frozen_string_literal: true

# RSpec shared examples and contexts

# Shared context for API testing
RSpec.shared_context 'with mock api client' do
  let(:mock_api_token) { 'test-token-123' }
  let(:mock_http_client) { instance_double(KanbanMetrics::Linear::HttpClient) }
  let(:mock_query_builder) { instance_double(KanbanMetrics::Linear::QueryBuilder) }
  let(:mock_cache) { instance_double(KanbanMetrics::Linear::Cache) }
end

# Shared context for test data
RSpec.shared_context 'with test issues' do
  let(:test_issues) do
    [
      build(:linear_issue, :completed),
      build(:linear_issue, :in_progress),
      build(:linear_issue, :backlog)
    ]
  end

  let(:completed_issues) { [build(:linear_issue, :completed)] }
  let(:in_progress_issues) { [build(:linear_issue, :in_progress)] }
  let(:backlog_issues) { [build(:linear_issue, :backlog)] }
end

# Shared context for team data
RSpec.shared_context 'with test teams' do
  let(:roi_team) do
    {
      'id' => '5cb3ee70-693d-406b-a6a5-23a002ef10d6',
      'name' => 'ROI',
      'key' => 'ROI'
    }
  end

  let(:frontend_team) do
    {
      'id' => 'c9dae417-1351-4c92-9a59-ea972c65f5ed',
      'name' => 'Frontend chapter',
      'key' => 'FRONT'
    }
  end
end

# Shared examples for error handling
RSpec.shared_examples 'handles api errors gracefully' do
  it 'raises ApiError for HTTP errors' do
    allow(subject).to receive(:post).and_raise(KanbanMetrics::ApiError, 'HTTP 500')

    expect { subject.fetch_data }.to raise_error(KanbanMetrics::ApiError, /HTTP 500/)
  end
end

# Shared examples for pagination
RSpec.shared_examples 'handles pagination correctly' do
  it 'processes multiple pages of results' do
    expect(subject.fetch_all_pages).to be_an(Array)
    expect(subject.fetch_all_pages.length).to be > 0
  end
end

# Shared examples for cache behavior
RSpec.shared_examples 'implements caching correctly' do
  it 'returns cached data when available' do
    subject.save_to_cache('test_key', test_data)
    result = subject.fetch_from_cache('test_key')

    expect(result).to eq(test_data)
  end

  it 'returns nil for expired cache' do
    subject.save_to_cache('test_key', test_data)
    travel_to_tomorrow

    result = subject.fetch_from_cache('test_key')
    expect(result).to be_nil
  end
end
