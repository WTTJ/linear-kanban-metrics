# frozen_string_literal: true

require 'spec_helper'

# Load the smart test runner from the correct path
require File.expand_path('../../../.github/scripts/smart_test_runner', __dir__)

RSpec.describe SmartTestRunner do
  let(:mock_logger) { instance_double(Logger) }
  let(:mock_config) { instance_double(SmartTestConfig) }

  before do
    allow(Logger).to receive(:new).and_return(mock_logger)
    allow(mock_logger).to receive(:info)
    allow(mock_logger).to receive(:warn)
    allow(mock_logger).to receive(:error)
    allow(mock_logger).to receive(:debug)
    allow(FileUtils).to receive(:mkdir_p)
  end

  describe SmartTestConfig do
    subject(:config) { described_class.new(env_vars) }

    let(:env_vars) do
      {
        'GITHUB_REPOSITORY' => 'owner/repo',
        'PR_NUMBER' => '123',
        'COMMIT_SHA' => 'abc123',
        'BASE_REF' => 'main',
        'GITHUB_TOKEN' => 'token123',
        'API_PROVIDER' => 'anthropic',
        'ANTHROPIC_API_KEY' => 'anthropic_key'
      }
    end

    describe '#valid?' do
      context 'with valid anthropic configuration' do
        it 'returns true' do
          expect(config.valid?).to be true
        end
      end

      context 'with missing github token' do
        let(:env_vars) { super().merge('GITHUB_TOKEN' => '') }

        it 'returns false' do
          expect(config.valid?).to be false
        end
      end

      context 'with missing anthropic key' do
        let(:env_vars) { super().merge('ANTHROPIC_API_KEY' => '') }

        it 'returns false' do
          expect(config.valid?).to be false
        end
      end
    end

    describe '#pr_mode?' do
      context 'when PR_NUMBER is set' do
        it 'returns true' do
          expect(config.pr_mode?).to be true
        end
      end

      context 'when PR_NUMBER is not set' do
        let(:env_vars) { super().merge('PR_NUMBER' => '') }

        it 'returns false' do
          expect(config.pr_mode?).to be false
        end
      end
    end
  end

  describe GitChangeAnalyzer do
    subject(:analyzer) { described_class.new(mock_logger) }

    describe '#analyze_changes' do
      let(:config) do
        instance_double(SmartTestConfig,
                        pr_mode?: false,
                        base_ref: 'main',
                        commit_sha: 'abc123')
      end
      let(:sample_diff) do
        <<~DIFF
          diff --git a/lib/example.rb b/lib/example.rb
          index abc123..def456 100644
          --- a/lib/example.rb
          +++ b/lib/example.rb
          @@ -1,3 +1,4 @@
           class Example
          +  attr_reader :name
             def initialize
             end
        DIFF
      end

      before do
        allow(analyzer).to receive(:`).with('git diff --no-color main...abc123').and_return(sample_diff)
      end

      it 'analyzes git changes successfully' do
        result = analyzer.analyze_changes(config)

        expect(result).to have_key(:diff)
        expect(result).to have_key(:changed_files)
        expect(result).to have_key(:analysis)
        expect(result[:changed_files]).not_to be_empty
      end

      it 'identifies file types correctly' do
        result = analyzer.analyze_changes(config)

        changed_file = result[:changed_files].first
        expect(changed_file[:path]).to eq('lib/example.rb')
        expect(changed_file[:type]).to eq(:source)
      end
    end
  end

  describe TestDiscoveryService do
    subject(:service) { described_class.new(mock_logger) }

    before do
      allow(Dir).to receive(:glob).with('spec/**/*_spec.rb').and_return([
                                                                          'spec/lib/example_spec.rb',
                                                                          'spec/lib/other_spec.rb'
                                                                        ])
      allow(Dir).to receive(:glob).with('lib/**/*.rb').and_return([
                                                                    'lib/example.rb',
                                                                    'lib/other.rb'
                                                                  ])
      allow(File).to receive(:exist?).and_return(true)
    end

    describe '#discover_tests' do
      it 'discovers test files and their relationships' do
        result = service.discover_tests

        expect(result).to have_key(:test_files)
        expect(result).to have_key(:source_files)
        expect(result).to have_key(:test_mapping)
        expect(result).to have_key(:reverse_mapping)
      end

      it 'maps tests to source files correctly' do
        result = service.discover_tests

        expect(result[:test_mapping]).to include('spec/lib/example_spec.rb' => ['lib/lib/example.rb'])
      end
    end
  end

  describe AITestSelector do
    subject(:selector) { described_class.new(config, mock_logger) }

    let(:config) do
      instance_double(SmartTestConfig,
                      anthropic?: true,
                      dust?: false,
                      anthropic_api_key: 'test_key')
    end
    let(:changes) do
      {
        changed_files: [
          {
            path: 'lib/example.rb',
            type: :source,
            changes: { added: ['+ new line'], removed: [], context: [] }
          }
        ],
        diff: 'sample diff'
      }
    end
    let(:test_discovery) do
      {
        test_files: ['spec/lib/example_spec.rb'],
        test_mapping: { 'spec/lib/example_spec.rb' => ['lib/example.rb'] }
      }
    end

    describe '#select_tests' do
      let(:ai_response) do
        <<~JSON
          ```json
          {
            "selected_tests": ["spec/lib/example_spec.rb"],
            "reasoning": {
              "direct_tests": ["spec/lib/example_spec.rb"],
              "indirect_tests": [],
              "risk_level": "low",
              "explanation": "Only direct test needed for simple change"
            }
          }
          ```
        JSON
      end

      before do
        allow(selector).to receive_messages(call_anthropic_api: ai_response, load_prompt_template: 'Test prompt with {{changed_files_summary}} placeholder')
      end

      it 'selects relevant tests using AI' do
        result = selector.select_tests(changes, test_discovery)

        expect(result[:selected_tests]).to eq(['spec/lib/example_spec.rb'])
        expect(result[:reasoning]['risk_level']).to eq('low')
      end
    end

    describe '#parse_ai_response' do
      context 'with valid JSON response' do
        let(:valid_response) do
          <<~JSON
            ```json
            {
              "selected_tests": ["spec/lib/example_spec.rb"],
              "reasoning": {
                "direct_tests": ["spec/lib/example_spec.rb"],
                "risk_level": "medium"
              }
            }
            ```
          JSON
        end

        it 'parses the response correctly' do
          result = selector.send(:parse_ai_response, valid_response, ['spec/lib/example_spec.rb'])

          expect(result[:selected_tests]).to eq(['spec/lib/example_spec.rb'])
          expect(result[:reasoning]['risk_level']).to eq('medium')
        end
      end

      context 'with invalid JSON response' do
        let(:invalid_response) { 'Invalid JSON response' }

        it 'falls back to running all tests' do
          available_tests = ['spec/lib/example_spec.rb', 'spec/lib/other_spec.rb']
          result = selector.send(:parse_ai_response, invalid_response, available_tests)

          expect(result[:selected_tests]).to eq(available_tests)
          expect(result[:reasoning]['risk_level']).to eq('high')
        end
      end
    end
  end

  describe SmartTestRunner do
    subject(:runner) { described_class.new(valid_config, mock_logger) }

    let(:valid_config) do
      instance_double(SmartTestConfig,
                      valid?: true,
                      base_ref: 'main',
                      commit_sha: 'abc123')
    end
    let(:changes) do
      {
        changed_files: [
          {
            path: 'lib/example.rb',
            type: :source,
            changes: { added: ['+ new line'], removed: [], context: [] }
          }
        ]
      }
    end
    let(:test_discovery) do
      {
        test_files: ['spec/lib/example_spec.rb'],
        test_mapping: { 'spec/lib/example_spec.rb' => ['lib/example.rb'] }
      }
    end
    let(:selection_result) do
      {
        selected_tests: ['spec/lib/example_spec.rb'],
        reasoning: { 'risk_level' => 'low', 'explanation' => 'Test explanation' }
      }
    end

    before do
      change_analyzer = instance_double(GitChangeAnalyzer)
      allow(GitChangeAnalyzer).to receive(:new).and_return(change_analyzer)
      allow(change_analyzer).to receive(:analyze_changes).and_return(changes)

      test_discovery_service = instance_double(TestDiscoveryService)
      allow(TestDiscoveryService).to receive(:new).and_return(test_discovery_service)
      allow(test_discovery_service).to receive(:discover_tests).and_return(test_discovery)

      ai_selector = instance_double(AITestSelector)
      allow(AITestSelector).to receive(:new).and_return(ai_selector)
      allow(ai_selector).to receive(:select_tests).and_return(selection_result)

      allow(File).to receive(:write)
      allow(JSON).to receive(:pretty_generate).and_return('{}')
      allow(Time).to receive(:now).and_return(Time.new(2025, 1, 1))
    end

    describe '#run' do
      it 'orchestrates the smart test selection process' do
        expect { runner.run }.not_to raise_error
        expect(mock_logger).to have_received(:info).with('🚀 Starting Smart Test Runner')
        expect(mock_logger).to have_received(:info).with('✅ Smart test selection completed')
      end

      it 'writes results to files' do
        runner.run

        expect(File).to have_received(:write).with('tmp/selected_tests.txt', 'spec/lib/example_spec.rb')
        expect(File).to have_received(:write).with('tmp/test_analysis.json', '{}')
        expect(File).to have_received(:write).with('tmp/ai_analysis.md', anything)
      end
    end

    context 'when no changes are detected' do
      let(:changes) { { changed_files: [] } }

      it 'skips test selection' do
        runner.run

        expect(mock_logger).to have_received(:info).with('✨ No relevant changes detected, skipping test selection')
      end
    end
  end
end
