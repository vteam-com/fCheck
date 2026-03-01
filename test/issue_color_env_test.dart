import 'dart:io';

import 'package:fcheck/src/input_output/issue_location_utils.dart';
import 'package:test/test.dart';

void main() {
  group('No-color environment detection', () {
    test('NO_COLOR presence disables colors', () {
      expect(isNoColorEnvironmentEnabled({'NO_COLOR': ''}), isTrue);
    });

    test('NO_COLORS truthy value disables colors', () {
      expect(isNoColorEnvironmentEnabled({'NO_COLORS': '1'}), isTrue);
    });

    test('no-colors truthy value disables colors', () {
      expect(isNoColorEnvironmentEnabled({'no-colors': 'true'}), isTrue);
    });

    test('NO_COLORS falsey value does not disable colors', () {
      expect(isNoColorEnvironmentEnabled({'NO_COLORS': '0'}), isFalse);
    });
  });

  group('CLI color configuration', () {
    tearDown(() {
      configureCliColorOutput(disableColors: false);
    });

    test('configureCliColorOutput disables ANSI colors when requested', () {
      configureCliColorOutput(disableColors: true);

      expect(supportsCliAnsiColors, isFalse);
    });

    test(
      'configureCliColorOutput false follows environment/terminal support',
      () {
        configureCliColorOutput(disableColors: false);

        final expected =
            !isNoColorEnvironmentEnabled(Platform.environment) &&
            stdout.hasTerminal &&
            stdout.supportsAnsiEscapes;
        expect(supportsCliAnsiColors, equals(expected));
      },
    );
  });
}
