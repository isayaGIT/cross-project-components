#!/usr/bin/env bash
set -euo pipefail

COMPONENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$COMPONENT_DIR/.build"
LOG_FILE="$BUILD_DIR/build.log"
mkdir -p "$BUILD_DIR"

printf 'Component: Avatar\nPackage:   %s\nBuild dir: %s\n\n' "$COMPONENT_DIR" "$BUILD_DIR"
set +e
swift build --package-path "$COMPONENT_DIR" --scratch-path "$BUILD_DIR/swiftpm" 2>&1 | tee "$LOG_FILE"
STATUS=${PIPESTATUS[0]}
set -e

if [[ "$STATUS" -eq 0 ]]; then
  printf '\nPASS: Avatar standalone build succeeded.\nLog: %s\n' "$LOG_FILE"
else
  printf '\nFAIL: Avatar standalone build failed (exit %s).\nLog: %s\n' "$STATUS" "$LOG_FILE" >&2
fi
exit "$STATUS"
