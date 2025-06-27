# CircleCI Configuration

This project includes a comprehensive CircleCI configuration for continuous integration, security analysis, and code quality checks.

## 🚀 What's Included

### Jobs

1. **Test** - Runs RSpec tests with coverage reporting
2. **Security** - Brakeman security analysis  
3. **Lint** - RuboCop code style and quality checks
4. **Quality** - Combined quality assessment

### Workflows

- **test_and_quality** - Runs on every commit
- **nightly** - Comprehensive checks at 2 AM UTC daily

## 📊 Reports Generated

- **Test Results** - JUnit XML format for CircleCI integration
- **Coverage Reports** - HTML and JSON coverage reports
- **Security Reports** - Brakeman analysis in multiple formats
- **Lint Reports** - RuboCop analysis in JSON and HTML

## 🔧 Local Testing

Test your changes locally before pushing:

```bash
# Run the local CI simulation
./bin/ci-local

# Or run individual checks:
bundle exec rspec                    # Tests
COVERAGE=true bundle exec rspec      # Tests with coverage  
bundle exec rubocop                  # Linting
bundle exec brakeman                 # Security analysis
```

## 📋 Setup Instructions

1. **Connect your repository to CircleCI**
   - Go to [CircleCI](https://circleci.com/)
   - Sign up/in with your GitHub account
   - Add your project

2. **Environment Variables** (if needed)
   Add any required environment variables in CircleCI project settings:
   - `LINEAR_API_KEY` (for integration tests, if applicable)

## 🤝 Integration with GitHub Actions

This project also includes GitHub Actions for immediate PR feedback that complement CircleCI:

| Feature | GitHub Actions | CircleCI |
|---------|---------------|----------|
| **Trigger** | PR events (immediate) | All commits + nightly |
| **Feedback** | Inline PR comments | Detailed artifacts |
| **Speed** | Fast (< 2 min) | Comprehensive (5-10 min) |
| **Focus** | Quick validation | Full pipeline |

### GitHub Actions Features:
- 🔍 **Inline code review** with RuboCop violations
- 💬 **Automated PR comments** with security & quality summaries  
- 🎯 **Targeted testing** for changed files only
- 💨 **Smoke tests** for basic functionality
- 📊 **Coverage impact** analysis

See [`.github/ACTIONS.md`](.github/ACTIONS.md) for complete GitHub Actions documentation.

### Local Testing:
```bash
# Test GitHub Actions workflow locally
./bin/github-actions-test

# Test CircleCI workflow locally  
./bin/ci-local
```

## 🎯 Quality Gates

The CI pipeline enforces these quality standards:

- ✅ All tests must pass
- ✅ Code coverage above 85% (configurable in `spec_helper.rb`)
- ✅ No RuboCop offenses
- ✅ No high-severity security issues

## 📈 Coverage Tracking

Coverage reports are:
- Generated with SimpleCov
- Stored as CircleCI artifacts  
- Available for download after each build
- Viewable as HTML reports

## 🔍 Security Scanning

Brakeman scans for:
- SQL injection vulnerabilities
- Cross-site scripting (XSS)
- Command injection
- Other common security issues

## 🛠️ Customization

### Modify Quality Thresholds

Edit `spec/spec_helper.rb`:
```ruby
SimpleCov.start do
  minimum_coverage 85      # Overall coverage
  minimum_coverage_by_file 65  # Per-file coverage
end
```

### Add More Checks

Add jobs to `.circleci/config.yml`:
```yaml
jobs:
  custom_check:
    executor: ruby-executor
    steps:
      - setup_project
      - run: your-custom-command
```

### Modify Workflows

Update workflows in `.circleci/config.yml` to change:
- When jobs run
- Job dependencies
- Parallel execution

## 📚 Resources

- [CircleCI Documentation](https://circleci.com/docs/)
- [RSpec Documentation](https://rspec.info/)
- [RuboCop Documentation](https://rubocop.org/)
- [Brakeman Documentation](https://brakemanscanner.org/)
- [SimpleCov Documentation](https://github.com/simplecov-ruby/simplecov)
