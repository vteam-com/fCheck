import 'dart:math';
import 'package:fcheck/src/analyzers/secrets/secret_issue.dart';
import 'package:fcheck/src/models/ignore_config.dart';

/// Shared scanner for secret detection across analyzers and delegates.
class SecretScanner {
  /// Number of leading lines checked for `// ignore: fcheck_secrets`.
  static const int ignoreDirectiveScanLines = 10;

  /// Expected length of AWS access key candidates.
  static const int awsAccessKeyLength = 20;

  /// Minimum entropy required to consider an AWS access key valid.
  static const double awsEntropyThreshold = 3.5;

  /// Minimum value length for generic secret detection.
  static const int genericSecretValueMinLength = 20;

  /// Minimum entropy required to consider a generic secret valid.
  static const double genericSecretEntropyThreshold = 4.0;

  /// Match group index for extracted generic secret values.
  static const int genericSecretValueGroupIndex = 3;

  /// Minimum bearer token length to consider for detection.
  static const int bearerTokenMinLength = 20;

  /// Minimum entropy required to consider a bearer token valid.
  static const double bearerTokenEntropyThreshold = 3.8;

  /// Minimum length for GitHub PAT candidates.
  static const int githubPatMinLength = 40;

  /// Minimum entropy required to consider a high-entropy string valid.
  static const double highEntropyThreshold = 4.5;

  /// Scans full file content for secrets and returns detected issues.
  List<SecretIssue> analyzeContent({
    required String filePath,
    required String content,
  }) {
    final lines = content.split('\n');
    return analyzeLines(filePath: filePath, lines: lines);
  }

  /// Scans a list of lines for secrets and returns detected issues.
  List<SecretIssue> analyzeLines({
    required String filePath,
    required List<String> lines,
  }) {
    for (final line in lines.take(ignoreDirectiveScanLines)) {
      if (line.trim().contains(IgnoreConfig.ignoreDirectiveForSecrets)) {
        return [];
      }
    }

    final issues = <SecretIssue>[];
    for (int i = 0; i < lines.length; i++) {
      issues.addAll(_scanLine(lines[i], filePath, i + 1));
    }
    return issues;
  }

  List<SecretIssue> _scanLine(String line, String filePath, int lineNumber) {
    final findings = <SecretIssue>[];

    // AWS Access Key
    if (_detectAwsAccessKey(line)) {
      findings.add(SecretIssue(
        filePath: filePath,
        lineNumber: lineNumber,
        secretType: 'aws_access_key',
        value: 'AWS Access Key detected',
      ));
    }

    // Generic Secret
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
    return _hasMatchingCandidate(
      line,
      RegExp(r'AKIA[0-9A-Z]{16}'),
      (candidate) =>
          candidate.length == awsAccessKeyLength &&
          _calculateEntropy(candidate) > awsEntropyThreshold,
    );
  }

  bool _detectGenericSecret(String line) {
    final keywordRegex = RegExp(
      r'api[_-]?key|token|secret|password|private_key',
      caseSensitive: false,
    );
    final assignmentRegex = RegExp(
      "([\\w\$\"'.-]+)\\s*[:=]\\s*r?(['\"])([^'\"]+)\\2",
      caseSensitive: false,
    );
    final tripleQuoteRegex = RegExp(
      "([\\w\$\"'.-]+)\\s*[:=]\\s*r?('''|\"\"\")(.+?)\\2",
      caseSensitive: false,
    );

    final candidates = <String>[];
    for (final match in assignmentRegex.allMatches(line)) {
      final lhs = match.group(1) ?? '';
      if (!keywordRegex.hasMatch(lhs)) {
        continue;
      }
      final candidate = match.group(genericSecretValueGroupIndex) ?? '';
      if (candidate.isNotEmpty) {
        candidates.add(candidate);
      }
    }
    for (final match in tripleQuoteRegex.allMatches(line)) {
      final lhs = match.group(1) ?? '';
      if (!keywordRegex.hasMatch(lhs)) {
        continue;
      }
      final candidate = match.group(genericSecretValueGroupIndex) ?? '';
      if (candidate.isNotEmpty) {
        candidates.add(candidate);
      }
    }

    for (final candidate in candidates) {
      if (candidate.length >= genericSecretValueMinLength &&
          _calculateEntropy(candidate) > genericSecretEntropyThreshold) {
        return true;
      }
    }
    return false;
  }

  bool _detectBearerToken(String line) {
    return _hasMatchingCandidate(
      line,
      RegExp(
        'Bearer\\s+[a-zA-Z0-9_\\-]{${SecretScanner.bearerTokenMinLength},}',
        caseSensitive: false,
      ),
      (candidate) => _calculateEntropy(candidate) > bearerTokenEntropyThreshold,
    );
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
    return _hasMatchingCandidate(
      line,
      RegExp(r'gh[p|s|o|u|l]_[0-9a-zA-Z]{36}|[gG]ithub_pat_'),
      (candidate) => candidate.length >= githubPatMinLength,
    );
  }

  bool _detectHighEntropyString(String line) {
    return _hasMatchingCandidate(
      line,
      RegExp(r'[a-zA-Z0-9+/]{32,}'),
      (candidate) => _calculateEntropy(candidate) > highEntropyThreshold,
    );
  }

  bool _hasMatchingCandidate(
    String line,
    RegExp regex,
    bool Function(String) isMatch,
  ) {
    for (final match in regex.allMatches(line)) {
      final candidate = match.group(0) ?? '';
      if (isMatch(candidate)) {
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
