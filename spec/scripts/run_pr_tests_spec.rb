# frozen_string_literal: true

require 'spec_helper'
require_relative '../../scripts/run_pr_tests'

RSpec.describe 'PR Test Runner Script' do
  describe Scripts::Configuration do
    describe '#initialize' do
      it 'sets default base branch to main when no parameters provided' do
        # Arrange & Act
        subject = described_class.new

        # Assert
        expect(subject.base_branch).to eq('main')
      end

      it 'sets debug mode to false by default' do
        # Arrange & Act
        subject = described_class.new

        # Assert
        expect(subject.debug_mode).to be false
      end

      it 'accepts custom base branch parameter' do
        # Arrange & Act
        subject = described_class.new(base_branch: 'develop')

        # Assert
        expect(subject.base_branch).to eq('develop')
      end

      it 'accepts debug mode flag parameter' do
        # Arrange & Act
        subject = described_class.new(debug_mode: true)

        # Assert
        expect(subject.debug?).to be true
      end

      it 'validates branch name is a string and rejects nil' do
        # Arrange, Act & Assert
        expect do
          described_class.new(base_branch: nil)
        end.to raise_error(Scripts::ArgumentParsingError, 'Branch name must be a non-empty string')
      end

      it 'validates branch name is not empty string' do
        # Arrange, Act & Assert
        expect do
          described_class.new(base_branch: '')
        end.to raise_error(Scripts::ArgumentParsingError, 'Branch name must be a non-empty string')
      end

      it 'validates branch name is not whitespace only' do
        # Arrange, Act & Assert
        expect do
          described_class.new(base_branch: '   ')
        end.to raise_error(Scripts::ArgumentParsingError, 'Branch name must be a non-empty string')
      end

      it 'freezes the configuration object for immutability' do
        # Arrange & Act
        subject = described_class.new

        # Assert
        expect(subject).to be_frozen
      end
    end

    describe '#debug?' do
      it 'returns false when debug mode is disabled' do
        # Arrange & Act
        subject = described_class.new(debug_mode: false)

        # Assert
        expect(subject.debug?).to be false
      end

      it 'returns true when debug mode is enabled' do
        # Arrange & Act
        subject = described_class.new(debug_mode: true)

        # Assert
        expect(subject.debug?).to be true
      end
    end
  end

  describe Scripts::Colors do
    describe '.colorize' do
      it 'wraps text with ANSI color codes and reset sequence' do
        # Arrange
        text = 'test'
        color = described_class::GREEN

        # Act
        result = described_class.colorize(text, color)

        # Assert
        expect(result).to eq("\033[0;32mtest\033[0m")
      end

      it 'includes red color code for red text' do
        # Arrange & Act
        result = described_class.colorize('error', described_class::RED)

        # Assert
        expect(result).to include("\033[0;31m")
      end

      it 'includes yellow color code for yellow text' do
        # Arrange & Act
        result = described_class.colorize('warning', described_class::YELLOW)

        # Assert
        expect(result).to include("\033[1;33m")
      end

      it 'includes blue color code for blue text' do
        # Arrange & Act
        result = described_class.colorize('info', described_class::BLUE)

        # Assert
        expect(result).to include("\033[0;34m")
      end

      it 'always includes reset sequence at the end' do
        # Arrange & Act
        result = described_class.colorize('test', described_class::GREEN)

        # Assert
        expect(result).to end_with("\033[0m")
      end
    end
  end

  describe Scripts::GitOperations do
    describe '.current_branch' do
      it 'returns current branch name when available' do
        # Arrange
        allow(described_class).to receive(:execute_git_command)
          .with(['git', 'branch', '--show-current'])
          .and_return('feature-branch')

        # Act & Assert
        expect(described_class.current_branch).to eq('feature-branch')
      end

      it 'returns HEAD when no branch name available' do
        # Arrange
        allow(described_class).to receive(:execute_git_command)
          .with(['git', 'branch', '--show-current'])
          .and_return('')

        # Act & Assert
        expect(described_class.current_branch).to eq('HEAD')
      end
    end

    describe '.branch_exists?' do
      it 'returns true when branch exists in repository' do
        # Arrange
        allow(Open3).to receive(:capture3)
          .with('git', 'rev-parse', '--verify', 'main', stdin_data: '', err: File::NULL)
          .and_return(['', '', double(success?: true)])

        # Act & Assert
        expect(described_class.branch_exists?('main')).to be true
      end

      it 'returns false when branch does not exist' do
        # Arrange
        allow(Open3).to receive(:capture3)
          .with('git', 'rev-parse', '--verify', 'nonexistent', stdin_data: '', err: File::NULL)
          .and_return(['', '', double(success?: false)])

        # Act & Assert
        expect(described_class.branch_exists?('nonexistent')).to be false
      end

      it 'returns false for nil branch name input' do
        # Act & Assert
        expect(described_class.branch_exists?(nil)).to be false
      end

      it 'returns false for empty branch name input' do
        # Act & Assert
        expect(described_class.branch_exists?('')).to be false
      end

      it 'returns false for whitespace-only branch name input' do
        # Act & Assert
        expect(described_class.branch_exists?('   ')).to be false
      end

      it 'uses Open3 for safe command execution' do
        # Arrange
        allow(Open3).to receive(:capture3)
          .and_return(['', '', double(success?: true)])

        # Act
        described_class.branch_exists?('feature/test-branch')

        # Assert
        expect(Open3).to have_received(:capture3)
          .with('git', 'rev-parse', '--verify', 'feature/test-branch', stdin_data: '', err: File::NULL)
      end
    end

    describe '.diff_files' do
      it 'returns array of changed files when files exist' do
        # Arrange
        allow(described_class).to receive(:execute_git_command)
          .and_return("file1.rb\nfile2.rb\nfile3.rb")

        # Act
        result = described_class.diff_files('--cached')

        # Assert
        expect(result).to eq(['file1.rb', 'file2.rb', 'file3.rb'])
      end

      it 'returns empty array when no files changed' do
        # Arrange
        allow(described_class).to receive(:execute_git_command)
          .and_return('')

        # Act
        result = described_class.diff_files('--cached')

        # Assert
        expect(result).to eq([])
      end

      it 'removes empty lines and duplicates from output' do
        # Arrange
        allow(described_class).to receive(:execute_git_command)
          .and_return("file1.rb\n\nfile2.rb\nfile1.rb\n")

        # Act
        result = described_class.diff_files('')

        # Assert
        expect(result).to eq(['file1.rb', 'file2.rb'])
      end
    end

    describe '.repository_exists?' do
      it 'returns true when in git repository' do
        # Arrange
        allow(Open3).to receive(:capture3)
          .with('git', 'rev-parse', '--git-dir', stdin_data: '', err: File::NULL)
          .and_return(['', '', double(success?: true)])

        # Act & Assert
        expect(described_class.repository_exists?).to be true
      end

      it 'returns false when not in git repository' do
        # Arrange
        allow(Open3).to receive(:capture3)
          .with('git', 'rev-parse', '--git-dir', stdin_data: '', err: File::NULL)
          .and_return(['', '', double(success?: false)])

        # Act & Assert
        expect(described_class.repository_exists?).to be false
      end
    end
  end

  describe Scripts::SpecFileLocator do
    describe '.find_spec_for' do
      context 'with lib files' do
        it 'maps lib files to spec/lib pattern when spec exists' do
          # Arrange
          allow(File).to receive(:exist?).with('spec/lib/kanban_metrics_spec.rb').and_return(true)

          # Act
          result = described_class.find_spec_for('lib/kanban_metrics.rb')

          # Assert
          expect(result).to eq('spec/lib/kanban_metrics_spec.rb')
        end

        it 'maps nested lib files correctly when spec exists' do
          # Arrange
          allow(File).to receive(:exist?)
            .with('spec/lib/kanban_metrics/calculator_spec.rb')
            .and_return(true)

          # Act
          result = described_class.find_spec_for('lib/kanban_metrics/calculator.rb')

          # Assert
          expect(result).to eq('spec/lib/kanban_metrics/calculator_spec.rb')
        end

        it 'returns nil when spec file does not exist for lib file' do
          # Arrange
          allow(File).to receive(:exist?).and_return(false)

          # Act
          result = described_class.find_spec_for('lib/nonexistent.rb')

          # Assert
          expect(result).to be_nil
        end
      end

      context 'with app files' do
        it 'maps app files to spec pattern when spec exists' do
          # Arrange
          allow(File).to receive(:exist?).with('spec/models/user_spec.rb').and_return(true)

          # Act
          result = described_class.find_spec_for('app/models/user.rb')

          # Assert
          expect(result).to eq('spec/models/user_spec.rb')
        end

        it 'returns nil when spec file does not exist for app file' do
          # Arrange
          allow(File).to receive(:exist?).and_return(false)

          # Act
          result = described_class.find_spec_for('app/models/user.rb')

          # Assert
          expect(result).to be_nil
        end
      end

      context 'with github scripts files' do
        it 'maps github scripts to spec pattern when spec exists' do
          # Arrange
          allow(File).to receive(:exist?)
            .with('spec/github/scripts/pr_review_spec.rb')
            .and_return(true)

          # Act
          result = described_class.find_spec_for('.github/scripts/pr_review.rb')

          # Assert
          expect(result).to eq('spec/github/scripts/pr_review_spec.rb')
        end
      end

      context 'with generic files' do
        it 'falls back to basename search when direct mapping fails' do
          # Arrange
          allow(Dir).to receive(:glob)
            .with('spec/**/*calculator*_spec.rb')
            .and_return(['spec/lib/calculator_spec.rb'])

          # Act
          result = described_class.find_spec_for('some/path/calculator.rb')

          # Assert
          expect(result).to eq('spec/lib/calculator_spec.rb')
        end
      end

      context 'with invalid inputs' do
        it 'returns nil for nil input' do
          # Act & Assert
          expect(described_class.find_spec_for(nil)).to be_nil
        end

        it 'returns nil for non-Ruby files' do
          # Act & Assert
          expect(described_class.find_spec_for('README.md')).to be_nil
        end
      end
    end

    describe '.find_spec_for with generic files' do
      it 'finds spec files by basename when they exist' do
        # Arrange
        allow(Dir).to receive(:glob)
          .with('spec/**/*calculator*_spec.rb')
          .and_return(['spec/lib/calculator_spec.rb'])

        # Act
        result = described_class.find_spec_for('calculator.rb')

        # Assert
        expect(result).to eq('spec/lib/calculator_spec.rb')
      end

      it 'returns nil for empty basename input' do
        # Act & Assert
        expect(described_class.find_spec_for('.rb')).to be_nil
      end

      it 'returns nil for nil basename input' do
        # Act & Assert
        expect(described_class.find_spec_for(nil)).to be_nil
      end

      it 'prevents directory traversal attacks with parent directory references' do
        # Act & Assert
        expect(described_class.find_spec_for('../etc/passwd.rb')).to be_nil
      end

      it 'prevents directory traversal attacks with path separators' do
        # Act & Assert
        expect(described_class.find_spec_for('path/to/file.rb')).to be_nil
      end

      it 'sanitizes special characters from basename' do
        # Arrange
        allow(Dir).to receive(:glob)
          .with('spec/**/*test*_spec.rb')
          .and_return(['spec/lib/test_spec.rb'])

        # Act
        result = described_class.find_spec_for('test!@#$%.rb')

        # Assert
        expect(result).to eq('spec/lib/test_spec.rb')
      end

      it 'returns nil when sanitized basename becomes empty' do
        # Act & Assert
        expect(described_class.find_spec_for('!@#$%.rb')).to be_nil
      end

      it 'ensures result path is within spec directory for security' do
        # Arrange
        allow(Dir).to receive(:glob)
          .and_return(['../malicious_spec.rb', 'spec/lib/safe_spec.rb'])

        # Act
        result = described_class.find_spec_for('test.rb')

        # Assert
        expect(result).to eq('spec/lib/safe_spec.rb')
      end
    end
  end

  describe Scripts::ChangeDetector do
    subject(:detector) { described_class.new(config) }

    let(:config) { Scripts::Configuration.new(base_branch: 'main', debug_mode: false) }

    before do
      allow(Scripts::OutputFormatter).to receive(:info)
      allow(Scripts::OutputFormatter).to receive(:success)
      allow(Scripts::GitOperations).to receive_messages(
        branch_exists?: false,
        diff_files: [],
        current_branch: 'feature-branch'
      )
    end

    describe '#find_changed_files' do
      it 'prints current branch status information' do
        # Act
        detector.find_changed_files

        # Assert
        expect(Scripts::OutputFormatter).to have_received(:info).with('🔍 Current branch: feature-branch')
      end

      it 'prints base branch comparison information' do
        # Act
        detector.find_changed_files

        # Assert
        expect(Scripts::OutputFormatter).to have_received(:info).with('🔍 Comparing against: main')
      end

      it 'returns files from branch comparison when base branch exists' do
        # Arrange
        allow(Scripts::GitOperations).to receive(:branch_exists?).with('main').and_return(true)
        allow(Scripts::GitOperations).to receive(:diff_files)
          .with('main...HEAD')
          .and_return(['file1.rb', 'file2.rb'])

        # Act
        result = detector.find_changed_files

        # Assert
        expect(result).to eq(['file1.rb', 'file2.rb'])
      end

      it 'falls back to uncommitted changes when base branch does not exist' do
        # Arrange
        allow(Scripts::GitOperations).to receive(:branch_exists?).with('main').and_return(false)
        allow(Scripts::GitOperations).to receive(:diff_files)
          .with('')
          .and_return(['uncommitted.rb'])

        # Act
        result = detector.find_changed_files

        # Assert
        expect(result).to eq(['uncommitted.rb'])
      end

      it 'falls back to staged changes when no uncommitted changes' do
        # Arrange
        allow(Scripts::GitOperations).to receive_messages(
          branch_exists?: false,
          diff_files: []
        )
        allow(Scripts::GitOperations).to receive(:diff_files)
          .with('--cached')
          .and_return(['staged.rb'])

        # Act
        result = detector.find_changed_files

        # Assert
        expect(result).to eq(['staged.rb'])
      end

      it 'falls back to last commit changes when no staged changes' do
        # Arrange
        allow(Scripts::GitOperations).to receive_messages(
          branch_exists?: false,
          diff_files: []
        )
        allow(Scripts::GitOperations).to receive(:diff_files).with('--cached').and_return([])
        allow(Scripts::GitOperations).to receive(:diff_files)
          .with('HEAD~1')
          .and_return(['last_commit.rb'])

        # Act
        result = detector.find_changed_files

        # Assert
        expect(result).to eq(['last_commit.rb'])
      end

      it 'returns empty array when no changes found by any method' do
        # Arrange
        allow(Scripts::GitOperations).to receive_messages(
          branch_exists?: false,
          diff_files: []
        )

        # Act
        result = detector.find_changed_files

        # Assert
        expect(result).to eq([])
      end
    end
  end

  describe Scripts::TestExecutor do
    subject(:executor) { described_class.new(config) }

    let(:config) { Scripts::Configuration.new(debug_mode: false) }

    before do
      allow(Scripts::OutputFormatter).to receive(:info)
      allow(Scripts::OutputFormatter).to receive(:success)
      allow(Scripts::OutputFormatter).to receive(:warning)
    end

    describe '#process_files' do
      it 'displays header message for changed files' do
        # Arrange
        files = ['lib/test.rb', 'app/model.rb']

        # Act
        executor.process_files(files)

        # Assert
        expect(Scripts::OutputFormatter).to have_received(:info).with('📁 Changed files:')
      end

      it 'displays each changed file to stdout' do
        # Arrange
        files = ['lib/test.rb', 'app/model.rb']

        # Act & Assert
        expect { executor.process_files(files) }.to output(%r{lib/test\.rb}).to_stdout
      end

      it 'collects spec files for Ruby files when spec exists' do
        # Arrange
        allow(Scripts::SpecFileLocator).to receive(:find_spec_for)
          .with('lib/test.rb')
          .and_return('spec/lib/test_spec.rb')
        allow(File).to receive(:exist?)
          .with('spec/lib/test_spec.rb')
          .and_return(true)

        # Act
        executor.process_files(['lib/test.rb'])

        # Assert - Verify the success message is shown, indicating spec was found
        expect(Scripts::OutputFormatter).to have_received(:success).with('✅ Found spec: spec/lib/test_spec.rb for lib/test.rb')
      end

      it 'warns when no spec file found for Ruby file' do
        # Arrange
        allow(Scripts::SpecFileLocator).to receive(:find_spec_for).and_return(nil)

        # Act
        executor.process_files(['lib/test.rb'])

        # Assert
        expect(Scripts::OutputFormatter).to have_received(:warning).with('⚠️  No spec found for: lib/test.rb')
      end

      it 'ignores non-Ruby files during processing' do
        # Arrange
        allow(Scripts::SpecFileLocator).to receive(:find_spec_for)

        # Act
        executor.process_files(['README.md', 'config.yml'])

        # Assert - No spec locator should be called for non-Ruby files
        expect(Scripts::SpecFileLocator).not_to have_received(:find_spec_for)
      end
    end

    describe '#run_tests' do
      it 'warns when no spec files found for execution' do
        # Arrange - No files processed, so @spec_files will be nil/empty

        # Act
        executor.run_tests

        # Assert
        expect(Scripts::OutputFormatter).to have_received(:warning)
          .with('No spec files found for changed Ruby files')
      end

      it 'validates bundle command exists before running tests' do
        # Arrange
        allow(Scripts::SpecFileLocator).to receive(:find_spec_for)
          .with('lib/test.rb')
          .and_return('spec/lib/test_spec.rb')
        allow(File).to receive(:exist?)
          .with('spec/lib/test_spec.rb')
          .and_return(true)
        allow(Scripts::TestEnvironmentValidator).to receive(:validate!)
          .and_raise(Scripts::CommandNotFoundError.new('bundle command not found. Please install bundler.'))

        # Act
        executor.process_files(['lib/test.rb'])

        # Assert
        expect { executor.run_tests }.to raise_error(
          Scripts::CommandNotFoundError,
          'bundle command not found. Please install bundler.'
        )
      end

      it 'executes rspec command successfully when tests pass' do
        # Arrange
        runner_double = instance_double(Scripts::RSpecRunner)
        allow(Scripts::RSpecRunner).to receive(:new).and_return(runner_double)
        allow(runner_double).to receive(:call).and_return(true)

        executor = described_class.new(config)
        allow(Scripts::SpecFileLocator).to receive(:find_spec_for)
          .with('lib/test.rb')
          .and_return('spec/lib/test_spec.rb')
        allow(File).to receive(:exist?)
          .with('spec/lib/test_spec.rb')
          .and_return(true)
        allow(Scripts::TestEnvironmentValidator).to receive(:validate!)

        # Act
        executor.process_files(['lib/test.rb'])

        # Assert
        expect { executor.run_tests }.not_to raise_error
      end

      it 'raises TestFailureError when tests fail' do
        # Arrange
        runner_double = instance_double(Scripts::RSpecRunner)
        allow(Scripts::RSpecRunner).to receive(:new).and_return(runner_double)
        allow(runner_double).to receive(:call)
          .and_raise(Scripts::TestFailureError.new('Some tests failed'))

        executor = described_class.new(config)
        allow(Scripts::SpecFileLocator).to receive(:find_spec_for)
          .with('lib/test.rb')
          .and_return('spec/lib/test_spec.rb')
        allow(File).to receive(:exist?)
          .with('spec/lib/test_spec.rb')
          .and_return(true)
        allow(Scripts::TestEnvironmentValidator).to receive(:validate!)

        # Act
        executor.process_files(['lib/test.rb'])

        # Assert
        expect { executor.run_tests }.to raise_error(Scripts::TestFailureError, 'Some tests failed')
      end
    end
  end

  describe Scripts::OutputFormatter do
    describe '.info' do
      it 'outputs blue colored text to stdout' do
        # Arrange & Act
        expect(Scripts::Colors).to receive(:colorize).with('test message', Scripts::Colors::BLUE)

        # Assert
        expect { described_class.info('test message') }.to output.to_stdout
      end
    end

    describe '.success' do
      it 'outputs green colored text to stdout' do
        # Arrange & Act
        expect(Scripts::Colors).to receive(:colorize).with('success message', Scripts::Colors::GREEN)

        # Assert
        expect { described_class.success('success message') }.to output.to_stdout
      end
    end

    describe '.warning' do
      it 'outputs yellow colored text to stdout' do
        # Arrange & Act
        expect(Scripts::Colors).to receive(:colorize).with('warning message', Scripts::Colors::YELLOW)

        # Assert
        expect { described_class.warning('warning message') }.to output.to_stdout
      end
    end

    describe '.error' do
      it 'outputs red colored text with error prefix to stdout' do
        # Arrange & Act
        expect(Scripts::Colors).to receive(:colorize).with('❌ Error: error message', Scripts::Colors::RED)

        # Assert
        expect { described_class.error('error message') }.to output.to_stdout
      end
    end
  end

  describe Scripts::ArgumentParser do
    subject(:parser) { described_class.new }

    describe '#parse' do
      it 'returns default configuration for empty arguments' do
        # Act
        config = parser.parse([])

        # Assert
        expect(config.base_branch).to eq('main')
      end

      it 'returns debug mode false by default' do
        # Act
        config = parser.parse([])

        # Assert
        expect(config.debug?).to be false
      end

      it 'sets custom base branch from first argument' do
        # Act
        config = parser.parse(['develop'])

        # Assert
        expect(config.base_branch).to eq('develop')
      end

      it 'enables debug mode with --debug flag' do
        # Act
        config = parser.parse(['--debug'])

        # Assert
        expect(config.debug?).to be true
      end

      it 'enables debug mode with -d shorthand flag' do
        # Act
        config = parser.parse(['-d'])

        # Assert
        expect(config.debug?).to be true
      end

      it 'combines base branch and debug flag correctly' do
        # Act
        config = parser.parse(['feature-branch', '--debug'])

        # Assert
        aggregate_failures do
          expect(config.base_branch).to eq('feature-branch')
          expect(config.debug?).to be true
        end
      end

      it 'shows help and exits with --help flag' do
        # Act & Assert
        expect { parser.parse(['--help']) }.to raise_error(SystemExit)
      end

      it 'shows help and exits with -h shorthand flag' do
        # Act & Assert
        expect { parser.parse(['-h']) }.to raise_error(SystemExit)
      end

      it 'raises SystemExit for invalid options' do
        # Arrange
        allow(Scripts::OutputFormatter).to receive(:error)

        # Act & Assert
        expect { parser.parse(['--invalid']) }.to raise_error(SystemExit)
      end
    end
  end

  describe Scripts::DebugInfoProvider do
    subject(:provider) { described_class.new(config) }

    let(:config) { Scripts::Configuration.new(base_branch: 'main') }

    before do
      allow(Scripts::OutputFormatter).to receive(:error)
      allow(Scripts::OutputFormatter).to receive(:info)
      allow(Scripts::GitOperations).to receive(:current_branch).and_return('feature-branch')
    end

    describe '#show_debug_info' do
      it 'shows error message about no files found' do
        # Arrange
        allow(provider).to receive(:show_git_status)
        allow(provider).to receive(:show_suggestions)

        # Act
        provider.show_debug_info

        # Assert
        expect(Scripts::OutputFormatter).to have_received(:error)
          .with('No files changed found using any method')
      end

      it 'shows current branch information in output' do
        # Arrange
        allow(provider).to receive(:show_git_status)
        allow(provider).to receive(:show_suggestions)

        # Act & Assert
        expect { provider.show_debug_info }.to output(/Current branch: feature-branch/).to_stdout
      end

      it 'shows git status information in output' do
        # Arrange
        allow(provider).to receive(:show_git_status) do
          puts '    M file.rb'
        end
        allow(provider).to receive(:show_suggestions)

        # Act & Assert
        expect { provider.show_debug_info }.to output(/ M file\.rb/).to_stdout
      end

      it 'shows suggestions in output when not mocked' do
        # Arrange
        allow(provider).to receive(:show_git_status)
        allow(Scripts::OutputFormatter).to receive(:info).and_call_original

        # Act & Assert
        expect { provider.show_debug_info }.to output(/Try one of these/).to_stdout
      end
    end
  end

  describe Scripts::TestRunnerWorkflow do
    subject(:workflow) { described_class.new(config) }

    let(:config) { Scripts::Configuration.new(base_branch: 'main', debug_mode: false) }

    before do
      allow(Scripts::OutputFormatter).to receive(:error)
      allow(Scripts::OutputFormatter).to receive(:info)
      allow(Scripts::GitOperations).to receive(:repository_exists?).and_return(true)
    end

    describe '#execute' do
      it 'validates git environment before proceeding' do
        # Arrange
        allow(Scripts::GitOperations).to receive(:repository_exists?).and_return(false)

        # Act & Assert
        expect { workflow.execute }.to raise_error(
          Scripts::GitRepositoryError,
          'Not in a git repository'
        )
      end

      it 'detects file changes and processes them when files found' do
        # Arrange
        changed_files = ['lib/test.rb']
        change_detector = instance_double(Scripts::ChangeDetector, find_changed_files: changed_files)
        test_executor = instance_double(Scripts::TestExecutor, process_files: nil, run_tests: nil)

        allow(Scripts::ChangeDetector).to receive(:new).with(config).and_return(change_detector)
        allow(Scripts::TestExecutor).to receive(:new).with(config).and_return(test_executor)

        # Act
        workflow.execute

        # Assert
        expect(test_executor).to have_received(:process_files).with(changed_files)
        expect(test_executor).to have_received(:run_tests)
      end

      it 'shows debug info and exits when no files found' do
        # Arrange
        change_detector = instance_double(Scripts::ChangeDetector, find_changed_files: [])
        debug_provider = instance_double(Scripts::DebugInfoProvider, show_debug_info: nil)

        allow(Scripts::ChangeDetector).to receive(:new).with(config).and_return(change_detector)
        allow(Scripts::DebugInfoProvider).to receive(:new).with(config).and_return(debug_provider)

        # Act & Assert
        expect { workflow.execute }.to raise_error(SystemExit)
        expect(debug_provider).to have_received(:show_debug_info)
      end

      it 'raises GitRepositoryError with context when not in git repo' do
        # Arrange
        allow(Scripts::GitOperations).to receive(:repository_exists?).and_return(false)
        allow(Dir).to receive(:pwd).and_return('/tmp/test')

        # Act & Assert
        expect { workflow.execute }.to raise_error do |error|
          expect(error).to be_a(Scripts::GitRepositoryError)
          expect(error.message).to eq('Not in a git repository')
          expect(error.context[:working_directory]).to eq('/tmp/test')
        end
      end
    end
  end

  describe 'Custom Exceptions' do
    describe Scripts::TestRunnerError do
      it 'stores context information when provided' do
        # Arrange & Act
        error = described_class.new('test message', context: { key: 'value' })

        # Assert
        aggregate_failures do
          expect(error.message).to eq('test message')
          expect(error.context).to eq({ key: 'value' })
        end
      end

      it 'defaults to empty context when none provided' do
        # Arrange & Act
        error = described_class.new('test message')

        # Assert
        expect(error.context).to eq({})
      end
    end

    describe 'Error hierarchy inheritance' do
      it 'ensures GitRepositoryError inherits from TestRunnerError' do
        # Act & Assert
        expect(Scripts::GitRepositoryError.new('test')).to be_a(Scripts::TestRunnerError)
      end

      it 'ensures CommandNotFoundError inherits from TestRunnerError' do
        # Act & Assert
        expect(Scripts::CommandNotFoundError.new('test')).to be_a(Scripts::TestRunnerError)
      end

      it 'ensures TestFailureError inherits from TestRunnerError' do
        # Act & Assert
        expect(Scripts::TestFailureError.new('test')).to be_a(Scripts::TestRunnerError)
      end

      it 'ensures ArgumentParsingError inherits from TestRunnerError' do
        # Act & Assert
        expect(Scripts::ArgumentParsingError.new('test')).to be_a(Scripts::TestRunnerError)
      end
    end
  end
end
