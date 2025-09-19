#!/bin/bash
set -e

echo "🚀 Setting up development environment..."

# Update package lists and install build essentials
echo "📦 Installing build dependencies..."
sudo apt-get update -qq
sudo apt-get install -y build-essential libffi-dev

# Install gems
echo "💎 Installing gems..."
bundle install

echo "✅ Development environment setup complete!"