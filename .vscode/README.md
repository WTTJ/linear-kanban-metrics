# VS Code Tasks

This document describes the available VS Code tasks configured in `.vscode/tasks.json`.

## Quick Start

Press `Cmd+Shift+P` (Mac) or `Ctrl+Shift+P` (Windows/Linux) and type "Tasks: Run Task" to see all available tasks.

## Task Categories

### 🏗️ Build & Setup Tasks

**Bundle Install**
- Installs Ruby gem dependencies
- Command: `bundle install`
- Group: build

**Setup Development Environment** ⭐
- Complete development setup sequence
- Runs: Bundle Install → Generate .env from 1Password  
- Group: build
- **Recommended for first-time setup**

### 🔐 Environment Configuration

**Generate .env from 1Password**
- Generates `.env` file from 1Password template
- Command: `./bin/env-handler`
- Group: build
- **Safe**: Creates backup of existing `.env` file

**Generate .env (Preview)** 🔍
- Preview what would be generated without making changes
- Command: `./bin/env-handler --dry-run --verbose`
- Group: build
- **Safe**: Read-only operation, no files modified

### 🧪 Testing Tasks

**Run Tests** (Default Test Task)
- Runs all RSpec tests
- Command: `bundle exec rspec`
- Group: test (default)
- Keyboard shortcut: `Cmd+Shift+T` (Mac)

**Run Tests with Coverage**
- Runs RSpec tests with SimpleCov coverage report
- Command: `bundle exec rspec` with `COVERAGE=true`
- Group: test
- Generates coverage report in `coverage/` directory

**Run Specific Test File**
- Runs tests for currently open file
- Command: `bundle exec rspec ${file}`
- Group: test
- **Usage**: Open a spec file and run this task

### 🔍 Code Quality Tasks

**Run RuboCop**
- Static code analysis and linting
- Command: `bundle exec rubocop`
- Group: build
- Includes problem matcher for VS Code integration

**Run RuboCop Auto-fix**
- Auto-fix correctable RuboCop offenses
- Command: `bundle exec rubocop -A`
- Group: build
- **Modifies files**: Review changes before committing

**Run Brakeman Security Scan**
- Security vulnerability analysis
- Command: `bundle exec brakeman --force`
- Group: build

**Validate Shell Scripts** 🐚
- Validates Bash scripts with shellcheck
- Command: `shellcheck scripts/*.sh bin/env-handler`
- Group: build
- Includes problem matcher for VS Code integration

### 🚀 Application Tasks

**Run Kanban Metrics**
- Executes the main application
- Command: `./bin/kanban_metrics`
- Group: build

**Run Kanban Metrics (JSON output)**
- Runs application with JSON output format
- Command: `./bin/kanban_metrics --format json`
- Group: build

### 🔄 Automation Tasks

**Run Guard**
- Starts file watcher for automated testing and linting
- Command: `bundle exec guard`
- Group: build
- **Background task**: Runs continuously
- **Panel**: Dedicated terminal

### 🏭 CI/CD Tasks

**Run CI Locally**
- Runs complete CI pipeline locally
- Command: `./bin/ci`
- Group: build
- **Focus**: Brings terminal to front
- Includes: tests, linting, security scans

**Run Quality Checks**
- Comprehensive quality analysis
- Command: `./bin/ci quality`
- Group: build
- **Focus**: Brings terminal to front
- Includes problem matcher for RuboCop

### 🧹 Cleanup Tasks

**Clean Coverage Reports**
- Removes `coverage/` directory
- Command: `rm -rf coverage/`
- Group: build
- **Silent**: Minimal terminal output

**Clean Temporary Files**
- Removes `tmp/` directory
- Command: `rm -rf tmp/`
- Group: build
- **Silent**: Minimal terminal output

## Task Usage Patterns

### First-Time Setup
1. **Setup Development Environment** (runs Bundle Install + Generate .env)
2. **Run Tests** (verify everything works)

### Daily Development
1. **Run Guard** (continuous testing while coding)
2. **Run RuboCop Auto-fix** (before committing)
3. **Run Tests with Coverage** (check coverage)

### Environment Updates
1. **Generate .env (Preview)** (check what would change)
2. **Generate .env from 1Password** (apply changes)

### Before Committing
1. **Run Quality Checks** (comprehensive analysis)
2. **Validate Shell Scripts** (if you modified shell scripts)
3. **Run CI Locally** (full CI pipeline)

### Debugging
1. **Run Specific Test File** (focused testing)
2. **Run Kanban Metrics (JSON output)** (structured output)

## Problem Matchers

VS Code integrates with several tools through problem matchers:

- **RuboCop**: Shows linting issues in Problems panel
- **Shellcheck**: Shows shell script issues in Problems panel

## Keyboard Shortcuts

You can assign keyboard shortcuts to frequently used tasks:

1. Open Command Palette (`Cmd+Shift+P`)
2. Search "Preferences: Open Keyboard Shortcuts"
3. Search for task name (e.g., "Tasks: Run Test Task")
4. Assign shortcut

## Task Groups

Tasks are organized into groups for better discoverability:

- **build**: General build and setup tasks
- **test**: Testing-related tasks (default test task gets `Cmd+Shift+T`)

## Customization

To modify tasks:

1. Edit `.vscode/tasks.json`
2. Use VS Code IntelliSense for task schema
3. Test with "Tasks: Run Task" command

## Dependencies

Some tasks depend on others:
- **Setup Development Environment** runs Bundle Install first, then Generate .env

## Background Tasks

**Run Guard** is configured as a background task that:
- Runs continuously
- Uses a dedicated terminal panel  
- Doesn't block other tasks

## Security Notes

- **.env generation**: Always creates backups before overwriting
- **Preview mode**: Available for safe testing
- **1Password integration**: Requires authenticated 1Password CLI
- **File permissions**: Maintained during operations

## Troubleshooting

**Task not found**:
- Reload VS Code window
- Check `.vscode/tasks.json` for syntax errors

**Command not found**:
- Ensure dependencies are installed (bundle install, op CLI)
- Check PATH environment variable

**Permission errors**:
- Ensure scripts are executable: `chmod +x scripts/*.sh bin/*`

**1Password errors**:
- Sign in: `op signin`
- Check vault access and item names