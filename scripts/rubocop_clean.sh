#!/usr/bin/env bash
# Script to run RuboCop without the noisy warnings from unused cop configurations

echo "Running RuboCop (hiding extension warnings)..."
bundle exec rubocop "$@" 2>&1 | grep -v "Warning: Using \`RSpec/.*\` configuration"
