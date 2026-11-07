#!/usr/bin/env bash
# Publish a new version of the app to GitHub Releases.
#
#   ./release.sh 1.1.0                 # notes generated from commits
#   ./release.sh 1.1.0 notes.md        # notes from a file
#   ./release.sh --dry-run 1.1.0       # show what would happen, change nothing
#
# Updates the version in roku-frm/manifest, commits, tags vX.Y.Z, pushes,
# builds frm-roku-dashboard.zip and creates the GitHub release with it attached.
set -euo pipefail
cd "$(dirname "$0")"

DRY_RUN=0
if [[ "${1:-}" == "--dry-run" ]]; then DRY_RUN=1; shift; fi

VERSION="${1:-}"
NOTES_FILE="${2:-}"
ZIP=frm-roku-dashboard.zip
MANIFEST=roku-frm/manifest

die() { echo "Error: $*" >&2; exit 1; }

[[ "$VERSION" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]] || die "usage: ./release.sh [--dry-run] X.Y.Z [notes-file]"
MAJOR=${BASH_REMATCH[1]} MINOR=${BASH_REMATCH[2]} BUILD=${BASH_REMATCH[3]}
TAG="v$VERSION"

[[ -z "$NOTES_FILE" || -f "$NOTES_FILE" ]] || die "notes file not found: $NOTES_FILE"
command -v gh >/dev/null || die "GitHub CLI (gh) is not installed"
gh auth status >/dev/null 2>&1 || die "gh is not logged in (run: gh auth login)"

# Release only clean, pushed work from main
[[ "$(git rev-parse --abbrev-ref HEAD)" == "main" ]] || die "switch to the main branch first"
[[ -z "$(git status --porcelain)" ]] || die "you have uncommitted changes; commit or stash them first"
git fetch -q origin main
[[ "$(git rev-parse HEAD)" == "$(git rev-parse origin/main)" ]] || die "main is not in sync with origin/main; push or pull first"
if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null || git ls-remote --exit-code --tags origin "$TAG" >/dev/null 2>&1; then
  die "tag $TAG already exists"
fi

CURRENT="$(grep -E '^major_version=' $MANIFEST | cut -d= -f2).$(grep -E '^minor_version=' $MANIFEST | cut -d= -f2).$(grep -E '^build_version=' $MANIFEST | cut -d= -f2)"
LATEST="$(git describe --tags --abbrev=0 2>/dev/null || echo none)"

echo "Release $TAG"
echo "  manifest version: $CURRENT -> $VERSION"
echo "  previous tag:     $LATEST"
echo "  notes:            ${NOTES_FILE:-generated from commits since $LATEST}"
echo "  will: commit + tag + push to origin/main, build $ZIP, create GitHub release"

if (( DRY_RUN )); then echo "Dry run: nothing changed."; exit 0; fi

read -r -p "Continue? [y/N] " answer
[[ "$answer" =~ ^[Yy]$ ]] || { echo "Cancelled."; exit 1; }

# Update the version (skip the commit if the manifest already has it)
sed -i -E "s/^major_version=.*/major_version=$MAJOR/; s/^minor_version=.*/minor_version=$MINOR/; s/^build_version=.*/build_version=$BUILD/" $MANIFEST
if ! git diff --quiet -- $MANIFEST; then
  git add $MANIFEST
  git commit -q -m "Release $TAG"
fi
git tag -a "$TAG" -m "Release $TAG"
git push -q origin main "$TAG"

rm -f "$ZIP"
(cd roku-frm && zip -qr "../$ZIP" manifest source components images sounds)

if [[ -n "$NOTES_FILE" ]]; then
  gh release create "$TAG" "$ZIP" --title "$TAG" --notes-file "$NOTES_FILE"
else
  gh release create "$TAG" "$ZIP" --title "$TAG" --generate-notes
fi
