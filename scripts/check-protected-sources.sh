#!/bin/sh
set -eu
ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"
MANIFEST="scripts/protected-sources.sha256"
if [ "${ALLOW_PROTECTED_SOURCE_CHANGES:-}" = "1" ]; then
  echo "WARNING: protected-source checksum enforcement explicitly bypassed."
  exit 0
fi
if [ ! -f "$MANIFEST" ]; then
  echo "ERROR: protected-source manifest missing: $MANIFEST" >&2
  exit 1
fi
if ! shasum -a 256 -c "$MANIFEST"; then
  echo "ERROR: a protected original is missing or changed." >&2
  echo "Do not edit imported originals when working on Swift ports." >&2
  echo "For an intentional source update, review the diff and update the manifest deliberately." >&2
  echo "ALLOW_PROTECTED_SOURCE_CHANGES=1 only bypasses this check for one command." >&2
  exit 1
fi
