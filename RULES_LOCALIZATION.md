# Localization Coverage Rules

This document defines the behavior and rules for the localization analyzer in fCheck.

## Overview

The localization analyzer helps engineers find discrepancies between localization languages in Flutter projects. It analyzes ARB (Application Resource Bundle) files to identify missing translations and provides coverage metrics for each supported language.

## Detection Criteria

fCheck automatically enables localization analysis when:

1. `l10n.yaml` configuration file exists in the project root, OR
2. `.arb` files are present in `lib/l10n/` directory, OR
3. Source files reference `AppLocalizations` or `flutter_gen/gen_l10n`

## File Analysis

### Supported File Locations

- Primary: `lib/l10n/*.arb`
- Fallback: Any `.arb` files in the project directory tree when no primary ARB files are found

### Supported File Naming Patterns

- `app_<locale>.arb` (e.g., `app_en.arb`, `app_es.arb`)
- `messages_<locale>.arb` (e.g., `messages_fr.arb`)
- `l10n_<locale>.arb` (e.g., `l10n_de.arb`)
- `<locale>.arb` (e.g., `en.arb`)
- Locale variants are supported too (e.g., `app_pt_BR.arb`, `app_zh_Hans.arb`)

### Base Language Detection

1. **Preferred**: English file (`en.arb` or `app_en.arb`)
2. **Fallback**: First ARB file found in alphabetical order

## Translation Analysis

### Included Keys

- String literal keys (e.g., `"hello": "Hello"`)
- All user-facing translation strings that are present, non-empty, and meaningfully translated

### Excluded Keys

- Metadata keys starting with `@` (e.g., `"@hello": {"description": "Greeting"}`)
- Special keys starting with `@@` (e.g., `"@@locale": "en"`)
- Technical and framework-generated metadata

### Duplicate Keys

- Duplicate top-level ARB keys are reported as warnings because JSON decoding keeps the last value and silently overwrites earlier entries.

### Unused English Keys

- When the base locale is English, fCheck scans app Dart sources under `lib/` and reports base ARB keys that are never referenced.
- Generated localization Dart files and `lib/l10n/**` support files are excluded from this usage scan so generated getters do not mask orphan strings.
- Unused English keys are reported as localization issues on the base locale because they are dead/orphan strings that should be removed.

### Coverage Calculation

For each non-base language:

- **Coverage Percentage**: `((total_keys - missing_keys) / total_keys) * 100`
- **Missing Count**: Number of keys present in base language but absent in target language
- **Total Count**: Number of translatable keys in base language
- Keys whose `@key.description` explicitly says `DO NOT TRANSLATE`, `ignore`, `reviewed`, or equivalent guidance in either the base ARB or the translated ARB are excluded from totals and warnings
- Strings that are empty, unchanged from the base locale, or have placeholder drift are counted as missing
- Unused English keys do not reduce translation coverage, but they are still reported as localization problems

## Issue Reporting

### Issue Structure

Each localization issue includes:

- **Language Code**: ISO language code (e.g., 'es', 'fr', 'de')
- **Language Name**: Display name (e.g., 'Spanish', 'French', 'German')
- **Missing Count**: Number of missing translations
- **Total Count**: Total strings in base language
- **Coverage Percentage**: Translation completeness (0.0% to 100.0%)

### Reporting Conditions

Issues are reported only when:

- Project uses localization (detected automatically)
- ARB files are found
- Language has missing translations (complete translations are not reported)

## Language Support

### Supported Languages

The analyzer recognizes common language codes and provides display names:

- `en` - English
- `es` - Spanish
- `fr` - French
- `de` - German
- `it` - Italian
- `pt` - Portuguese
- `ru` - Russian
- `ja` - Japanese
- `ko` - Korean
- `zh` - Chinese
- `ar` - Arabic
- And many more...

### Unknown Language Codes

For unrecognized language codes, the analyzer:

- Uses the primary language subtag in uppercase as display name
- Still performs coverage analysis

## Edge Cases

### Empty Base Language

- If base language contains no translatable keys, coverage is 100% for all languages
- No issues are reported

### Malformed ARB Files

- Files with invalid YAML syntax are skipped
- Analysis continues with other valid ARB files
- No errors are reported for malformed files

### Single Language Projects

- If only base language exists, no issues are reported
- Analyzer shows as complete with 0 issues

## Configuration

### Enable/Disable

Use `.fcheck` configuration file:

```yaml
analyzers:
  disabled:
    - localization  # Disable localization analyzer
```

```yaml
analyzers:
  default: off
  enabled:
    - localization  # Enable only localization analyzer
```

## Integration with Other Analyzers

### Hardcoded Strings Analyzer

- When localization is detected, hardcoded strings analyzer becomes more strict
- Missing translations may indicate hardcoded strings that should be localized

### Code Size Analysis

- Generated localization files are excluded from code size metrics
- ARB files are not counted as Dart source files

## Best Practices

1. **Complete Translations**: Ensure all supported languages have complete translations before releases
2. **Consistent Keys**: Use descriptive, consistent key names across all language files
3. **Regular Reviews**: Check localization coverage when adding new features
4. **Fallback Testing**: Test app behavior with missing translations to ensure graceful fallbacks
5. **Translation Tools**: Consider professional translation tools for large-scale projects

## Troubleshooting

### Analyzer Not Running

- Verify ARB files exist in `lib/l10n/` directory
- Check `l10n.yaml` configuration if present
- Ensure project imports `AppLocalizations` or uses localization

### False Positives

- Review ARB file structure and naming
- Check for malformed YAML syntax
- Verify metadata keys use proper `@` prefix
- Use ARB descriptions such as `reviewed`, `DO NOT TRANSLATE`, or `ignore` for intentional identical text or brand names
- Fix duplicate top-level keys instead of suppressing them because later entries overwrite earlier ones
- Correct placeholder mismatches and empty strings rather than suppressing them unless the value is intentionally exempt
- Remove orphan English keys that are no longer referenced from app source, rather than suppressing the warning

### Missing Languages

- Confirm file naming follows supported patterns
- Check language codes are valid ISO codes
- Verify files are in correct directory location
