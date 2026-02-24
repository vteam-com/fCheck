# Publishing a New Release

Follow these steps to publish a new version of fcheck to pub.dev:

## 1. Commit Current Code Changes

Ensure all changes are committed and pushed to the main branch:

```bash
git add .
git commit -m "Brief description of changes"
git push origin main
```

## 2. Bump the Version

Update the version in `pubspec.yaml`. Follow semantic versioning:

- **MAJOR** version for incompatible API changes
- **MINOR** version for backwards-compatible functionality additions
- **PATCH** version for backwards-compatible bug fixes

```yaml
# Update this line in pubspec.yaml
version: X.Y.Z
```

## 3. Sync Version and Run Checks

After updating the version in `pubspec.yaml`, you must:

1. **Run the version extraction script** to ensure `version.dart` matches `pubspec.yaml`:

   ```bash
   ./tool/generate_version.sh
   ```

2. **Run the complete check suite** to verify all quality standards:

   ```bash
   ./tool/check.sh
   ```

This ensures:

- ✅ `version.dart` is synchronized with `pubspec.yaml`
- ✅ All tests pass
- ✅ Code formatting is applied
- ✅ Static analysis passes
- ✅ No lint warnings or errors

## 4. Update the Changelog

Add a new entry to `CHANGELOG.md` at the top (under the unreleased section):

```markdown
## [X.Y.Z] - YYYY-MM-DD

### Added
- New features or functionality

### Changed
- Changes in existing functionality

### Fixed
- Bug fixes

### Removed
- Removed features or functionality
```

**Note**: If adding global executable support, include:

```markdown
- 🛠️ Global CLI executable support via `executables` configuration
- 📦 Users can now install fcheck globally: `dart pub global activate fcheck`
- 🖥️ Direct command execution: `fcheck ./path/` (after global activation)
```

Update the date to today's date in YYYY-MM-DD format.

For major releases (`X.0.0`), include a dedicated **BREAKING** migration section listing
old CLI flags/file names and their replacements.

## 5. Validate README Output Sample

Always update the version displayed in the README.md bash sample output

If recent changes affect CLI output, update the sample output in `README.md`.
At minimum, make sure the version shown in the README `fcheck` output matches
the version being released.

## 6. Execute the Publish Script

Run the automated publishing script:

```bash
./tool/publish.sh
```

The script will:

- ✅ Verify you're in the correct directory
- ✅ Check that publish_to is not set to 'none'
- ✅ Run all tests
- ✅ Perform a dry-run publish to catch issues
- ✅ Ask for confirmation before publishing
- ✅ Publish to pub.dev

## Post-Publish Checklist

After successful publication:

- [ ] Verify the package appears on [pub.dev/packages/fcheck](https://pub.dev/packages/fcheck)
- [ ] Check that the new version is listed correctly
- [ ] Test installing the published version: `dart pub global activate fcheck`
- [ ] Create a GitHub release with the changelog notes
- [ ] Announce the release in relevant communities/forums

## Troubleshooting

**If publish fails:**

- Check that all tests pass: `dart test`
- Ensure version number is unique and follows semantic versioning
- Verify you have publish permissions for the package
- Check that `publish_to` is not set to 'none' in pubspec.yaml

**If you need to unpublish:**

```bash
dart pub unpublish fcheck --version <version>
```

Note: You can only unpublish within 7 days of publication.</content>
