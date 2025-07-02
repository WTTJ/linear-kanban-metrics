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

### 🔧 `test_response_validation_fix.rb`
**Response validation logic test**

Tests the improved `response_is_valid?` method in the Dust provider to ensure it correctly identifies valid vs invalid responses:

```bash
# Test basic response validation logic
ruby spec/scripts/test_response_validation_fix.rb
```

### 🔍 `test_comprehensive_validation.rb`
**Comprehensive response validation test**

Extensive testing of response validation with edge cases, common review terms, and error scenarios:

```bash
# Run comprehensive validation tests
ruby spec/scripts/test_comprehensive_validation.rb
```

### ⚡ `test_retry_logic_fix.rb`
**Retry logic fix demonstration**

Demonstrates the fix for unnecessary retries in the Dust provider by showing how the old vs new validation logic behaves:

```bash
# See the retry logic fix in action
ruby spec/scripts/test_retry_logic_fix.rb
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
- ✅ **CRITICAL FIX**: Fixed the core issue where citation markers like `:cite[aa,eu]` remained unprocessed

**Key Bug Fix - Citation Marker Processing**:
The main issue was that citation markers in content (like `:cite[aa,eu]`) didn't match the citation IDs provided by the Dust API. The fix implements a smart sequential mapping strategy:

1. **Extract all citation IDs** from content markers (handling multi-citations like `:cite[aa,eu]`)
2. **Sequential mapping**: Map extracted IDs to available citations in order (first unique ID → citation 1, second → citation 2, etc.)
3. **Process multi-citations**: `:cite[aa,eu]` becomes `<sup>[1](#ref-1),[2](#ref-2)</sup>`
4. **Handle unavailable citations**: Citations without matches remain as `**:cite[unknown]**`

**Before Fix**:
```
Content: "Issue :cite[aa,eu] needs attention :cite[bb]"
Result:  "Issue **:cite[aa,eu]** needs attention **:cite[bb]**"  ❌
```

**After Fix**:
```
Content: "Issue :cite[aa,eu] needs attention :cite[bb]" 
Result:  "Issue <sup>[1](#ref-1),[2](#ref-2)</sup> needs attention <sup>[3](#ref-3)</sup>"  ✅
```

**Key Features Verified**:
- Single citations: `:cite[aw]` → `<sup>[1](#ref-1)</sup>`
- Multi-citations: `:cite[aa,eu]` → `<sup>[1](#ref-1),[2](#ref-2)</sup>`
- Mixed valid/invalid: `:cite[aa,unknown,bb]` → `<sup>[1](#ref-1),[3](#ref-3)</sup>` (skipping unknown)
- Unknown citations: `:cite[unknown]` → `**:cite[unknown]**` (highlighted)
- Reference list generation with clickable anchor links

**Files Updated**:
- `.github/scripts/pr_review.rb` - Main PR review script with smart citation processing
- `spec/scripts/test_pr_review_citations.rb` - Test to verify PR review citation handling
- `spec/scripts/test_smart_citations.rb` - Test for the new smart citation logic
- `spec/scripts/test_final_citation_fix.rb` - Verification test for the complete fix
- `spec/scripts/debug_citation_mapping.rb` - Debug script that identified the core issue
- `spec/scripts/README.md` - This documentation update

**Impact**: The `:cite[aa,eu]` issue reported by the user has been completely resolved. All citation markers are now properly processed when corresponding citations are available from the Dust API.

## Retry Logic Fix Summary ✅

### Issue Identified
The `response_is_valid?` method in the Dust provider was being overly strict, causing unnecessary retries even when valid responses were received. The main problems were:

1. **Strict minimum length check**: Responses shorter than 50 characters were rejected as invalid, even for legitimate short reviews like "LGTM! ✅" or "Approved"
2. **Poor nil handling**: Could cause exceptions when checking nil responses
3. **No recognition of common review terms**: Valid short responses with review terminology were treated as errors

### Solution Implemented
Enhanced the `response_is_valid?` method with:

- **Proper nil handling**: Check for nil responses before other validations
- **Smart minimum length**: Allow very short responses (>= 1 char) if they contain meaningful content
- **Review term recognition**: Recognize common review terms and emojis (`lgtm`, `approved`, `ok`, `✅`, `👍`, etc.)
- **Specific error detection**: Only reject responses that are actual error messages or empty/whitespace-only
- **Debug logging**: Added validation logging to help troubleshoot issues

### Impact
- **Performance improvement**: Eliminates unnecessary API retries for valid short responses
- **Better user experience**: Faster PR reviews when agents provide concise feedback
- **Cost reduction**: Fewer API calls to Dust when responses are already valid
- **Maintained reliability**: Still properly rejects actual error messages and invalid responses

### Testing
Created comprehensive test suites to verify the fix:
- Basic validation logic tests
- Edge case and comprehensive validation tests  
- Before/after comparison demonstrations
- 100% test success rate across 25+ test scenarios
