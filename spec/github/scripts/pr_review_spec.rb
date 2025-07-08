# frozen_string_literal: true

require_relative '../../../.github/scripts/pr_review'

RSpec.describe 'PR Review Refactored' do
  describe BasicConfigValidator do
    let(:validator) { described_class.new }
    let(:config) { double('config') }

    before do
      allow(config).to receive_messages(repo: 'test/repo', pr_number: 123, github_token: 'token', api_provider: 'anthropic')
    end

    it 'returns no errors for valid config' do
      errors = validator.validate(config)
      expect(errors).to be_empty
    end

    it 'returns error for missing repo' do
      allow(config).to receive(:repo).and_return(nil)
      errors = validator.validate(config)
      expect(errors).to include('GITHUB_REPOSITORY environment variable is required')
    end

    it 'returns error for invalid PR number' do
      allow(config).to receive(:pr_number).and_return(0)
      errors = validator.validate(config)
      expect(errors).to include('PR_NUMBER must be a positive integer')
    end
  end

  describe AnthropicConfigValidator do
    let(:validator) { described_class.new }
    let(:config) { double('config') }

    context 'when using anthropic provider' do
      before do
        allow(config).to receive_messages(anthropic?: true, anthropic_api_key: 'key')
      end

      it 'returns no errors for valid config' do
        errors = validator.validate(config)
        expect(errors).to be_empty
      end

      it 'returns error for missing API key' do
        allow(config).to receive(:anthropic_api_key).and_return(nil)
        errors = validator.validate(config)
        expect(errors).to include('ANTHROPIC_API_KEY environment variable is required for Anthropic API')
      end
    end

    context 'when not using anthropic provider' do
      before do
        allow(config).to receive(:anthropic?).and_return(false)
      end

      it 'returns no errors' do
        errors = validator.validate(config)
        expect(errors).to be_empty
      end
    end
  end

  describe DustConfigValidator do
    let(:validator) { described_class.new }
    let(:config) { double('config') }

    context 'when using dust provider' do
      before do
        allow(config).to receive_messages(dust?: true, dust_api_key: 'key', dust_workspace_id: 'workspace', dust_agent_id: 'agent')
      end

      it 'returns no errors for valid config' do
        errors = validator.validate(config)
        expect(errors).to be_empty
      end

      it 'returns error for missing API key' do
        allow(config).to receive(:dust_api_key).and_return(nil)
        errors = validator.validate(config)
        expect(errors).to include('DUST_API_KEY environment variable is required for Dust API')
      end
    end

    context 'when not using dust provider' do
      before do
        allow(config).to receive(:dust?).and_return(false)
      end

      it 'returns no errors' do
        errors = validator.validate(config)
        expect(errors).to be_empty
      end
    end
  end

  describe ConfigValidationService do
    let(:service) { described_class.new }
    let(:config) { double('config') }

    before do
      allow(config).to receive_messages(repo: 'test/repo', pr_number: 123, github_token: 'token', api_provider: 'anthropic', anthropic?: true, dust?: false, anthropic_api_key: 'key')
    end

    it 'validates configuration using all validators' do
      errors = service.validate(config)
      expect(errors).to be_empty
    end
  end

  describe ReviewerConfig do
    let(:env) do
      {
        'GITHUB_REPOSITORY' => 'test/repo',
        'PR_NUMBER' => '123',
        'GITHUB_TOKEN' => 'token',
        'API_PROVIDER' => 'anthropic',
        'ANTHROPIC_API_KEY' => 'key'
      }
    end
    let(:validation_service) { double('validation_service') }
    let(:config) { described_class.new(env, validation_service) }

    before do
      allow(validation_service).to receive(:validate).and_return([])
    end

    it 'extracts configuration from environment' do
      expect(config.repo).to eq('test/repo')
      expect(config.pr_number).to eq(123)
      expect(config.github_token).to eq('token')
      expect(config.api_provider).to eq('anthropic')
      expect(config.anthropic_api_key).to eq('key')
    end

    it 'is valid when no errors' do
      expect(config.valid?).to be true
    end

    it 'is invalid when has errors' do
      allow(validation_service).to receive(:validate).and_return(['error'])
      expect(config.valid?).to be false
    end

    it 'returns true for anthropic provider' do
      expect(config.anthropic?).to be true
    end

    it 'returns false for dust provider' do
      expect(config.dust?).to be false
    end
  end

  describe SecureFileReader do
    let(:logger) { double('logger') }
    let(:reader) { described_class.new(logger) }

    before do
      allow(logger).to receive(:warn)
    end

    it 'raises error for invalid file path' do
      expect { reader.read_file('../invalid') }.to raise_error(ArgumentError)
    end

    it 'raises error for file path with null bytes' do
      expect { reader.read_file("doc/test\0") }.to raise_error(ArgumentError)
    end

    it 'returns fallback for missing file' do
      allow(File).to receive(:exist?).with('doc/missing.md').and_return(false)
      result = reader.read_file('doc/missing.md', 'fallback')
      expect(result).to eq('fallback')
    end

    it 'reads existing file' do
      allow(File).to receive(:exist?).with('doc/test.md').and_return(true)
      allow(File).to receive(:read).with('doc/test.md').and_return('content')
      result = reader.read_file('doc/test.md')
      expect(result).to eq('content')
    end
  end

  describe PromptBuilder do
    let(:builder) { described_class.new }
    let(:review_data) do
      {
        prompt_template: 'Guidelines: {{guidelines}}, RSpec: {{rspec_results}}, RuboCop: {{rubocop_results}}, Brakeman: {{brakeman_results}}, Diff: {{pr_diff}}',
        guidelines: 'Follow standards',
        rspec_results: 'Tests passed',
        rubocop_results: 'No offenses',
        brakeman_results: 'No issues',
        pr_diff: 'diff content'
      }
    end

    it 'builds prompt by replacing placeholders' do
      prompt = builder.build_prompt(review_data)
      expect(prompt).to eq('Guidelines: Follow standards, RSpec: Tests passed, RuboCop: No offenses, Brakeman: No issues, Diff: diff content')
    end
  end

  describe HTTPClient do
    let(:logger) { double('logger') }
    let(:client) { described_class.new(logger) }

    before do
      allow(logger).to receive(:error)
    end

    it 'raises error for non-200 response' do
      response = double('response', code: '400', body: 'error')
      allow(Net::HTTP).to receive(:start).and_return(response)

      expect { client.post(URI('http://test.com'), {}, '{}') }.to raise_error(StandardError)
    end
  end

  describe AnthropicProvider do
    let(:config) { double('config', anthropic_api_key: 'key') }
    let(:http_client) { double('http_client') }
    let(:logger) { double('logger') }
    let(:provider) { described_class.new('key', http_client, logger) }

    before do
      allow(logger).to receive(:info)
      allow(logger).to receive(:debug)
      allow(logger).to receive(:warn)
    end

    it 'returns correct provider name' do
      expect(provider.provider_name).to eq('Anthropic Claude')
    end

    it 'requests review from API' do
      api_response = { 'content' => [{ 'text' => 'review content' }] }
      allow(http_client).to receive(:post).and_return(api_response)

      result = provider.make_request('test prompt')
      expect(result).to eq('review content')
    end

    it 'handles empty response' do
      api_response = { 'content' => [{ 'text' => '' }] }
      allow(http_client).to receive(:post).and_return(api_response)

      result = provider.make_request('test prompt')
      expect(result).to be_nil
    end
  end

  describe DustProvider do
    let(:config) do
      double('config',
             dust_api_key: 'key',
             dust_workspace_id: 'workspace',
             dust_agent_id: 'agent')
    end
    let(:http_client) { double('http_client') }
    let(:logger) { double('logger') }
    let(:provider) { described_class.new('key', 'workspace', 'agent', http_client, logger) }

    before do
      allow(logger).to receive(:info)
      allow(logger).to receive(:debug)
      allow(logger).to receive(:warn)
      # Mock sleep to prevent test delays
      allow(provider).to receive(:sleep)
    end

    it 'returns correct provider name' do
      expect(provider.provider_name).to eq('Dust AI')
    end

    it 'requests review from API' do
      conversation_response = { 'conversation' => { 'sId' => 'conv123' } }
      response_data = {
        'conversation' => {
          'content' => [[{ 'type' => 'agent_message', 'status' => 'succeeded', 'content' => 'review content' }]]
        }
      }

      allow(http_client).to receive_messages(post: conversation_response, get: response_data)

      result = provider.make_request('test prompt')
      expect(result).to eq('review content')
    end
  end

  describe AIProviderFactory do
    let(:config) { double('config') }
    let(:http_client) { double('http_client') }
    let(:logger) { double('logger') }

    it 'creates Anthropic provider' do
      allow(config).to receive_messages(api_provider: 'anthropic', anthropic_api_key: 'key')
      provider = described_class.create(config, http_client, logger)
      expect(provider).to be_a(AnthropicProvider)
    end

    it 'creates Dust provider' do
      allow(config).to receive_messages(api_provider: 'dust', dust_api_key: 'key', dust_workspace_id: 'workspace', dust_agent_id: 'agent')
      provider = described_class.create(config, http_client, logger)
      expect(provider).to be_a(DustProvider)
    end

    it 'raises error for unsupported provider' do
      allow(config).to receive(:api_provider).and_return('unknown')
      expect { described_class.create(config, http_client, logger) }.to raise_error(StandardError)
    end
  end

  describe GitHubCommentService do
    let(:github_client) { double('github_client') }
    let(:logger) { double('logger') }
    let(:service) { described_class.new(github_client, logger) }
    let(:config) { double('config', repo: 'test/repo', pr_number: 123) }

    before do
      allow(logger).to receive(:info)
      allow(logger).to receive(:error)
      allow(Time).to receive(:now).and_return(Time.parse('2025-01-01 10:00:00 UTC'))
    end

    it 'posts comment to GitHub' do
      expect(github_client).to receive(:add_comment).with('test/repo', 123, anything)
      service.post_comment(config, 'review content', 'AI Provider')
    end

    it 'formats comment correctly' do
      allow(github_client).to receive(:add_comment) do |_repo, _pr, comment|
        expect(comment).to include('review content')
        expect(comment).to include('Review generated by AI Provider')
        expect(comment).to include('2025-01-01 10:00:00 UTC')
      end

      service.post_comment(config, 'review content', 'AI Provider')
    end
  end

  describe PullRequestReviewer do
    let(:config) { double('config') }
    let(:logger) { double('logger') }
    let(:github_client) { double('github_client') }
    let(:dependencies) do
      {
        logger: logger,
        github_client: github_client,
        http_client: double('http_client'),
        file_reader: double('file_reader'),
        data_gatherer: double('data_gatherer'),
        prompt_builder: double('prompt_builder'),
        ai_provider: double('ai_provider'),
        comment_service: double('comment_service')
      }
    end

    before do
      allow(config).to receive_messages(valid?: true, repo: 'test/repo', pr_number: 123, api_provider: 'anthropic')
      allow(logger).to receive(:info)
      allow(logger).to receive(:error)
      allow(logger).to receive(:debug)
    end

    it 'runs the review process successfully' do
      reviewer = described_class.new(config, dependencies)

      allow(dependencies[:data_gatherer]).to receive(:gather_data).and_return({})
      allow(dependencies[:prompt_builder]).to receive(:build_prompt).and_return('prompt')
      allow(dependencies[:ai_provider]).to receive_messages(make_request: 'review', provider_name: 'AI Provider')
      expect(dependencies[:comment_service]).to receive(:post_comment)

      reviewer.run
    end

    it 'raises error for invalid configuration' do
      allow(config).to receive_messages(valid?: false, errors: ['error'])

      expect { described_class.new(config, dependencies) }.to raise_error(ArgumentError)
    end
  end
end
