#!/bin/bash

# Check if Ruby is installed
if ! command -v ruby &> /dev/null; then
    echo "Ruby is not installed. Please install Ruby first."
    exit 1
fi

# Check if .ruby-version exists
if [ ! -f ".ruby-version" ]; then
    echo "Error: .ruby-version file not found"
    exit 1
fi

# Get required Ruby version from .ruby-version
REQUIRED_RUBY=$(cat .ruby-version)

# Get current Ruby version
CURRENT_RUBY=$(ruby -v | cut -d' ' -f2)

# Compare versions
if [ "$CURRENT_RUBY" != "$REQUIRED_RUBY" ]; then
    echo "Error: Ruby version mismatch"
    echo "Required version: $REQUIRED_RUBY"
    echo "Current version: $CURRENT_RUBY"
    echo "Please install the correct Ruby version using rbenv, rvm, or asdf"
    exit 1
fi


# Check if Bundler is installed
if ! command -v bundle &> /dev/null; then
    echo "Installing Bundler..."
    gem install bundler
fi

# Install dependencies if Gemfile.lock doesn't exist
if [ ! -f "Gemfile.lock" ]; then
    echo "Installing dependencies..."
    bundle install
fi

# Clean previous build
echo "Cleaning previous build..."
bundle exec jekyll clean

# Start Jekyll server
echo "Starting Jekyll server..."
bundle exec jekyll serve --livereload 