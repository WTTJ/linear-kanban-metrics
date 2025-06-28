# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../.github/scripts/pr_review'

RSpec.describe PullRequestReviewer do
  let(:github_client) { instance_double(Octokit::Client) }
  let(:test_config) do
    {
      repo: 'test-user/test-repo',
      pr_number: 123,
      anthropic_api_key: 'test-key'
    }
  end

  before do
    # Set up test environment variables
    allow(ENV).to receive(:fetch).with('GITHUB_TOKEN', nil).and_return('test-token')
    allow(ENV).to receive(:fetch).with('GITHUB_REPOSITORY', nil).and_return('test-user/test-repo')
    allow(ENV).to receive(:fetch).with('PR_NUMBER', '0').and_return('123')
    allow(ENV).to receive(:fetch).with('ANTHROPIC_API_KEY', nil).and_return('test-key')
    allow(ENV).to receive(:[]).with('DEBUG').and_return(nil)

    # Mock Octokit client
    allow(Octokit::Client).to receive(:new).and_return(github_client)
  end

  describe '#initialize' do
    it 'creates a reviewer instance with valid configuration' do
      reviewer = described_class.new
      expect(reviewer).to be_an_instance_of(described_class)
    end

    context 'with missing environment variables' do
      before do
        allow(ENV).to receive(:fetch).with('GITHUB_TOKEN', nil).and_return(nil)
      end

      it 'raises an error for missing GITHUB_TOKEN' do
        expect { described_class.new }.to raise_error('GITHUB_TOKEN environment variable is required')
      end
    end

    context 'with invalid PR number' do
      before do
        allow(ENV).to receive(:fetch).with('PR_NUMBER', '0').and_return('0')
      end

      it 'raises an error for invalid PR_NUMBER' do
        expect { described_class.new }.to raise_error(ArgumentError, /Invalid configuration.*PR_NUMBER must be a positive integer/)
      end
    end
  end

  describe '#gather_review_data' do
    let(:reviewer) { described_class.new }

    before do
      # Create test files
      allow(File).to receive(:exist?).and_return(true)
      allow(File).to receive(:read).with('doc/CODING_STANDARDS.md').and_return('Test coding standards')
      allow(File).to receive(:read).with('reports/rspec.txt').and_return('All tests pass')
      allow(File).to receive(:read).with('reports/rubocop.txt').and_return('No offenses')
      allow(File).to receive(:read).with('reports/brakeman.txt').and_return('No warnings')
      allow(File).to receive(:read).with('.github/scripts/pr_review_prompt_template.md').and_return('Test template {{guidelines}}')

      # Mock GitHub API call
      allow(github_client).to receive(:pull_request).and_return('Test PR diff')
    end

    it 'gathers all required review data' do
      data = reviewer.send(:gather_review_data)

      expect(data).to include(
        guidelines: 'Test coding standards',
        rspec_results: 'All tests pass',
        rubocop_results: 'No offenses',
        brakeman_results: 'No warnings',
        pr_diff: 'Test PR diff',
        prompt_template: 'Test template {{guidelines}}'
      )
    end

    it 'handles missing files gracefully' do
      allow(File).to receive(:exist?).and_return(false)

      data = reviewer.send(:gather_review_data)

      expect(data[:guidelines]).to eq('Not available.')
      expect(data[:rspec_results]).to eq('Not available.')
    end
  end

  describe '#build_claude_prompt' do
    let(:reviewer) { described_class.new }
    let(:review_data) do
      {
        prompt_template: 'Guidelines: {{guidelines}}\nRSpec: {{rspec_results}}',
        guidelines: 'Test guidelines',
        rspec_results: 'Test results',
        rubocop_results: 'Clean',
        brakeman_results: 'Secure',
        pr_diff: 'Test diff'
      }
    end

    it 'replaces template placeholders with actual data' do
      prompt = reviewer.send(:build_claude_prompt, review_data)

      expect(prompt).to include('Guidelines: Test guidelines')
      expect(prompt).to include('RSpec: Test results')
      expect(prompt).not_to include('{{')
    end
  end

  describe '#safe_read_file' do
    let(:reviewer) { described_class.new }

    context 'when file exists' do
      before do
        allow(File).to receive(:exist?).with('test_file.txt').and_return(true)
        allow(File).to receive(:read).with('test_file.txt').and_return('file content')
      end

      it 'returns file content' do
        result = reviewer.send(:safe_read_file, 'test_file.txt')
        expect(result).to eq('file content')
      end
    end

    context 'when file does not exist' do
      before do
        allow(File).to receive(:exist?).with('missing_file.txt').and_return(false)
      end

      it 'returns fallback message' do
        result = reviewer.send(:safe_read_file, 'missing_file.txt')
        expect(result).to eq('Not available.')
      end

      it 'returns custom fallback when provided' do
        result = reviewer.send(:safe_read_file, 'missing_file.txt', 'Custom fallback')
        expect(result).to eq('Custom fallback')
      end
    end

    context 'when file read raises an error' do
      before do
        allow(File).to receive(:exist?).with('error_file.txt').and_return(true)
        allow(File).to receive(:read).with('error_file.txt').and_raise(StandardError, 'Permission denied')
      end

      it 'returns fallback message' do
        result = reviewer.send(:safe_read_file, 'error_file.txt')
        expect(result).to eq('Not available.')
      end
    end
  end

  describe '#format_github_comment' do
    let(:reviewer) { described_class.new }
    let(:review_content) { 'This is a test review' }

    it 'formats the review content with proper structure' do
      comment = reviewer.send(:format_github_comment, review_content)

      expect(comment).to include('## 🤖 AI Code Review')
      expect(comment).to include(review_content)
      expect(comment).to include('Review generated by Claude 4 Sonnet at')
    end

    it 'includes a timestamp' do
      freeze_time = Time.parse('2025-06-28 10:00:00 UTC')
      allow(Time).to receive(:now).and_return(freeze_time)

      comment = reviewer.send(:format_github_comment, review_content)

      expect(comment).to include('2025-06-28 10:00:00 UTC')
    end
  end

  describe 'configuration validation' do
    context 'with all required environment variables' do
      it 'passes validation' do
        expect { described_class.new }.not_to raise_error
      end
    end

    context 'with missing ANTHROPIC_API_KEY' do
      before do
        allow(ENV).to receive(:fetch).with('ANTHROPIC_API_KEY', nil).and_return(nil)
      end

      it 'raises ArgumentError' do
        expect { described_class.new }.to raise_error(ArgumentError, /ANTHROPIC_API_KEY environment variable is required/)
      end
    end

    context 'with empty GITHUB_REPOSITORY' do
      before do
        allow(ENV).to receive(:fetch).with('GITHUB_REPOSITORY', nil).and_return('')
      end

      it 'raises ArgumentError' do
        expect { described_class.new }.to raise_error(ArgumentError, /GITHUB_REPOSITORY environment variable is required/)
      end
    end
  end

  describe 'constants' do
    it 'defines API configuration constants' do
      expect(described_class::API_VERSION).to eq('2023-06-01')
      expect(described_class::CLAUDE_MODEL).to eq('claude-opus-4-20250514')
      expect(described_class::MAX_TOKENS).to eq(4096)
      expect(described_class::TEMPERATURE).to eq(0.1)
    end
  end
end
