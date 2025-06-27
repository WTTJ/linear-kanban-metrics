# GitHub Actions Configuration
# This file configures automatic workflows for code quality

## Workflows Overview

### 1. PR Analysis (`pr-analysis.yml`)
**Trigger**: Pull Request events (open, sync, reopen)
**Purpose**: Comprehensive quality gate for PRs

**Features**:
- 🔍 **RuboCop Analysis** with inline PR comments
- 🔒 **Security Scanning** with Brakeman
- 🧪 **Targeted Testing** for changed files
- 📊 **Coverage Impact** analysis
- 💨 **Smoke Tests** for CLI functionality
- 📝 **Automated PR Comments** with results summary

### 2. Coding Standards (`coding-standards.yml`)
**Trigger**: Pull Requests and pushes to main/master
**Purpose**: Focus specifically on code style and standards

**Features**:
- 🎨 **Style Analysis** with reviewdog integration
- 📋 **Standards Report** with violation summaries
- 💡 **Auto-fix Suggestions** in PR comments
- 🎯 **Filter Mode** - only checks added/modified lines

## Integration with CircleCI

These GitHub Actions complement your CircleCI pipeline:

| Check | GitHub Actions | CircleCI |
|-------|---------------|----------|
| **Quick Feedback** | ✅ Immediate PR feedback | ⏱️ Full pipeline |
| **Style Issues** | ✅ Inline comments | 📊 Detailed reports |
| **Security Scan** | ✅ Basic Brakeman | 🔒 Comprehensive analysis |
| **Test Coverage** | ✅ Impact analysis | 📈 Full coverage reports |
| **Smoke Tests** | ✅ CLI validation | 🧪 Complete test suite |

## Setup Instructions

### 1. Enable GitHub Actions
- Actions are automatically enabled for public repos
- For private repos: Go to repo Settings → Actions → Enable

### 2. Configure Permissions
The workflows use these permissions:
- `contents: read` - Read repository code
- `pull-requests: write` - Add PR comments
- `checks: write` - Update check status
- `statuses: write` - Set commit statuses

### 3. Customize Thresholds
Edit the workflows to adjust:

**Coverage Threshold** (in `pr-analysis.yml`):
```yaml
if (( $(echo "$coverage >= 85" | bc -l) )); then
```

**RuboCop Configuration**:
Uses your existing `.rubocop.yml` configuration

### 4. Branch Protection Rules
Recommended GitHub settings:
1. Go to Settings → Branches
2. Add rule for `main`/`master`
3. Enable:
   - ✅ Require status checks before merging
   - ✅ Require branches to be up to date
   - ✅ Include administrators

## Workflow Behavior

### Pull Request Flow
1. **Developer opens PR** → Triggers both workflows
2. **Style check runs** → Adds inline comments for violations
3. **Security scan** → Comments with vulnerability summary  
4. **Targeted tests** → Runs specs for changed files
5. **Coverage check** → Ensures no coverage regression
6. **Status updates** → Shows pass/fail in PR interface

### Comment Management
- **Single comment per workflow** - updates in place
- **Collapse on success** - minimal noise when passing
- **Detailed on failure** - actionable feedback for fixes

## Troubleshooting

### Common Issues

**1. RuboCop fails with "command not found"**
- Ensure RuboCop is in your Gemfile
- Check Ruby version compatibility

**2. Tests fail with missing dependencies**
- Verify `bundler-cache: true` is working
- Check if any system dependencies are needed

**3. Coverage check fails unexpectedly**
- Ensure SimpleCov is properly configured
- Check that `COVERAGE=true` environment variable is set

**4. PR comments not appearing**
- Verify `pull-requests: write` permission
- Check if repository is private (may need additional setup)

### Debug Mode
Enable debug logging by adding to workflow:
```yaml
env:
  ACTIONS_RUNNER_DEBUG: true
  ACTIONS_STEP_DEBUG: true
```

## Customization Examples

### Add Custom Checks
Add to any workflow job:
```yaml
- name: 🔧 Custom Check
  run: |
    # Your custom validation logic
    echo "Running custom checks..."
```

### Change Failure Behavior
Modify `fail_on_error` in RuboCop action:
```yaml
fail_on_error: false  # Don't fail PR, just comment
```

### Add More File Types
Extend file filters:
```yaml
filter_mode: added
filter_patterns: |
  *.rb
  *.yml
  *.md
```

## Performance Notes

- **Parallel execution** - Jobs run concurrently when possible
- **Caching** - Ruby gems cached via `bundler-cache: true`
- **Targeted testing** - Only tests related to changed files
- **Incremental analysis** - RuboCop only checks changed lines

## Security Considerations

- **No secrets required** - Uses default `GITHUB_TOKEN`
- **Read-only by default** - Only writes to PR comments/status
- **Sandboxed execution** - Runs in isolated GitHub runners
- **Audit trail** - All actions logged and traceable
