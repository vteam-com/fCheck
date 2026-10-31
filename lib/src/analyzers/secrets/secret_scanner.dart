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

  /// Minimum run length of base64-like characters for high-entropy detection.
  static const int highEntropyMinLength = 32;

  /// Literal prefix shared by all AWS access key candidates.
  static const String _awsAccessKeyPrefix = 'AKIA';

  /// Literal marker that starts every PEM private key header.
  static const String _privateKeyMarker = '-----';

  /// Literal marker shared by Stripe live keys.
  static const String _stripeLiveMarker = '_live_';

  static final RegExp _awsAccessKeyRegex = RegExp(r'AKIA[0-9A-Z]{16}');

  static final RegExp _genericSecretKeywordRegex = RegExp(
    r'api[_-]?key|token|secret|password|private_key',
    caseSensitive: false,
  );

  static final RegExp _genericSecretAssignmentRegex = RegExp(
    "([\\w\$\"'.-]+)\\s*[:=]\\s*r?(['\"])([^'\"]+)\\2",
    caseSensitive: false,
  );

  static final RegExp _genericSecretTripleQuoteRegex = RegExp(
    "([\\w\$\"'.-]+)\\s*[:=]\\s*r?('''|\"\"\")(.+?)\\2",
    caseSensitive: false,
  );

  static final RegExp _bearerTokenRegex = RegExp(
    'Bearer\\s+[a-zA-Z0-9_\\-]{${SecretScanner.bearerTokenMinLength},}',
    caseSensitive: false,
  );

  static final RegExp _privateKeyRegex = RegExp(
    r'-----BEGIN\s+(RSA|EC|DSA|OPENSSH)\s+PRIVATE\s+KEY-----',
    caseSensitive: false,
  );

  static final RegExp _emailRegex = RegExp(
    r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}',
    caseSensitive: false,
  );

  static final RegExp _stripeKeyRegex = RegExp(
    r'(sk_live_|pk_live_)[0-9a-zA-Z]{24}',
  );

  static final RegExp _gitHubPatRegex = RegExp(
    r'gh[p|s|o|u|l]_[0-9a-zA-Z]{36}|[gG]ithub_pat_',
  );

  /// Characters that form high-entropy (base64-like) candidate runs.
  static const String _highEntropyAlphabet =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';

  static final Set<int> _highEntropyCodeUnits = _highEntropyAlphabet.codeUnits
      .toSet();

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

  /// Internal helper used by fcheck analysis and reporting.
  List<SecretIssue> _scanLine(String line, String filePath, int lineNumber) {
    final findings = <SecretIssue>[];

    // AWS Access Key
    if (_detectAwsAccessKey(line)) {
      findings.add(
        SecretIssue(
          filePath: filePath,
          lineNumber: lineNumber,
          secretType: 'aws_access_key',
          value: 'AWS Access Key detected',
        ),
      );
    }

    // Generic Secret
    if (_detectGenericSecret(line)) {
      findings.add(
        SecretIssue(
          filePath: filePath,
          lineNumber: lineNumber,
          secretType: 'generic_secret',
          value: 'Generic secret detected',
        ),
      );
    }

    // Bearer Token
    if (_detectBearerToken(line)) {
      findings.add(
        SecretIssue(
          filePath: filePath,
          lineNumber: lineNumber,
          secretType: 'bearer_token',
          value: 'Bearer token detected',
        ),
      );
    }

    // Private Key
    if (_detectPrivateKey(line)) {
      findings.add(
        SecretIssue(
          filePath: filePath,
          lineNumber: lineNumber,
          secretType: 'private_key',
          value: 'Private key detected',
        ),
      );
    }

    // Email PII
    if (_detectEmail(line)) {
      findings.add(
        SecretIssue(
          filePath: filePath,
          lineNumber: lineNumber,
          secretType: 'email_pii',
          value: 'Email address detected',
        ),
      );
    }

    // Stripe Keys
    if (_detectStripeKey(line)) {
      findings.add(
        SecretIssue(
          filePath: filePath,
          lineNumber: lineNumber,
          secretType: 'stripe_key',
          value: 'Stripe key detected',
        ),
      );
    }

    // GitHub PAT
    if (_detectGitHubPAT(line)) {
      findings.add(
        SecretIssue(
          filePath: filePath,
          lineNumber: lineNumber,
          secretType: 'github_pat',
          value: 'GitHub PAT detected',
        ),
      );
    }

    // High Entropy Strings
    if (_detectHighEntropyString(line)) {
      findings.add(
        SecretIssue(
          filePath: filePath,
          lineNumber: lineNumber,
          secretType: 'high_entropy',
          value: 'High entropy string detected',
        ),
      );
    }

    return findings;
  }

  /// Internal helper used by fcheck analysis and reporting.
  bool _detectAwsAccessKey(String line) {
    if (!line.contains(_awsAccessKeyPrefix)) {
      return false;
    }
    return _hasMatchingCandidate(
      line,
      _awsAccessKeyRegex,
      (candidate) =>
          candidate.length == awsAccessKeyLength &&
          _calculateEntropy(candidate) > awsEntropyThreshold,
    );
  }

  /// Internal helper used by fcheck analysis and reporting.
  bool _detectGenericSecret(String line) {
    // Every candidate's left-hand side is a substring of [line], so a line
    // without any keyword can never yield a candidate.
    if (!_genericSecretKeywordRegex.hasMatch(line)) {
      return false;
    }

    final candidates = <String>[];
    for (final match in _genericSecretAssignmentRegex.allMatches(line)) {
      final lhs = match.group(1) ?? '';
      if (!_genericSecretKeywordRegex.hasMatch(lhs)) {
        continue;
      }
      final candidate = match.group(genericSecretValueGroupIndex) ?? '';
      if (candidate.isNotEmpty) {
        candidates.add(candidate);
      }
    }
    for (final match in _genericSecretTripleQuoteRegex.allMatches(line)) {
      final lhs = match.group(1) ?? '';
      if (!_genericSecretKeywordRegex.hasMatch(lhs)) {
        continue;
      }
      final candidate = match.group(genericSecretValueGroupIndex) ?? '';
      if (candidate.isNotEmpty) {
        candidates.add(candidate);
      }
    }

    for (final candidate in candidates) {
      if (candidate.length >= genericSecretValueMinLength &&
          /// Internal helper used by fcheck analysis and reporting.
          _calculateEntropy(candidate) > genericSecretEntropyThreshold) {
        return true;
      }
    }
    return false;
  }

  /// Internal helper used by fcheck analysis and reporting.
  bool _detectBearerToken(String line) {
    return _hasMatchingCandidate(
      line,
      _bearerTokenRegex,
      (candidate) => _calculateEntropy(candidate) > bearerTokenEntropyThreshold,
    );
  }

  /// Internal helper used by fcheck analysis and reporting.
  bool _detectPrivateKey(String line) {
    return line.contains(_privateKeyMarker) && _privateKeyRegex.hasMatch(line);
  }

  /// Internal helper used by fcheck analysis and reporting.
  bool _detectEmail(String line) {
    return line.contains('@') && _emailRegex.hasMatch(line);
  }

  /// Internal helper used by fcheck analysis and reporting.
  bool _detectStripeKey(String line) {
    return line.contains(_stripeLiveMarker) && _stripeKeyRegex.hasMatch(line);
  }

  /// Internal helper used by fcheck analysis and reporting.
  bool _detectGitHubPAT(String line) {
    return _hasMatchingCandidate(
      line,
      _gitHubPatRegex,
      (candidate) => candidate.length >= githubPatMinLength,
    );
  }

  /// Internal helper used by fcheck analysis and reporting.
  ///
  /// Candidates are maximal runs of [_highEntropyAlphabet] characters at least
  /// [highEntropyMinLength] long. A linear scan finds the same runs as the
  /// equivalent `[a-zA-Z0-9+/]{32,}` regex without its per-position retries.
  bool _detectHighEntropyString(String line) {
    var runStart = 0;
    for (var index = 0; index <= line.length; index++) {
      if (index < line.length &&
          _highEntropyCodeUnits.contains(line.codeUnitAt(index))) {
        continue;
      }
      if (index - runStart >= highEntropyMinLength &&
          _calculateEntropy(line.substring(runStart, index)) >
              highEntropyThreshold) {
        return true;
      }
      runStart = index + 1;
    }
    return false;
  }

  /// Evaluates regex candidates and returns true when any passes [isMatch].
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

  /// Internal helper used by fcheck analysis and reporting.
  double _calculateEntropy(String str) {
    if (str.isEmpty) return 0.0;

    final counts = <int, int>{};
    for (final rune in str.runes) {
      counts[rune] = (counts[rune] ?? 0) + 1;
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
