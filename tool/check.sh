#!/bin/sh

echo --- Pub Clean
flutter clean > /dev/null || { echo "flutter Clean failed"; exit 1; }

echo --- Pub Get
flutter pub get > /dev/null || { echo "Pub get failed"; exit 1; }

echo --- Pub Upgrade
flutter pub upgrade > /dev/null

echo --- Pub Outdated
flutter pub outdated > /dev/null

echo --- Extract version
./tool/generate_version.sh > /dev/null

echo --- Format sources
dart format . | sed 's/^/    /'
dart fix --apply | sed 's/^/    /'

echo --- Analyze
dart analyze lib test | sed 's/^/    /'

echo --- Test

if ! NO_COLOR=1 dart test --reporter=compact; then
  echo "Tests failed"
  exit 1
fi
NO_COLOR=0

echo --- fCheck
# on the ./example
dart run ./bin/fcheck.dart --svg --mermaid --plantuml ./example > /dev/null 2>&1

# on the main app
dart run ./bin/fcheck.dart --list full --svg --fix --exclude "**/example"
