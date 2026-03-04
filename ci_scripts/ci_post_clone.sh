#!/bin/bash
set -euo pipefail

# Xcode Cloud auto-version bumping.
#
# Reads MARKETING_VERSION from project.yml, bumps it based on the
# latest commit message, then writes the new version into the
# pbxproj build settings so the archive picks it up.
#
# Commit message rules:
#   [major]  → bump major  (1.2.3 → 2.0.0)
#   [minor]  → bump minor  (1.2.3 → 1.3.0)
#   anything else → bump patch (1.2.3 → 1.2.4)
#
# CURRENT_PROJECT_VERSION is set to the Xcode Cloud build number
# (CI_BUILD_NUMBER) so every build has a unique, ascending build number.

REPO_ROOT="$CI_PRIMARY_REPOSITORY_PATH"
PROJECT_YML="$REPO_ROOT/project.yml"
PBXPROJ="$REPO_ROOT/ReadFaster.xcodeproj/project.pbxproj"

CURRENT_VERSION=$(grep 'MARKETING_VERSION:' "$PROJECT_YML" | head -1 | sed 's/.*"\(.*\)"/\1/')
echo "Current version: $CURRENT_VERSION"

IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VERSION"
MAJOR=${MAJOR:-0}
MINOR=${MINOR:-0}
PATCH=${PATCH:-0}

COMMIT_MSG=$(git -C "$REPO_ROOT" log -1 --pretty=%B)
echo "Commit message: $COMMIT_MSG"

if echo "$COMMIT_MSG" | grep -qi '\[major\]'; then
    MAJOR=$((MAJOR + 1))
    MINOR=0
    PATCH=0
    echo "Bumping MAJOR"
elif echo "$COMMIT_MSG" | grep -qi '\[minor\]'; then
    MINOR=$((MINOR + 1))
    PATCH=0
    echo "Bumping MINOR"
else
    PATCH=$((PATCH + 1))
    echo "Bumping PATCH"
fi

NEW_VERSION="${MAJOR}.${MINOR}.${PATCH}"
echo "New version: $NEW_VERSION"

BUILD_NUMBER="${CI_BUILD_NUMBER:-1}"
echo "Build number: $BUILD_NUMBER"

sed -i '' "s/MARKETING_VERSION = [^;]*/MARKETING_VERSION = $NEW_VERSION/" "$PBXPROJ"
sed -i '' "s/CURRENT_PROJECT_VERSION = [^;]*/CURRENT_PROJECT_VERSION = $BUILD_NUMBER/" "$PBXPROJ"

echo "Updated pbxproj → MARKETING_VERSION=$NEW_VERSION CURRENT_PROJECT_VERSION=$BUILD_NUMBER"
