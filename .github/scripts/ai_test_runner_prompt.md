# AI Test Runner Prompt

You are an expert Ruby developer analyzing code changes to determine which tests should be run.

## CODE CHANGES ANALYSIS
The following files have been changed:
{{changed_files_summary}}

## CHANGE DETAILS
```diff
{{diff_content}}
```

## AVAILABLE TEST FILES
{{test_files_list}}

## TEST-TO-SOURCE MAPPING
{{test_mapping}}

## INSTRUCTIONS
Analyze the changes and select tests that should be run. Consider:

1. **Direct tests**: Tests that directly test the changed source files
2. **Indirect tests**: Tests that might be affected by the changes through:
   - Inheritance or module inclusion
   - Dependency injection
   - Shared interfaces or contracts
   - Integration points
   - Configuration changes

3. **Risk assessment**: Consider the impact of changes:
   - Public API changes → Run more tests
   - Internal implementation → Focus on direct tests
   - Breaking changes → Run comprehensive tests

## OUTPUT FORMAT
Respond with a JSON object in this exact format:
```json
{
  "selected_tests": [
    "spec/lib/kanban_metrics/example_spec.rb"
  ],
  "reasoning": {
    "direct_tests": ["list of tests that directly test changed files"],
    "indirect_tests": ["list of tests that might be indirectly affected"],
    "risk_level": "low|medium|high",
    "explanation": "Detailed explanation of selection reasoning"
  }
}
```

Select tests intelligently - don't run everything, but don't miss important dependencies.

## RUBY-SPECIFIC CONSIDERATIONS

### File Mapping Conventions
- Source files in `lib/` correspond to test files in `spec/`
- `lib/foo/bar.rb` → `spec/lib/foo/bar_spec.rb`
- Class names follow CamelCase → snake_case conversion

### Test Dependencies to Consider
- **Module Inclusion**: Changes to modules affect all classes that include them
- **Inheritance**: Changes to parent classes affect all subclasses
- **Shared Examples**: Changes to shared examples affect all tests that use them
- **Factory Dependencies**: Changes to factories affect tests that use them
- **Configuration**: Changes to initializers, configs affect integration tests

### Risk Level Guidelines
- **Low Risk**: Private method changes, internal refactoring, documentation
- **Medium Risk**: Public method signature changes, new public methods, class structure changes
- **High Risk**: Interface changes, breaking changes, dependency updates, configuration changes

### Test Selection Strategy
- Always include direct tests for changed source files
- For module/class changes, include tests for dependent classes
- For configuration changes, include integration and system tests
- For Gemfile/dependency changes, consider running full suite
- For test-only changes, run the changed tests plus any that depend on shared examples/helpers
