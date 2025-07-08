# 🤖 AI Test Runner

An AI-powered GitHub Action that intelligently selects and runs only the tests relevant to your code changes, reducing CI time while maintaining comprehensive coverage.

## Features

- **🧠 AI-Powered Analysis**: Uses Claude 3 Sonnet to analyze code changes and understand test dependencies
- **🎯 AI Test Selection**: Identifies both direct and indirect tests that may be affected by changes
- **⚡ Performance Optimization**: Runs only relevant tests instead of the entire test suite
- **📊 Detailed Reporting**: Provides comprehensive analysis of why tests were selected
- **🔄 Fallback Safety**: Falls back to running all tests if AI analysis fails
- **🔧 Flexible Configuration**: Supports multiple AI providers (Anthropic Claude, Dust)

## How It Works

1. **Change Analysis**: Analyzes git diff to understand what files have changed
2. **Test Discovery**: Maps source files to their corresponding test files
3. **AI Selection**: Uses AI to determine which tests are directly or indirectly affected
4. **Smart Execution**: Runs only the selected tests in your CI pipeline

## Quick Start

### 1. Add GitHub Secrets

Add the following secrets to your GitHub repository:

```bash
# For Anthropic Claude (recommended)
ANTHROPIC_API_KEY=your_anthropic_api_key

# Alternative: For Dust API
DUST_API_KEY=your_dust_api_key
DUST_WORKSPACE_ID=your_workspace_id
DUST_AGENT_ID=your_agent_id
```

### 2. Configure Variables (Optional)

Set repository variables:

- `API_PROVIDER`: `anthropic` (default) or `dust`

### 3. The Workflow is Ready!

The AI test runner is already configured in `.github/workflows/smart_tests.yml` and will automatically:

- Trigger on pushes to `main` and `develop` branches
- Trigger on pull requests to `main` and `develop` branches
- Analyze your changes and select relevant tests
- Run only the necessary tests

## Manual Usage

You can also run the AI test selector locally:

```bash
# Set required environment variables
export GITHUB_REPOSITORY=owner/repo
export COMMIT_SHA=$(git rev-parse HEAD)
export BASE_REF=main
export GITHUB_TOKEN=your_github_token
export ANTHROPIC_API_KEY=your_anthropic_key

# Run the AI test selector
bundle exec ruby .github/scripts/ai_test_runner.rb

# Check selected tests
cat tmp/selected_tests.txt

# View detailed analysis
cat tmp/ai_analysis.md
```

## Configuration

### Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `GITHUB_REPOSITORY` | Yes | - | Repository in format `owner/repo` |
| `GITHUB_TOKEN` | Yes | - | GitHub token for API access |
| `COMMIT_SHA` | Yes | - | Commit SHA to analyze |
| `BASE_REF` | No | `main` | Base branch to compare against |
| `PR_NUMBER` | No | - | Pull request number (auto-set in workflows) |
| `API_PROVIDER` | No | `anthropic` | AI provider: `anthropic` or `dust` |
| `ANTHROPIC_API_KEY` | Yes* | - | Anthropic API key (*if using Anthropic) |
| `DUST_API_KEY` | Yes* | - | Dust API key (*if using Dust) |
| `DUST_WORKSPACE_ID` | Yes* | - | Dust workspace ID (*if using Dust) |
| `DUST_AGENT_ID` | Yes* | - | Dust agent ID (*if using Dust) |

### Test Selection Logic

The AI considers multiple factors when selecting tests:

#### Direct Tests
- Tests that directly test the changed source files
- Based on file path conventions (`lib/foo.rb` → `spec/lib/foo_spec.rb`)
- Analysis of `describe` blocks and `require` statements

#### Indirect Tests
- Tests that may be affected through:
  - Module inclusion and inheritance
  - Dependency injection
  - Shared interfaces or contracts
  - Integration points
  - Configuration changes

#### Risk Assessment
- **Low Risk**: Internal implementation changes → Focus on direct tests
- **Medium Risk**: API changes → Include related integration tests
- **High Risk**: Breaking changes → Run comprehensive test coverage

## Output Files

The AI test runner generates several output files:

### `tmp/selected_tests.txt`
Simple list of selected test files (one per line) used by the GitHub workflow.

### `tmp/test_analysis.json`
Detailed JSON analysis including:
```json
{
  "selected_tests": ["spec/lib/example_spec.rb"],
  "total_available_tests": 42,
  "selection_reasoning": {
    "direct_tests": ["spec/lib/example_spec.rb"],
    "indirect_tests": [],
    "risk_level": "low",
    "explanation": "Only direct test needed..."
  },
  "changed_files": [...],
  "timestamp": "2025-01-01T12:00:00Z"
}
```

### `tmp/ai_analysis.md`
Human-readable markdown report with:
- Summary statistics
- List of selected tests with reasoning
- Changed files analysis
- Direct vs indirect test breakdown

## Examples

### Example 1: Simple Source File Change

**Changed File**: `lib/kanban_metrics/calculators/flow_efficiency_calculator.rb`

**AI Analysis**: 
- Risk Level: Low
- Selected Tests: `spec/lib/kanban_metrics/calculators/flow_efficiency_calculator_spec.rb`
- Reasoning: "Internal implementation change in calculator. Direct test coverage sufficient."

### Example 2: API Change

**Changed File**: `lib/kanban_metrics/domain/issue.rb`

**AI Analysis**:
- Risk Level: Medium  
- Selected Tests:
  - `spec/lib/kanban_metrics/domain/issue_spec.rb` (direct)
  - `spec/lib/kanban_metrics/calculators/*_spec.rb` (indirect)
  - `spec/integration/kanban_metrics_integration_spec.rb` (integration)
- Reasoning: "Domain model change affects multiple calculators and integration flows."

### Example 3: Configuration Change

**Changed File**: `Gemfile`

**AI Analysis**:
- Risk Level: High
- Selected Tests: All tests
- Reasoning: "Dependency changes require full test suite to ensure compatibility."

## Troubleshooting

### Common Issues

#### 1. AI Analysis Fails
The system automatically falls back to running all tests if AI analysis fails.

Check logs for:
```
ERROR: Error calling Anthropic API: ...
WARN: AI analysis failed, running all tests as fallback
```

#### 2. Invalid Configuration
```
ERROR: Invalid configuration
```

Verify all required environment variables are set correctly.

#### 3. No Tests Selected
```
INFO: No relevant changes detected, skipping test selection
```

This happens when only documentation or non-code files are changed.

### Debug Mode

Enable debug logging by setting the log level:

```ruby
logger = Logger.new($stdout, level: Logger::DEBUG)
runner = AITestRunner.new(config, logger)
```

## Contributing

### Running Tests

```bash
# Run the AI test runner tests
bundle exec rspec spec/github/scripts/ai_test_runner_spec.rb

# Run all tests
bundle exec rspec
```

### Adding New Features

1. Add your feature to the appropriate class in `ai_test_runner.rb`
2. Add corresponding tests in `spec/github/scripts/ai_test_runner_spec.rb`
3. Update this README if needed
4. Test with real changes to ensure AI selection works correctly

### Improving AI Prompts

The AI prompt is defined in `.github/scripts/ai_test_runner_prompt.md` as an external template file. This allows for:

- **Easy maintenance**: Update prompts without touching Ruby code
- **Version control**: Track prompt changes separately
- **Collaboration**: Non-developers can improve prompts
- **A/B testing**: Easy to test different prompt variations

Key considerations for prompt improvements:

- Be specific about Ruby conventions and testing patterns
- Provide clear examples of direct vs indirect dependencies
- Include risk assessment guidelines
- Maintain the JSON output format for parsing
- Use placeholder syntax: `{{variable_name}}` for dynamic content

The system automatically falls back to a built-in prompt if the external file is missing or unreadable.

## Architecture

```
AITestRunner
├── AITestConfig             # Configuration management
├── GitChangeAnalyzer        # Git diff analysis and parsing
├── TestDiscoveryService     # Test file discovery and mapping
├── AITestSelector          # AI-powered test selection
│   └── ai_test_runner_prompt.md  # External AI prompt template
└── AITestRunner            # Main orchestrator
```

## Performance Benefits

Based on typical Ruby projects:

- **50-80% reduction** in test execution time for small changes
- **20-40% reduction** for medium-sized changes  
- **Fallback protection** ensures no tests are missed
- **CI cost savings** from reduced compute time

## Security Considerations

- API keys are stored as GitHub secrets
- File path validation prevents directory traversal
- Input sanitization for git commands
- Limited file access to approved directories only

## License

This project is part of the Linear Kanban Metrics tool and follows the same license terms.
