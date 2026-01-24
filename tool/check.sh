#!/bin/sh

echo --- Pub Get
flutter pub get > /dev/null || { echo "Pub get failed"; exit 1; }

echo --- Pub Upgrade
flutter pub upgrade > /dev/null

echo --- Pub Outdated
flutter pub outdated

echo --- Format sources
dart format . | sed 's/^/    /'
dart fix --apply | sed 's/^/    /'

echo --- Analyze
flutter analyze lib test --no-pub | sed 's/^/    /'

echo --- Test
echo "    Running tests..."
flutter test --reporter=compact --no-pub

echo --- fCheck
dart run fcheck.dart --svg .
