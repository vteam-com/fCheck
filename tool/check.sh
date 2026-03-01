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
flutter analyze lib test --no-pub | sed 's/^/    /'

echo --- Test
if ! flutter test --reporter=compact --no-pub; then
  echo "Tests failed"
  exit 1
fi

echo --- fCheck
dart run ./bin/fcheck.dart --svg --mermaid --plantuml ./example > /dev/null 2>&1
dart run ./bin/fcheck.dart --list full --svg --fix --exclude "**/example"
