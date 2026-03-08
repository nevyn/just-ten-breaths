#!/usr/bin/env bash
# release.sh — bump version, commit, push, and create a GitHub release.
# The release triggers CI which builds, signs, notarizes, and attaches the zip.
#
# Usage:
#   ./release.sh [minor|major] [--dry-run]
#   ./release.sh redo [--dry-run]
#
#   --dry-run  Print every step (including Claude-generated notes) without
#              touching the pbxproj, git, or GitHub.
#
#   redo       Re-release the current version: deletes the GitHub release and
#              tag, bumps the build number, recommits, and creates a fresh
#              release at HEAD with the same version and changelog.

set -euo pipefail

# ── Parse args (order-independent) ───────────────────────────────────────────

BUMP="minor"
DRY_RUN=false
REDO=false

for arg in "$@"; do
    case "$arg" in
        minor|major) BUMP="$arg" ;;
        redo)        REDO=true ;;
        --dry-run)   DRY_RUN=true ;;
        *) echo "error: unknown argument '$arg'" >&2; exit 1 ;;
    esac
done

PBXPROJ="just ten breaths.xcodeproj/project.pbxproj"

# Helper: in dry-run mode, print the command instead of running it.
maybe() {
    if [[ "$DRY_RUN" == true ]]; then
        echo "  [dry run] $*"
    else
        "$@"
    fi
}

[[ "$DRY_RUN" == true ]] && echo "*** DRY RUN — nothing will be written or pushed ***"
echo ""

# ── Sanity checks ────────────────────────────────────────────────────────────

if ! command -v gh &>/dev/null; then
    echo "error: 'gh' CLI not found — install it with: brew install gh" >&2
    exit 1
fi

BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if [[ "$BRANCH" != "main" ]]; then
    echo "error: not on main (currently on '$BRANCH')" >&2
    exit 1
fi

# ── Redo mode ────────────────────────────────────────────────────────────────

if [[ "$REDO" == true ]]; then
    # Read current version from pbxproj (this IS the version we're redoing).
    CURRENT_VERSION="$(grep -m1 'MARKETING_VERSION' "$PBXPROJ" \
        | sed 's/.*MARKETING_VERSION = \(.*\);.*/\1/' | tr -d '\t ')"
    TAG="v${CURRENT_VERSION}"

    # Read current build number.
    CURRENT_BUILD="$(grep -m1 'CURRENT_PROJECT_VERSION' "$PBXPROJ" \
        | sed 's/.*CURRENT_PROJECT_VERSION = \(.*\);.*/\1/' | tr -d '\t ')"
    NEW_BUILD=$((CURRENT_BUILD + 1))

    echo "Redo release: v${CURRENT_VERSION} (build ${CURRENT_BUILD} → ${NEW_BUILD})"
    echo ""

    # Grab the existing release notes before deleting.
    EXISTING_NOTES=""
    if gh release view "$TAG" &>/dev/null; then
        EXISTING_NOTES="$(gh release view "$TAG" --json body --jq .body 2>/dev/null || true)"
        echo "Saved release notes from existing release."
    fi

    # Delete GitHub release.
    if gh release view "$TAG" &>/dev/null; then
        echo "Deleting GitHub release ${TAG}…"
        maybe gh release delete "$TAG" --yes
    else
        echo "No GitHub release found for $TAG (skipping delete)."
    fi

    # Delete remote tag.
    if git ls-remote --tags origin "$TAG" | grep -q "$TAG"; then
        echo "Deleting remote tag ${TAG}…"
        maybe git push origin --delete "$TAG"
    fi

    # Delete local tag.
    if git tag -l "$TAG" | grep -q "$TAG"; then
        echo "Deleting local tag ${TAG}…"
        maybe git tag -d "$TAG"
    fi

    # Bump build number in pbxproj.
    if [[ "$DRY_RUN" == true ]]; then
        echo "  [dry run] sed: CURRENT_PROJECT_VERSION = ${CURRENT_BUILD} → ${NEW_BUILD} in $PBXPROJ"
    else
        sed -i '' \
            "s/CURRENT_PROJECT_VERSION = ${CURRENT_BUILD};/CURRENT_PROJECT_VERSION = ${NEW_BUILD};/g" \
            "$PBXPROJ"
    fi

    # Commit the build number bump (if there are changes).
    if [[ -n "$(git status --porcelain)" ]]; then
        maybe git add "$PBXPROJ"
        maybe git commit -m "Redo v${CURRENT_VERSION} (build ${NEW_BUILD})"
        maybe git push
    fi

    # Re-create the GitHub release with original notes at HEAD.
    RELEASE_FLAGS=(--title "v${CURRENT_VERSION}")
    if [[ -n "$EXISTING_NOTES" ]]; then
        RELEASE_FLAGS+=(--notes "$EXISTING_NOTES")
    else
        RELEASE_FLAGS+=(--generate-notes)
    fi

    maybe gh release create "$TAG" "${RELEASE_FLAGS[@]}"

    echo ""
    if [[ "$DRY_RUN" == true ]]; then
        echo "*** Dry run complete — no changes made. ***"
    else
        echo "✓ Redone v${CURRENT_VERSION} (build ${NEW_BUILD}) — CI is rebuilding."
    fi
    exit 0
fi

# ── Normal release flow ─────────────────────────────────────────────────────

if [[ -n "$(git status --porcelain)" ]]; then
    echo "error: working tree has uncommitted changes — commit or stash them first" >&2
    git status --short
    exit 1
fi

# ── Read current version ─────────────────────────────────────────────────────

CURRENT_VERSION="$(grep -m1 'MARKETING_VERSION' "$PBXPROJ" \
    | sed 's/.*MARKETING_VERSION = \(.*\);.*/\1/' | tr -d '\t ')"

MAJOR="$(echo "$CURRENT_VERSION" | cut -d. -f1)"
MINOR="$(echo "$CURRENT_VERSION" | cut -d. -f2)"

# ── Compute new version ───────────────────────────────────────────────────────

if [[ "$BUMP" == "major" ]]; then
    MAJOR=$((MAJOR + 1))
    MINOR=0
else
    MINOR=$((MINOR + 1))
fi

NEW_VERSION="${MAJOR}.${MINOR}"

echo "Version:  $CURRENT_VERSION → $NEW_VERSION"
echo ""

# ── Update pbxproj ────────────────────────────────────────────────────────────
# Escape dots so sed treats them as literals, not wildcards.

ESC_VER="$(echo "$CURRENT_VERSION" | sed 's/\./\\./g')"

if [[ "$DRY_RUN" == true ]]; then
    echo "  [dry run] sed: MARKETING_VERSION = ${CURRENT_VERSION} → ${NEW_VERSION} in $PBXPROJ"
else
    sed -i '' \
        "s/MARKETING_VERSION = ${ESC_VER};/MARKETING_VERSION = ${NEW_VERSION};/g" \
        "$PBXPROJ"

    CHECK_VER="$(grep -m1 'MARKETING_VERSION' "$PBXPROJ" \
        | sed 's/.*MARKETING_VERSION = \(.*\);.*/\1/' | tr -d '\t ')"
    if [[ "$CHECK_VER" != "$NEW_VERSION" ]]; then
        echo "error: pbxproj update failed — check the file manually" >&2
        exit 1
    fi
fi

# Reset build number to 1 for new versions.
if [[ "$DRY_RUN" == true ]]; then
    echo "  [dry run] sed: CURRENT_PROJECT_VERSION → 1 in $PBXPROJ"
else
    sed -i '' \
        "s/CURRENT_PROJECT_VERSION = [0-9]*;/CURRENT_PROJECT_VERSION = 1;/g" \
        "$PBXPROJ"
fi

# ── Commit & push ─────────────────────────────────────────────────────────────

maybe git add "$PBXPROJ"
maybe git commit -m "Bump version to $NEW_VERSION"
maybe git push

# ── Generate release notes with Claude ───────────────────────────────────────

echo ""
LAST_TAG="$(git describe --tags --abbrev=0 2>/dev/null || true)"

RELEASE_FLAGS=(--title "v${NEW_VERSION}")

if command -v claude &>/dev/null && [[ -n "$LAST_TAG" ]]; then
    echo "Generating release notes with Claude (changes since $LAST_TAG)…"
    echo ""

    # Feed Claude both the commit log and the Swift diff so it has full context
    # even when commit messages are terse.
    COMMIT_LOG="$(git log "${LAST_TAG}..HEAD" --format='%s%n%b' -- 2>/dev/null || true)"
    SWIFT_DIFF="$(git diff "${LAST_TAG}..HEAD" -- '*.swift' 2>/dev/null || true)"

    NOTES="$(cat <<EOF | claude -p --output-format text 2>/dev/null || true
You are writing release notes for just ten breaths, a minimal macOS menu bar breathing reminder app.
Below are the git commits and Swift code changes since the last release (v${CURRENT_VERSION}).
Write a short, friendly release notes body (2–5 bullet points) describing user-facing changes.
Omit version-bump commits and internal/CI plumbing. Use plain markdown bullet points, no header.
You are running non-interactive, so go ahead and decide on your own if you become undecisive
about anything.

Your response is directly piped to the gh tool, so IT IS VERY IMPORTANT that you do not say
any commentary, notes or disclaimers. ONLY say the bullet points for the release notes in
response to this prompt.

## Commits
${COMMIT_LOG}

## Swift diff
${SWIFT_DIFF}
EOF
)"

    if [[ -n "$NOTES" ]]; then
        echo "$NOTES"
        echo ""
        RELEASE_FLAGS+=(--notes "$NOTES")
    else
        echo "Claude returned nothing — falling back to auto-generated notes."
        RELEASE_FLAGS+=(--generate-notes)
    fi
else
    if ! command -v claude &>/dev/null; then
        echo "'claude' CLI not found — falling back to auto-generated notes."
    elif [[ -z "$LAST_TAG" ]]; then
        echo "No previous tag found — falling back to auto-generated notes."
    fi
    RELEASE_FLAGS+=(--generate-notes)
fi

# ── Create GitHub release (triggers CI) ──────────────────────────────────────

maybe gh release create "v${NEW_VERSION}" "${RELEASE_FLAGS[@]}"

echo ""
if [[ "$DRY_RUN" == true ]]; then
    echo "*** Dry run complete — no changes made. ***"
else
    echo "✓ Released v${NEW_VERSION} — CI is building, signing, and notarizing."
fi
