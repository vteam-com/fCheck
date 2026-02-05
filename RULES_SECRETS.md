# Rule for Secrets Analysis

## Overview

Scans Dart source for potential secrets and PII using regex and entropy heuristics.

## What It Flags

- AWS access keys: `AKIA[0-9A-Z]{16}` with entropy > 3.5.
- Generic secrets on assignment lines containing `api_key`, `token`, `secret`, `password`, `private_key` with entropy > 4.0 and line length > 20.
- Bearer tokens: `Bearer <token>` with length >= 20 and entropy > 3.8.
- Private key headers: `-----BEGIN ... PRIVATE KEY-----`.
- Email addresses.
- Stripe keys: `sk_live_` or `pk_live_` + 24 chars.
- GitHub PATs: `gh[p|s|o|u|l]_<36>` or `github_pat_`.
- High entropy strings: `[a-zA-Z0-9+/]{32,}` with entropy > 4.5.

## How It Works

- `SecretAnalyzer` recursively scans `.dart` files, applies exclude globs, then scans each line.
- `SecretDelegate` is used by the unified analyzer runner and scans the pre-split lines for each Dart file.
- Matches are emitted as `SecretIssue` entries with a `secretType` label.

## Ignores and Exclusions

- `// ignore: fcheck_secrets` in the first 10 lines skips a file.
- CLI `--exclude` patterns are honored.
- When run via `AnalyzeFolder` and `AnalyzerRunner`, default exclusions from `FileUtils` are also applied.

## Output

- `SecretIssue` contains `filePath`, `lineNumber`, `secretType`, `value`.

## Related Files

- `lib/src/analyzers/secrets/secret_analyzer.dart`
- `lib/src/analyzers/secrets/secret_issue.dart`
- `lib/src/analyzer_runner/analyzer_delegates.dart`

## Notes

- The scanner is line-based and may produce false positives for high-entropy or email-like strings.
- Only `.dart` files are scanned.
