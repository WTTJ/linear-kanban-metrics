# Testing Best Practices Guide

This document outlines the testing conventions and patterns used in this project.

## 1. Four-Phase Test Pattern

Every test should follow the **Arrange, Act, Assert, Cleanup** pattern:

```ruby
it 'calculates the correct result' do
  # Setup (Arrange) - Prepare test data and environment
  input_data = create_test_data
  calculator = Calculator.new(input_data)
  
  # Execute (Act) - Perform the action being tested
  result = calculator.calculate
  
  # Verify (Assert) - Check the outcome
  expect(result).to eq(expected_value)
  
  # Cleanup (implicit with let blocks)
end
```

## 2. Named Subjects

Use named subjects to improve readability and reduce duplication:

```ruby
# Good - Named subject
subject(:calculator) { described_class.new(issues) }
subject(:result) { calculator.calculate }

# Avoid - Anonymous subject
subject { described_class.new(issues).calculate }
```

## 3. Single Responsibility Testing

Each test should verify one specific behavior:

```ruby
# Good - Tests one thing
it 'returns a hash' do
  expect(result).to be_a(Hash)
end

it 'includes all required keys' do
  expect(result.keys).to contain_exactly(:total, :average, :median)
end

# Avoid - Tests multiple things
it 'returns correct structure and values' do
  expect(result).to be_a(Hash)
  expect(result.keys).to contain_exactly(:total, :average, :median)
  expect(result[:total]).to eq(10)
end
```

## 4. Aggregate Failures

Use `aggregate_failures` for related assertions that should all be verified:

```ruby
it 'returns complete user data', :aggregate_failures do
  expect(user.name).to eq('John Doe')
  expect(user.email).to eq('john@example.com')
  expect(user.active?).to be true
end
```

## 5. VCR for HTTP Interactions

Use VCR cassettes for external API calls:

```ruby
describe 'API integration', :vcr do
  it 'fetches data from external service', vcr: { cassette_name: 'external_api/success' } do
    # Test will record/replay HTTP interactions
    result = client.fetch_data
    expect(result).to be_present
  end
end
```

## 6. Test Data Organization

Structure test data clearly at the top of specs:

```ruby
RSpec.describe MyClass do
  # === TEST DATA SETUP ===
  let(:valid_input) { { name: 'Test', value: 100 } }
  let(:invalid_input) { { name: '', value: -1 } }
  let(:empty_input) { {} }
  
  # === NAMED SUBJECTS ===
  subject(:processor) { described_class.new(input_data) }
  subject(:result) { processor.process }
  
  # Tests follow...
end
```

## 7. Context Organization

Organize contexts by setup conditions:

```ruby
describe '#process' do
  context 'with valid input' do
    let(:input_data) { valid_input }
    
    it 'processes successfully' do
      expect(result).to be_successful
    end
  end
  
  context 'with invalid input' do
    let(:input_data) { invalid_input }
    
    it 'returns error' do
      expect(result).to be_error
    end
  end
end
```

## 8. Coverage Configuration

Enable coverage reporting with environment variable:

```bash
# Run tests with coverage
COVERAGE=true bundle exec rspec

# Run tests without coverage (default)
bundle exec rspec
```

## 9. Shared Examples and Contexts

Use shared examples for common behavior:

```ruby
RSpec.shared_examples 'a calculator' do
  it 'responds to calculate method' do
    expect(subject).to respond_to(:calculate)
  end
  
  it 'returns numeric result' do
    expect(subject.calculate).to be_a(Numeric)
  end
end

# Usage
RSpec.describe SomeCalculator do
  it_behaves_like 'a calculator'
end
```

## 10. Factory Usage

Use factories for complex test data:

```ruby
# In spec/factories/
FactoryBot.define do
  factory :issue do
    sequence(:id) { |n| "issue-#{n}" }
    title { Faker::Lorem.sentence }
    state { { type: 'completed' } }
    completed_at { 1.day.ago }
  end
end

# In specs
let(:issues) { create_list(:issue, 5) }
```

## 11. Performance Testing

Include performance considerations:

```ruby
it 'performs efficiently with large datasets' do
  large_dataset = create_list(:issue, 10_000)
  
  expect {
    calculator = Calculator.new(large_dataset)
    calculator.calculate
  }.to perform_under(1.second)
end
```

## 12. Error Handling Tests

Test edge cases and error conditions:

```ruby
context 'with malformed data' do
  let(:input_data) { { invalid: 'structure' } }
  
  it 'handles errors gracefully' do
    expect { processor.process }.not_to raise_error
  end
  
  it 'returns appropriate error response' do
    expect(result.error?).to be true
    expect(result.message).to include('Invalid data format')
  end
end
```

## Running Tests

```bash
# All tests
bundle exec rspec

# With coverage
COVERAGE=true bundle exec rspec

# Specific file
bundle exec rspec spec/lib/calculators/flow_efficiency_calculator_spec.rb

# With profiling
PROFILE=true bundle exec rspec

# Watch mode with Guard (auto-run tests on file changes)
bundle exec guard
```
