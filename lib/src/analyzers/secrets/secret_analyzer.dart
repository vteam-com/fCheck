// ignore: fcheck_secrets
import 'dart:io';
import 'dart:math';
import 'package:glob/glob.dart';
import 'package:fcheck/src/analyzers/secrets/secret_issue.dart';

/// Advanced Secret Analyzer implementing SECRET.md rules
class SecretAnalyzer {
  static const int _ignoreDirectiveScanLines = 10;
  static const int _awsAccessKeyLength = 20;
  static const double _awsEntropyThreshold = 3.5;
  static const int _genericSecretLineMinLength = 20;
  static const double _genericSecretEntropyThreshold = 4.0;
  static const int _bearerTokenMinLength = 20;
  static const double _bearerTokenEntropyThreshold = 3.8;
  static const int _githubPatMinLength = 40;
  static const double _highEntropyThreshold = 4.5;

  /// Analyze a directory for secrets
  List<SecretIssue> analyzeDirectory(
    Directory directory, {
    List<String> excludePatterns = const [],
  }) {
    final issues = <SecretIssue>[];

    final dartFiles = Directory(directory.path)
        .listSync(recursive: true, followLinks: false)
        .whereType<File>()
        .cast<File>()
        .where((file) =>
            file.path.endsWith('.dart') &&
            _shouldIncludeFile(file, excludePatterns))
        .toList();

    for (final file in dartFiles) {
      try {
        final content = file.readAsStringSync();
        final fileIssues = _analyzeFileContent(file.path, content);
        issues.addAll(fileIssues);
      } catch (e) {
        continue;
      }
    }

    return issues;
  }

  bool _shouldIncludeFile(File file, List<String> excludePatterns) {
    final relativePath = file.path.split(Platform.pathSeparator).join('/');

    for (final pattern in excludePatterns) {
      if (Glob(pattern).matches(relativePath)) {
        return false;
      }
    }

    return true;
  }

  List<SecretIssue> _analyzeFileContent(String filePath, String content) {
    final issues = <SecretIssue>[];
    final lines = content.split('\n');

    // Check for ignore directive
    for (final line in lines.take(_ignoreDirectiveScanLines)) {
      if (line.trim().contains('// ignore: fcheck_secrets')) {
        return [];
      }
    }

    for (int i = 0; i < lines.length; i++) {
      final lineFindings = _scanLine(lines[i], filePath, i + 1);
      issues.addAll(lineFindings);
    }

    return issues;
  }

  List<SecretIssue> _scanLine(String line, String filePath, int lineNumber) {
    /// ignore: fcheck_secrets
    final findings = <SecretIssue>[];

    // AWS Access Key - AKIA[0-9A-Z]{16}
    if (_detectAwsAccessKey(line)) {
      findings.add(SecretIssue(
        filePath: filePath,
        lineNumber: lineNumber,
        secretType: 'aws_access_key',
        value: 'AWS Access Key detected',
      ));
    }

    // Generic Secret - api[_-]?key|token|secret|password|private_key
    if (_detectGenericSecret(line)) {
      findings.add(SecretIssue(
        filePath: filePath,
        lineNumber: lineNumber,
        secretType: 'generic_secret',
        value: 'Generic secret detected',
      ));
    }

    // Bearer Token
    if (_detectBearerToken(line)) {
      findings.add(SecretIssue(
        filePath: filePath,
        lineNumber: lineNumber,
        secretType: 'bearer_token',
        value: 'Bearer token detected',
      ));
    }

    // Private Key
    if (_detectPrivateKey(line)) {
      findings.add(SecretIssue(
        filePath: filePath,
        lineNumber: lineNumber,
        secretType: 'private_key',
        value: 'Private key detected',
      ));
    }

    // Email PII
    if (_detectEmail(line)) {
      findings.add(SecretIssue(
        filePath: filePath,
        lineNumber: lineNumber,
        secretType: 'email_pii',
        value: 'Email address detected',
      ));
    }

    // Stripe Keys
    if (_detectStripeKey(line)) {
      findings.add(SecretIssue(
        filePath: filePath,
        lineNumber: lineNumber,
        secretType: 'stripe_key',
        value: 'Stripe key detected',
      ));
    }

    // GitHub PAT
    if (_detectGitHubPAT(line)) {
      findings.add(SecretIssue(
        filePath: filePath,
        lineNumber: lineNumber,
        secretType: 'github_pat',
        value: 'GitHub PAT detected',
      ));
    }

    // High Entropy Strings
    if (_detectHighEntropyString(line)) {
      findings.add(SecretIssue(
        filePath: filePath,
        lineNumber: lineNumber,
        secretType: 'high_entropy',
        value: 'High entropy string detected',
      ));
    }

    return findings;
  }

  bool _detectAwsAccessKey(String line) {
    final regex = RegExp(r'AKIA[0-9A-Z]{16}');
    final matches = regex.allMatches(line);
    for (final match in matches) {
      final candidate = match.group(0) ?? '';
      if (candidate.length == _awsAccessKeyLength &&
          _calculateEntropy(candidate) > _awsEntropyThreshold) {
        return true;
      }
    }
    return false;
  }

  bool _detectGenericSecret(String line) {
    final regex = RegExp(r'api[_-]?key|token|secret|password|private_key',
        caseSensitive: false);
    if (regex.hasMatch(line) &&
        line.contains('=') &&
        line.length > _genericSecretLineMinLength) {
      return _calculateEntropy(line) > _genericSecretEntropyThreshold;
    }
    return false;
  }

  bool _detectBearerToken(String line) {
    final regex = RegExp(
      'Bearer\\s+[a-zA-Z0-9_\\-]{$_bearerTokenMinLength,}',
      caseSensitive: false,
    );
    final matches = regex.allMatches(line);
    for (final match in matches) {
      final candidate = match.group(0) ?? '';
      if (_calculateEntropy(candidate) > _bearerTokenEntropyThreshold) {
        return true;
      }
    }
    return false;
  }

  bool _detectPrivateKey(String line) {
    final regex = RegExp(
        r'-----BEGIN\s+(RSA|EC|DSA|OPENSSH)\s+PRIVATE\s+KEY-----',
        caseSensitive: false);
    return regex.hasMatch(line);
  }

  bool _detectEmail(String line) {
    final regex = RegExp(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}',
        caseSensitive: false);
    return regex.hasMatch(line);
  }

  bool _detectStripeKey(String line) {
    final regex = RegExp(r'(sk_live_|pk_live_)[0-9a-zA-Z]{24}');
    return regex.hasMatch(line);
  }

  bool _detectGitHubPAT(String line) {
    final regex = RegExp(r'gh[p|s|o|u|l]_[0-9a-zA-Z]{36}|[gG]ithub_pat_');
    final matches = regex.allMatches(line);
    for (final match in matches) {
      final candidate = match.group(0) ?? '';
      if (candidate.length >= _githubPatMinLength) {
        return true;
      }
    }
    return false;
  }

  bool _detectHighEntropyString(String line) {
    final regex = RegExp(r'[a-zA-Z0-9+/]{32,}');
    final matches = regex.allMatches(line);
    for (final match in matches) {
      final candidate = match.group(0) ?? '';
      if (_calculateEntropy(candidate) > _highEntropyThreshold) {
        return true;
      }
    }
    return false;
  }

  double _calculateEntropy(String str) {
    if (str.isEmpty) return 0.0;

    final counts = <String, int>{};
    for (final char in str.runes) {
      final charStr = String.fromCharCode(char);
      counts[charStr] = (counts[charStr] ?? 0) + 1;
    }

    double entropy = 0.0;
    final length = str.length;

    for (final count in counts.values) {
      final probability = count / length;
      entropy -= probability * (log(probability) / ln2);
    }

    return entropy;
  }
}
