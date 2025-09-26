#!/bin/sh
set -e

# CI_BUILD_NUMBER - The build number assigned by Xcode Cloud.
# CI_PRIMARY_REPOSITORY_PATH - The location of the source code in the Xcode Cloud runner.
# CI_PRODUCT - The name of the product being built.
#
# GITHUB_LOCAL_TOKEN - A GitHub token with permissions to create releases.
#
# KCHAT_PRODUCT_ICON - The icon to use for the product in the kChat message.
# KCHAT_WEBHOOK_URL - The webhook URL for the kChat channel.

# Install only if missing
command -v gh >/dev/null 2>&1 || brew install gh

# MARK: - Push Git Tag

# Navigate to the repository
cd "$CI_PRIMARY_REPOSITORY_PATH"

# Get version from the built app
VERSION=$(xcodebuild -showBuildSettings | grep MARKETING_VERSION | awk '{print $3}')

# Ensure VERSION is not empty
if [ -z "$VERSION" ]; then
    echo "⚠️ Error while retrieving version from Info.plist"
    exit 1
fi

TAG_NAME="Beta-$VERSION-b$CI_BUILD_NUMBER"

# MARK: - GitHub Release

gh auth login --with-token <<< "$GITHUB_LOCAL_TOKEN"
RELEASE_URL=$(gh release create $TAG_NAME --generate-notes --target $CI_COMMIT)

# MARK: - kChat Notification

AAPL_LOGO=$(((RANDOM % 120) + 1))
TESTFLIGHT_RELEASE_NOTE=$(cat "$CI_PRIMARY_REPOSITORY_PATH/TestFlight/WhatToTest.en-GB.txt")

MESSAGE=$(cat <<EOF
#### :aapl-$AAPL_LOGO::$KCHAT_PRODUCT_ICON: $CI_PRODUCT
##### :testflight: Version $VERSION-b$CI_BUILD_NUMBER available on TestFlight

$TESTFLIGHT_RELEASE_NOTE


:github:  [See changelog]($RELEASE_URL)
EOF
)

MESSAGE_JSON=$(printf '%s' "$MESSAGE" | jq -Rs '{text: .}')
curl -i -X POST \
    -H 'Content-Type: application/json' \
    -d "$MESSAGE_JSON" \
    "$KCHAT_WEBHOOK_URL"
