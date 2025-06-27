# AI Code Review Standards Configuration
# This file defines the coding standards and design patterns that should be enforced during AI code reviews

## Project Architecture Standards

### Module Organization
- All code must be organized under the `KanbanMetrics` namespace
- Use Zeitwerk autoloading - never use `require_relative`
- Follow the established module hierarchy:
  - `KanbanMetrics::Linear::*` - API client layer
  - `KanbanMetrics::Calculators::*` - Business logic and metrics
  - `KanbanMetrics::Timeseries::*` - Time series analysis
  - `KanbanMetrics::Formatters::*` - Output formatting strategies
  - `KanbanMetrics::Reports::*` - High-level report generation

### Design Patterns (Required)
1. **Value Objects**: Use for configuration and data transfer (e.g., `QueryOptions`)
2. **Strategy Pattern**: For different output formats and calculation methods
3. **Adapter Pattern**: For external API communication
4. **Builder Pattern**: For complex object construction (queries, timelines)
5. **Repository Pattern**: For data access abstraction

### SOLID Principles (Mandatory)
- **Single Responsibility**: Each class should have one reason to change
- **Open/Closed**: Open for extension, closed for modification
- **Liskov Substitution**: Subtypes must be substitutable for base types
- **Interface Segregation**: Depend on abstractions, not concretions
- **Dependency Inversion**: High-level modules shouldn't depend on low-level modules

## Ruby Code Standards

### Language Features
- Use Ruby 3.0+ features where appropriate
- Prefer keyword arguments for methods with multiple parameters
- Use safe navigation operator (`&.`) for nil checks
- Leverage pattern matching for complex conditionals
- Use `frozen_string_literal: true` in all files

### Naming Conventions
- Classes: `PascalCase`
- Methods/Variables: `snake_case`
- Constants: `SCREAMING_SNAKE_CASE`
- Files: `snake_case.rb` matching class names
- Modules: Follow Zeitwerk conventions exactly

### Code Structure
- Maximum method length: 25 lines
- Maximum class length: 160 lines
- Maximum line length: 140 characters
- No more than 3 levels of nesting
- Use early returns to reduce nesting

### Error Handling
- Define custom exception classes under `KanbanMetrics` module
- Always handle external API errors gracefully
- Provide meaningful error messages with context
- Use `rescue` with specific exception types, not bare `rescue`

## Testing Standards

### Test Structure (Four-Phase Pattern)
```ruby
it 'describes the behavior being tested' do
  # Arrange - Set up test data and environment
  test_data = build_test_data
  subject = described_class.new(test_data)
  
  # Act - Execute the behavior being tested
  result = subject.perform_action
  
  # Assert - Verify the expected outcome
  expect(result).to meet_expectations
  
  # Cleanup - Handled automatically by let blocks
end
```

### Test Organization
- Use named subjects: `subject(:calculator) { described_class.new(data) }`
- One assertion per test (use `aggregate_failures` for related checks)
- Descriptive test names that explain the behavior
- Group related tests with `describe` and `context`
- Use FactoryBot for test data creation

### Test Data Patterns
- Use `let` blocks for test data setup
- Create realistic test scenarios with FactoryBot
- Use VCR for HTTP interactions
- Mock external dependencies appropriately

## Anti-Patterns (Forbidden)

### Code Smells to Reject
- **God Objects**: Classes doing too many things
- **Long Parameter Lists**: Use value objects or keyword arguments
- **Primitive Obsession**: Use domain objects instead of basic types
- **Feature Envy**: Methods using more of another class than their own
- **Shotgun Surgery**: Changes requiring modifications in many places

### Architecture Violations
- Manual `require_relative` statements (use Zeitwerk)
- Direct coupling between distant layers
- Business logic in formatters or HTTP clients
- Hardcoded values that should be configurable
- Missing error handling for external dependencies

### Testing Anti-Patterns
- Tests that test multiple behaviors
- Tests that depend on external services (use VCR/mocks)
- Overly complex test setups
- Testing implementation details instead of behavior
- Missing edge case testing

## Performance Considerations

### Efficiency Requirements
- Use streaming for large datasets
- Implement proper pagination for API calls
- Cache expensive calculations when appropriate
- Avoid N+1 queries in any iteration patterns
- Use lazy evaluation where beneficial

### Memory Management
- Don't load entire datasets into memory at once
- Use enumerators for large collections
- Clean up temporary files and resources
- Avoid circular references in object graphs

## Security Standards

### API Security
- Never log sensitive data (API tokens, user data)
- Validate all external inputs
- Use HTTPS for all external communications
- Implement proper timeout handling
- Sanitize data before logging

### Code Security
- Avoid `eval` and other dynamic code execution
- Validate file paths and user inputs
- Use secure random generation for any tokens
- Don't store secrets in code or version control

## Documentation Standards

### Self-Documenting Code
- Use descriptive method and variable names
- Write code that explains its intent
- Avoid commenting obvious code
- Comment complex business logic and algorithms
- Document public API interfaces

### README and Documentation
- Keep documentation up-to-date with code changes
- Provide clear usage examples
- Document all CLI options and parameters
- Include troubleshooting guides for common issues

## Git and PR Standards

### Commit Messages
- Use conventional commit format: `type(scope): description`
- Types: `feat`, `fix`, `refactor`, `test`, `docs`, `style`
- Keep subject lines under 50 characters
- Provide detailed body for complex changes

### Pull Request Requirements
- Single responsibility per PR
- Include tests for new functionality
- Update documentation for user-facing changes
- Ensure all CI checks pass
- Provide clear description of changes

This configuration serves as the authoritative guide for all AI code reviews. Any deviation from these standards should be flagged and explained in the review.
