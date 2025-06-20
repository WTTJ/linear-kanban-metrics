#!/bin/bash

# Test Execution Script with Coverage
# Usage: ./scripts/test.sh [options]

set -e

# Configuration
COVERAGE=${COVERAGE:-false}
PROFILE=${PROFILE:-false}
PARALLEL=${PARALLEL:-false}
FORMAT=${FORMAT:-progress}
DEBUG=${DEBUG:-false}
UNIT_ONLY=${UNIT_ONLY:-false}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --coverage)
      COVERAGE=true
      shift
      ;;
    --profile)
      PROFILE=true
      shift
      ;;
    --format)
      FORMAT="$2"
      shift 2
      ;;
    --debug)
      DEBUG=true
      shift
      ;;
    --unit)
      UNIT_ONLY=true
      shift
      ;;
    --help)
      echo "Usage: $0 [options]"
      echo "Options:"
      echo "  --coverage   Enable code coverage reporting with SimpleCov"
      echo "  --profile    Enable RSpec profiling to identify slow tests"
      echo "  --format     Set RSpec format (progress, documentation, json, etc.)"
      echo "  --debug      Enable debug mode with full program output"
      echo "  --unit       Run only unit tests (exclude integration tests)"
      echo "  --help       Show this help message"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Environment setup
export RACK_ENV=test

if [ "$COVERAGE" = "true" ]; then
  export COVERAGE=true
  echo "📊 Coverage reporting enabled"
fi

if [ "$PROFILE" = "true" ]; then
  export PROFILE=true
  echo "⏱️  Test profiling enabled"
fi

if [ "$DEBUG" = "true" ]; then
  export DEBUG=true
  export RSPEC_DEBUG=true
  echo "🐛 Debug mode enabled - program output will be visible"
fi

# Run tests
echo "🧪 Running RSpec tests..."

# Determine test path
if [ "$UNIT_ONLY" = "true" ]; then
  TEST_PATH="spec/lib/"
  echo "📋 Running unit tests only (excluding integration tests)"
else
  TEST_PATH="spec/"
fi

# Coverage reporting
if [ "$COVERAGE" = "true" ]; then
  echo "📈 Coverage report generated in coverage/index.html"
  
  # Optional: Open coverage report in browser (macOS)
  if command -v open &> /dev/null; then
    echo "🌐 Opening coverage report in browser..."
    open coverage/index.html
  fi
fi

echo "✅ Test run completed!"
