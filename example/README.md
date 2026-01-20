# Example Flutter App for Testing fcheck

This example Flutter application demonstrates various code quality scenarios that can be analyzed by the fcheck quality analyzer.

## File Structure and Test Cases

### Compliant Files (follow "one class per file" rule):
- `lib/utils.dart` - Single class file ✅
- `lib/home_page.dart` - StatefulWidget with State class (2 classes, acceptable) ✅

### Non-Compliant Files (violate "one class per file" rule):
- `lib/main.dart` - Contains 2 classes ❌
- `lib/models.dart` - Contains 3 classes ❌
- `lib/widgets.dart` - StatefulWidget with 4 classes total ❌

### Special Cases:
- `lib/comments_example.dart` - High comment ratio for testing comment counting

## Running the Analyzer

To test the fcheck analyzer on this example:

```bash
# From the root of the fcheck project
dart run bin/quality_check.dart --path example
```

## Expected Output

The analyzer should report:
- Total files, folders, and lines of code
- Comment ratio
- Files that violate the "one class per file" rule with their class counts

This example helps verify that the analyzer correctly identifies:
- Single class files as compliant
- Multiple class files as non-compliant
- StatefulWidget files with exactly 2 classes as compliant
- StatefulWidget files with more than 2 classes as non-compliant
- Comment line counting accuracy
