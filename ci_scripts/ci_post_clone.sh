#!/bin/sh
set -e

./check_preconditions.sh

cd ..

curl https://mise.run | sh
export PATH="$HOME/.local/bin:$PATH"

mise install
eval "$(mise activate bash --shims)"

tuist install
TUIST_XCODE_CLOUD_BUILD_NUMBER="${CI_BUILD_NUMBER:?CI_BUILD_NUMBER must be set}" tuist generate --no-open
