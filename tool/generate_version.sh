#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
PUBSPEC="$ROOT_DIR/pubspec.yaml"
OUT_FILE="$ROOT_DIR/lib/src/models/version.dart"

if [ ! -f "$PUBSPEC" ]; then
  echo "pubspec.yaml not found at $PUBSPEC" >&2
  exit 1
fi

version=$(awk -F ':[[:space:]]*' '
  /^[[:space:]]*version:[[:space:]]*/ {
    v=$2
    sub(/^[[:space:]]+/, "", v)
    sub(/[[:space:]]+$/, "", v)
    print v
    exit
  }
' "$PUBSPEC")

version=$(printf '%s' "$version" | sed -E "s/^['\"]//; s/['\"]$//")

if [ -z "$version" ]; then
  echo "Version not found in $PUBSPEC" >&2
  exit 1
fi

mkdir -p "$(dirname -- "$OUT_FILE")"

# Remove existing version.dart file if it exists
rm -f "$OUT_FILE"

cat > "$OUT_FILE" <<EOF2
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint

/// Package version, generated from pubspec.yaml.
const String packageVersion = '$version';
EOF2

echo "Wrote $OUT_FILE (version $version)"
