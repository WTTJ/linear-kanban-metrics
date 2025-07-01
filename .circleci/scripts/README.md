# CI Scripts

This directory contains all CI/CD scripts used by CircleCI and for local development.

## Scripts

- **`ci-test`** - Runs RSpec tests with coverage reporting
- **`ci-security`** - Runs Brakeman security analysis  
- **`ci-lint`** - Runs RuboCop code linting
- **`ci-quality`** - Runs comprehensive quality checks (combines all checks in one report)
- **`ci-runner`** - Master script to run any combination of checks

## Usage

### From project root directory:

```bash
# Run individual checks directly
./.circleci/scripts/ci-test
./.circleci/scripts/ci-security
./.circleci/scripts/ci-lint
./.circleci/scripts/ci-quality

# Use the master runner for individual checks (no duplication)
./.circleci/scripts/ci-runner test
./.circleci/scripts/ci-runner lint security
./.circleci/scripts/ci-runner all              # Runs test, security, lint (no duplication)

# Use comprehensive quality analysis (includes everything in one report)
./.circleci/scripts/ci-runner quality          # Runs all checks in one comprehensive report
./.circleci/scripts/ci-runner comprehensive    # Same as quality

# Use the convenience wrapper (same functionality)
bin/ci test
bin/ci lint security  
bin/ci all                                     # Individual checks
bin/ci quality                                 # Comprehensive report
```

## Output

All scripts create organized output in the `tmp/` directory:
- `tmp/test-results/` - Test results and coverage
- `tmp/security-results/` - Security analysis reports
- `tmp/lint-results/` - Linting reports  
- `tmp/quality-results/` - Combined quality summary

## Usage Recommendations

- **For development**: Use `bin/ci test` or `bin/ci lint` for quick individual checks
- **For comprehensive analysis**: Use `bin/ci quality` for a complete quality report (local development only)
- **For CI/CD**: Individual scripts run in parallel for efficient CI pipeline

## CircleCI Integration

The `.circleci/config.yml` file runs individual scripts in parallel (test, security, lint) for efficient CI execution. The quality script is available for local comprehensive analysis but not used in CI to avoid duplication.
