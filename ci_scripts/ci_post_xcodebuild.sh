#!/bin/sh
set -e

 ./check_preconditions.sh

cd ..

curl https://mise.run | sh
export PATH="$HOME/.local/bin:$PATH"

mise install
eval "$(mise activate bash --shims)"


if [[ -n $CI_ARCHIVE_PATH ]];
then
    # Upload dSYMs
    sentry-cli --url $SENTRY_URL --auth-token $SENTRY_AUTH_TOKEN upload-dif --org sentry --project $SENTRY_PROJECT $CI_ARCHIVE_PATH
else
    echo "Archive path isn't available. Unable to run dSYMs uploading script."
fi
