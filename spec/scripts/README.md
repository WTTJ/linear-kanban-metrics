# Test Scripts for Dust API Integration

This folder contains test scripts for validating and troubleshooting the Dust API integration used in the PR review GitHub Actions workflow.

## Scripts Overview

### 🧪 `test_dust_api.rb`
**Main test script for Dust API functionality**

Simple, standalone test that validates:
- API connectivity
- Agent response generation
- Environment variable loading
- Basic conversation flow

```bash
# Run basic test
ruby spec/scripts/test_dust_api.rb

# Run with debug output
DEBUG=true ruby spec/scripts/test_dust_api.rb
```

### 🔍 `check_dust_agents.rb`
**Agent discovery and validation**

Lists all available agents in the Dust workspace and their status:
- Shows agent IDs and names
- Indicates active/inactive status
- Helps verify correct agent configuration

```bash
ruby spec/scripts/check_dust_agents.rb
```

### 📝 `test_long_prompt.rb`
**PR review scenario simulation**

Tests agent response with longer prompts similar to actual PR reviews:
- Simulates GitHub Actions environment
- Tests with coding standards content
- Validates timeout behavior

```bash
ruby spec/scripts/test_long_prompt.rb
```

### 🔧 `troubleshoot_dust_github_actions.rb`
**Comprehensive troubleshooting tool**

Multi-scenario test that:
- Tests different prompt lengths
- Simulates various timeout conditions
- Provides solutions for common issues
- Offers debugging guidance

```bash
ruby spec/scripts/troubleshoot_dust_github_actions.rb
```

### 📚 `test_citation_processing.rb`
**Citation extraction and formatting test**

Validates citation processing with sample Dust API response data:
- Tests single citation markers: `:cite[id]` → `[1]`
- Tests multiple citations: `:cite[id1,id2]` → `[1,2]`
- Tests unknown citations: `:cite[unknown]` → `**:cite[unknown]**`
- Verifies citation formatting with links and titles

```bash
# Test citation processing
ruby spec/scripts/test_citation_processing.rb
```

## Prerequisites

### Environment Configuration
All scripts require `config/.env.test` with:

```env
DUST_API_KEY=sk-your-api-key-here
DUST_WORKSPACE_ID=your-workspace-id
DUST_AGENT_ID=claude-4-sonnet
```

### Dependencies
- Ruby 3.x
- Bundler with project gems installed
- Network access to dust.tt API

## Usage Patterns

### Quick Health Check
```bash
# Verify basic connectivity
ruby spec/scripts/test_dust_api.rb
```

### GitHub Actions Debugging
```bash
# If GitHub Actions fails, run:
ruby spec/scripts/troubleshoot_dust_github_actions.rb

# Check agent availability:
ruby spec/scripts/check_dust_agents.rb
```

### Development Testing
```bash
# Test changes to PR review logic:
ruby spec/scripts/test_long_prompt.rb
```

## Common Issues & Solutions

### Agent Not Responding
1. **Verify agent status**: Run `check_dust_agents.rb`
2. **Check credentials**: Ensure API key and workspace ID are correct
3. **Test connectivity**: Run basic `test_dust_api.rb`

### GitHub Actions Timeouts
1. **Environment differences**: GitHub Actions may need longer timeouts
2. **Network latency**: CI environments have higher latency
3. **Agent capacity**: Agent might be busy with other requests

### Configuration Problems
1. **Missing environment variables**: Check `config/.env.test` exists
2. **Invalid agent ID**: Verify with `check_dust_agents.rb`
3. **API permissions**: Ensure API key has correct workspace access

## Integration with Main Code

These test scripts mirror the logic in:
- `.github/scripts/pr_review.rb` - Main PR review script
- `spec/github/scripts/pr_review_spec.rb` - RSpec test suite

They use the same:
- API endpoints
- Authentication methods
- Response parsing logic
- Error handling patterns

## Output Examples

### Successful Test
```
🧪 Dust API Test Script
==================================================
📄 Loading environment variables from config/.env.test...
✅ Configuration loaded:
   Workspace ID: 931d8504bc
   Agent ID: claude-4-sonnet
   API Key: sk-220804...

[INFO] 🔌 Testing Dust API connection...
[INFO] ✅ Conversation created: abc123
[INFO] ✅ Response received!

🤖 DUST AI RESPONSE:
============================================================
# Code Review
... (agent response) ...
============================================================

🎉 SUCCESS! Dust API is working correctly.
```

### Failed Test
```
❌ Agent did not respond after 3 attempts
💥 Test failed. Please check the error messages above.
```

## Maintenance

- **Update paths**: If moving scripts, update relative paths to `config/.env.test`
- **Update agent IDs**: If changing agents, update test configurations
- **Monitor API changes**: Update scripts if Dust API endpoints change
- **Version compatibility**: Ensure Ruby and gem versions match main project

## Recent Updates ✅

### Citation Processing Completion (January 2025)

**Task**: Refactor, test, and ensure robust citation extraction and formatting in Dust/Anthropic PR review/test scripts.

**Completed**:
- ✅ **Main PR Review Script Updated**: `.github/scripts/pr_review.rb` now uses the same robust citation logic as our validated test scripts
- ✅ **Citation Logic Unified**: Simplified and unified the citation mapping logic for consistency across all scripts
- ✅ **Multi-Citation Support**: All scripts (including PR review) properly handle multi-citation markers like `:cite[aw,gx]`
- ✅ **Unknown Citation Handling**: Unknown citations are highlighted as `**:cite[unknown]**` instead of being ignored
- ✅ **Comprehensive Testing**: Created `test_pr_review_citations.rb` to verify the main PR review script handles citations correctly
- ✅ **RuboCop Compliance**: All scripts (including PR review) are RuboCop compliant
- ✅ **Documentation**: Updated with complete task status and usage instructions

**Key Features Verified**:
- Single citations: `:cite[aw]` → `[1]`
- Multi-citations: `:cite[gx,bt]` → `[2,3]`
- Mixed valid/invalid: `:cite[aw,unknown,bt]` → `[1,3]` (skipping unknown)
- Unknown citations: `:cite[unknown]` → `**:cite[unknown]**` (highlighted)
- Reference list generation with proper formatting

**Files Updated**:
- `.github/scripts/pr_review.rb` - Main PR review script with unified citation logic
- `spec/scripts/test_pr_review_citations.rb` - New test to verify PR review citation handling
- `spec/scripts/README.md` - This documentation update

The citation processing system is now complete, robust, and consistent across all scripts. All requirements have been met.
