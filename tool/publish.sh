#!/bin/bash

# fcheck package publishing script
# This script publishes the fcheck package to pub.dev

set -e  # Exit on any error

echo "🚀 Preparing to publish fcheck to pub.dev"
echo

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if we're in the right directory
if [ ! -f "pubspec.yaml" ]; then
    print_error "pubspec.yaml not found. Please run this script from the package root directory."
    exit 1
fi

# Check if publish_to is set correctly
if grep -q "publish_to: none" pubspec.yaml; then
    print_warning "publish_to is set to 'none' in pubspec.yaml"
    echo "Please update pubspec.yaml to set publish_to to pub.dev or remove the line entirely."
    echo "Current pubspec.yaml publish_to setting:"
    grep "publish_to" pubspec.yaml
    echo
    read -p "Do you want to continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "Publication cancelled."
        exit 1
    fi
fi

print_status "Checking package version..."
VERSION=$(grep "^version:" pubspec.yaml | sed 's/version: //')
print_status "Package version: $VERSION"

print_status "Running tests..."
if ! flutter test; then
    print_error "Tests failed. Please fix the issues before publishing."
    exit 1
fi
print_success "All tests passed!"

print_status "Running dart pub get..."
dart pub get

print_status "Running dry-run publish to check for issues..."
if ! dart pub publish --dry-run; then
    print_error "Dry-run publish failed. Please fix the issues before publishing."
    exit 1
fi
print_success "Dry-run publish completed successfully!"

echo
print_warning "Ready to publish fcheck v$VERSION to pub.dev"
echo
echo "This will make the package publicly available to all Dart/Flutter developers."
echo "Please ensure that:"
echo "  - All code is properly documented"
echo "  - README.md is up to date"
echo "  - Version number is correct"
echo "  - You have publish permissions for this package"
echo
read -p "Do you want to proceed with publishing? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_status "Publication cancelled."
    exit 1
fi

print_status "Publishing fcheck v$VERSION to pub.dev..."
if dart pub publish; then
    print_success "Package published successfully!"
    echo
    print_status "Package should be available at: https://pub.dev/packages/fcheck"
    print_status "It may take a few minutes for the package to appear on pub.dev"
else
    print_error "Failed to publish package."
    exit 1
fi
