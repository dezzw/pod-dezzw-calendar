#!/bin/bash

# Local Lint Script for Calendar Pod

echo "🔍 Running SwiftLint for Calendar Pod..."
echo "=================================================="

# Check if SwiftLint is installed
if ! command -v swiftlint >/dev/null 2>&1; then
    echo "❌ SwiftLint is not installed."
    echo "To install SwiftLint, run: brew install swiftlint"
    exit 1
fi

# Change to project directory
cd "$(dirname "$0")"

echo "📍 Working directory: $(pwd)"

# Check if .swiftlint.yml exists
if [[ ! -f ".swiftlint.yml" ]]; then
    echo "⚠️  No .swiftlint.yml configuration found. Using default rules."
fi

# Run SwiftLint with configuration
echo "🔍 Running SwiftLint..."
swiftlint --config .swiftlint.yml

LINT_EXIT_CODE=$?

# Offer to run autocorrect if there are fixable issues
if [[ $LINT_EXIT_CODE -ne 0 ]]; then
    echo ""
    echo "⚠️  SwiftLint found issues. Would you like to run autocorrect? (y/n)"
    read -r response
    
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        echo "🔧 Running SwiftLint autocorrect..."
        swiftlint --autocorrect --config .swiftlint.yml
        
        # Check if any files were modified
        if ! git diff --exit-code --quiet; then
            echo ""
            echo "✅ SwiftLint made the following changes:"
            git diff --name-only
            echo ""
            echo "You may want to review and commit these changes."
        else
            echo "✅ No autocorrect changes were made"
        fi
        
        # Run lint again to show remaining issues
        echo ""
        echo "🔍 Running SwiftLint again to check remaining issues..."
        swiftlint --config .swiftlint.yml
        LINT_EXIT_CODE=$?
    fi
fi

echo ""
echo "📊 Lint Summary:"
echo "=================================================="

if [[ $LINT_EXIT_CODE -eq 0 ]]; then
    echo "✅ SwiftLint passed with no issues!"
else
    echo "⚠️  SwiftLint found issues that need attention"
fi

echo ""
echo "💡 Tips:"
echo "   • Use 'swiftlint --autocorrect' to fix style issues automatically"
echo "   • Check .swiftlint.yml to customize rules"
echo "   • Some rules are disabled for specific contexts (like test files)"
echo "   • Focus on fixing 'error' level issues first"

exit $LINT_EXIT_CODE
