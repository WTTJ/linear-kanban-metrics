# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../.github/scripts/pr_review'

RSpec.describe PullRequestReviewer do
  # === TEST DATA SETUP ===
  # === NAMED SUBJECTS ===
  subject(:reviewer) { described_class.new }

  let(:github_client) { instance_double(Octokit::Client) }
  let(:valid_github_token) { 'test-token' }
  let(:valid_repo) { 'test-user/test-repo' }
  let(:valid_pr_number) { '123' }
  let(:valid_anthropic_key) { 'test-key' }

  let(:test_guidelines) { 'Test coding standards' }
  let(:test_rspec_results) { 'All tests pass' }
  let(:test_rubocop_results) { 'No offenses' }
  let(:test_brakeman_results) { 'No warnings' }
  let(:test_pr_diff) { 'Test PR diff' }
  let(:test_prompt_template) { 'Test template {{guidelines}}' }

  before do
    # Arrange - Set up valid test environment
    setup_valid_environment
    setup_github_client_mock
  end

  def setup_valid_environment
    allow(ENV).to receive(:fetch).with('GITHUB_TOKEN', nil).and_return(valid_github_token)
    allow(ENV).to receive(:fetch).with('GITHUB_REPOSITORY', nil).and_return(valid_repo)
    allow(ENV).to receive(:fetch).with('PR_NUMBER', '0').and_return(valid_pr_number)
    allow(ENV).to receive(:fetch).with('ANTHROPIC_API_KEY', nil).and_return(valid_anthropic_key)
    allow(ENV).to receive(:[]).with('DEBUG').and_return(nil)
  end

  def setup_github_client_mock
    connection_options = double('connection_options')
    allow(connection_options).to receive(:[]=).with(:request, anything)

    allow(Octokit::Client).to receive(:new).and_return(github_client)
    allow(github_client).to receive(:connection_options).and_return(connection_options)
  end

  describe '#initialize' do
    context 'with valid configuration' do
      it 'creates a reviewer instance successfully' do
        # Act & Assert
        expect(reviewer).to be_an_instance_of(described_class)
      end
    end

    context 'with missing GITHUB_TOKEN' do
      before do
        # Arrange - Remove GITHUB_TOKEN
        allow(ENV).to receive(:fetch).with('GITHUB_TOKEN', nil).and_return(nil)
      end

      it 'raises descriptive error message' do
        # Act & Assert
        expect { described_class.new }.to raise_error(ArgumentError, /GITHUB_TOKEN environment variable is required/)
      end
    end

    context 'with invalid PR number' do
      before do
        # Arrange - Set invalid PR number
        allow(ENV).to receive(:fetch).with('PR_NUMBER', '0').and_return('0')
      end

      it 'raises ArgumentError with validation message' do
        # Act & Assert
        expect { described_class.new }.to raise_error(ArgumentError, /Invalid configuration.*PR_NUMBER must be a positive integer/)
      end
    end
  end

  describe '#gather_review_data' do
    subject(:review_data) { reviewer.send(:gather_review_data) }

    before do
      # Arrange - Setup file system mocks
      setup_file_mocks
      setup_github_api_mock
    end

    def setup_file_mocks
      allow(File).to receive(:exist?).and_return(true)
      setup_coding_standards_mock
      setup_report_file_mocks
      setup_prompt_template_mock
    end

    def setup_coding_standards_mock
      allow(File).to receive(:read).with('doc/CODING_STANDARDS.md').and_return(test_guidelines)
    end

    def setup_report_file_mocks
      allow(File).to receive(:read).with('reports/rspec.txt').and_return(test_rspec_results)
      allow(File).to receive(:read).with('reports/rubocop.txt').and_return(test_rubocop_results)
      allow(File).to receive(:read).with('reports/brakeman.txt').and_return(test_brakeman_results)
    end

    def setup_prompt_template_mock
      allow(File).to receive(:read)
        .with('.github/scripts/pr_review_prompt_template.md')
        .and_return(test_prompt_template)
    end

    def setup_github_api_mock
      allow(github_client).to receive(:pull_request).and_return(test_pr_diff)
    end

    context 'with all files available' do
      it 'returns complete review data structure', :aggregate_failures do
        # Act & Assert
        expect(review_data).to include(
          guidelines: test_guidelines,
          rspec_results: test_rspec_results,
          rubocop_results: test_rubocop_results,
          brakeman_results: test_brakeman_results,
          pr_diff: test_pr_diff,
          prompt_template: test_prompt_template
        )
      end
    end

    context 'with missing files' do
      before do
        # Arrange - Simulate missing files
        allow(File).to receive(:exist?).and_return(false)
      end

      it 'provides fallback content for missing files', :aggregate_failures do
        # Act & Assert
        expect(review_data[:guidelines]).to eq('Not available.')
        expect(review_data[:rspec_results]).to eq('Not available.')
      end
    end

    context 'with GitHub API failure' do
      before do
        # Arrange - Simulate API failure
        allow(github_client).to receive(:pull_request).and_raise(StandardError, 'API Error')
      end

      it 'handles API errors gracefully' do
        # Act & Assert
        expect(review_data[:pr_diff]).to eq('PR diff not available.')
      end
    end
  end

  describe '#build_claude_prompt' do
    subject(:prompt) { reviewer.send(:build_claude_prompt, review_data) }

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

    it 'replaces all template placeholders', :aggregate_failures do
      # Act & Assert
      expect(prompt).to include('Guidelines: Test guidelines')
      expect(prompt).to include('RSpec: Test results')
      expect(prompt).not_to include('{{')
    end
  end

  describe '#safe_read_file' do
    subject(:file_content) do
      if custom_fallback
        reviewer.send(:safe_read_file, file_path, custom_fallback)
      else
        reviewer.send(:safe_read_file, file_path)
      end
    end

    let(:file_path) { 'doc/test_file.txt' }
    let(:custom_fallback) { nil }

    context 'when file exists and is readable' do
      before do
        # Arrange - Setup successful file read
        allow(File).to receive(:exist?).with(file_path).and_return(true)
        allow(File).to receive(:read).with(file_path).and_return('file content')
      end

      it 'returns the file content' do
        # Act & Assert
        expect(file_content).to eq('file content')
      end
    end

    context 'when file does not exist' do
      before do
        # Arrange - Simulate missing file
        allow(File).to receive(:exist?).with(file_path).and_return(false)
      end

      it 'returns default fallback message' do
        # Act & Assert
        expect(file_content).to eq('Not available.')
      end

      context 'with custom fallback' do
        let(:custom_fallback) { 'Custom fallback' }

        it 'returns the custom fallback message' do
          # Act & Assert
          expect(file_content).to eq('Custom fallback')
        end
      end
    end

    context 'when file read raises an error' do
      before do
        # Arrange - Simulate file read error
        allow(File).to receive(:exist?).with(file_path).and_return(true)
        allow(File).to receive(:read).with(file_path).and_raise(StandardError, 'Permission denied')
      end

      it 'handles errors gracefully and returns fallback' do
        # Act & Assert
        expect(file_content).to eq('Not available.')
      end
    end

    context 'with security validation' do
      context 'when file path contains directory traversal' do
        let(:file_path) { '../etc/passwd' }

        it 'raises security error' do
          # Act & Assert
          expect { file_content }.to raise_error(ArgumentError, /directory traversal patterns/)
        end
      end

      context 'when file path contains null bytes' do
        let(:file_path) { "doc/test\0file.txt" }

        it 'raises security error' do
          # Act & Assert
          expect { file_content }.to raise_error(ArgumentError, /null bytes/)
        end
      end

      context 'when file path is outside allowed directories' do
        let(:file_path) { 'unauthorized/file.txt' }

        it 'raises security error' do
          # Act & Assert
          expect { file_content }.to raise_error(ArgumentError, /must start with one of/)
        end
      end

      context 'when file path is nil' do
        let(:file_path) { nil }

        it 'raises security error' do
          # Act & Assert
          expect { file_content }.to raise_error(ArgumentError, /cannot be nil or empty/)
        end
      end

      context 'when file path is empty' do
        let(:file_path) { '' }

        it 'raises security error' do
          # Act & Assert
          expect { file_content }.to raise_error(ArgumentError, /cannot be nil or empty/)
        end
      end
    end
  end

  describe '#format_github_comment' do
    subject(:formatted_comment) { reviewer.send(:format_github_comment, review_content) }

    let(:review_content) { 'This is a test review' }
    let(:freeze_time) { Time.parse('2025-06-28 10:00:00 UTC') }

    before do
      # Arrange - Freeze time for consistent testing
      allow(Time).to receive(:now).and_return(freeze_time)
    end

    it 'includes all required comment components', :aggregate_failures do
      # Act & Assert
      expect(formatted_comment).to include(review_content)
      expect(formatted_comment).to include('Review generated by Claude')
      expect(formatted_comment).to include('---')
    end

    it 'includes the correct timestamp' do
      # Act & Assert
      expect(formatted_comment).to include('2025-06-28 10:00:00 UTC')
    end
  end

  describe 'configuration validation' do
    context 'with complete valid configuration' do
      it 'passes all validation checks' do
        # Act & Assert
        expect { described_class.new }.not_to raise_error
      end
    end

    context 'with missing ANTHROPIC_API_KEY' do
      before do
        # Arrange - Remove required API key
        allow(ENV).to receive(:fetch).with('ANTHROPIC_API_KEY', nil).and_return(nil)
      end

      it 'raises descriptive validation error' do
        # Act & Assert
        expect { described_class.new }.to raise_error(ArgumentError, /ANTHROPIC_API_KEY environment variable is required/)
      end
    end

    context 'with empty GITHUB_REPOSITORY' do
      before do
        # Arrange - Set empty repository name
        allow(ENV).to receive(:fetch).with('GITHUB_REPOSITORY', nil).and_return('')
      end

      it 'raises descriptive validation error' do
        # Act & Assert
        expect { described_class.new }.to raise_error(ArgumentError, /GITHUB_REPOSITORY environment variable is required/)
      end
    end
  end

  describe 'API configuration constants' do
    it 'defines correct API version and model', :aggregate_failures do
      # Act & Assert
      expect(described_class::API_VERSION).to eq('2023-06-01')
      expect(described_class::CLAUDE_MODEL).to eq('claude-opus-4-20250514')
      expect(described_class::MAX_TOKENS).to eq(4096)
      expect(described_class::TEMPERATURE).to eq(0.1)
    end

    it 'defines timeout configurations', :aggregate_failures do
      # Act & Assert
      expect(described_class::HTTP_TIMEOUT).to eq(30)
      expect(described_class::READ_TIMEOUT).to eq(120)
      expect(described_class::GITHUB_TIMEOUT).to eq(15)
    end
  end
end

RSpec.describe ReviewerConfig do
  subject(:config) { described_class.new }

  before do
    # Arrange - Setup environment variables
    allow(ENV).to receive(:fetch).with('GITHUB_REPOSITORY', nil).and_return('test-repo')
    allow(ENV).to receive(:fetch).with('PR_NUMBER', '0').and_return('123')
    allow(ENV).to receive(:fetch).with('ANTHROPIC_API_KEY', nil).and_return('test-key')
    allow(ENV).to receive(:fetch).with('GITHUB_TOKEN', nil).and_return('test-token')
  end

  describe '#initialize' do
    it 'extracts configuration from environment variables', :aggregate_failures do
      # Act & Assert
      expect(config.repo).to eq('test-repo')
      expect(config.pr_number).to eq(123)
      expect(config.anthropic_api_key).to eq('test-key')
      expect(config.github_token).to eq('test-token')
    end
  end

  describe '#valid?' do
    context 'with all required values' do
      it 'returns true' do
        # Act & Assert
        expect(config.valid?).to be true
      end
    end

    context 'with missing required values' do
      before do
        # Arrange - Remove required environment variable
        allow(ENV).to receive(:fetch).with('GITHUB_REPOSITORY', nil).and_return(nil)
      end

      it 'returns false' do
        # Act & Assert
        expect(config.valid?).to be false
      end
    end
  end

  describe '#errors' do
    context 'with valid configuration' do
      it 'returns empty array' do
        # Act & Assert
        expect(config.errors).to be_empty
      end
    end

    context 'with invalid PR number' do
      before do
        # Arrange - Set invalid PR number
        allow(ENV).to receive(:fetch).with('PR_NUMBER', '0').and_return('0')
      end

      it 'includes PR number error' do
        # Act & Assert
        expect(config.errors).to include('PR_NUMBER must be a positive integer')
      end
    end

    context 'with missing environment variables' do
      before do
        # Arrange - Remove all required variables
        allow(ENV).to receive(:fetch).with('GITHUB_REPOSITORY', nil).and_return('')
        allow(ENV).to receive(:fetch).with('ANTHROPIC_API_KEY', nil).and_return(nil)
        allow(ENV).to receive(:fetch).with('GITHUB_TOKEN', nil).and_return('')
      end

      it 'includes all validation errors', :aggregate_failures do
        # Act & Assert
        expect(config.errors).to include('GITHUB_REPOSITORY environment variable is required')
        expect(config.errors).to include('ANTHROPIC_API_KEY environment variable is required')
        expect(config.errors).to include('GITHUB_TOKEN environment variable is required')
      end
    end
  end
end
