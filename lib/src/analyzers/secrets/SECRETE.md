# Secret Scanner (CLI)

## Overview

This repo's CLI uses a line-based secret scanner (`SecretScanner`) via
`SecretDelegate` in the unified analyzer runner.

## What It Flags

- AWS access keys: `AKIA[0-9A-Z]{16}` with length 20 and entropy > 3.5.
- Generic secrets on assignment lines containing `api_key`, `token`, `secret`,
  `password`, `private_key` with value length >= 20 and entropy > 4.0.
- Bearer tokens: `Bearer <token>` with length >= 20 and entropy > 3.8.
- Private key headers: `-----BEGIN (RSA|EC|DSA|OPENSSH) PRIVATE KEY-----`.
- Email addresses.
- Stripe keys: `sk_live_` or `pk_live_` + 24 chars.
- GitHub PATs: `gh[p|s|o|u|l]_<36>` or `github_pat_` with length >= 40.
- High entropy strings: `[a-zA-Z0-9+/]{32,}` with entropy > 4.5.

## Ignores and Exclusions

- `// ignore: fcheck_secrets` in the first 10 lines skips a file.
- CLI `--exclude` patterns are honored.
- When run via `AnalyzeFolder` and `AnalyzerRunner`, default exclusions from
  `FileUtils` are also applied.

## How It Works

- `AnalyzeFolder` / `AnalyzerRunner` select `.dart` files and provide
  pre-split lines in `AnalysisFileContext`.
- `SecretDelegate` runs `SecretScanner` on the lines and emits `SecretIssue`
  entries per match.

## Related Files

- `lib/src/analyzers/secrets/secret_scanner.dart`
- `lib/src/analyzers/secrets/secret_issue.dart`
- `lib/src/analyzer_runner/analyzer_delegates.dart`
- `lib/src/models/ignore_config.dart`
