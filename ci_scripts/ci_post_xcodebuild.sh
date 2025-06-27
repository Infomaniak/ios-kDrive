#!/bin/sh
set -e

 ./check_preconditions.sh

cd ..

curl https://mise.run | sh
export PATH="$HOME/.local/bin:$PATH"

mise install
eval "$(mise activate bash --shims)"


if [[ -n $CI_ARCHIVE_PATH ]]; then
    retries=0
    max_retries=3
    until [ $retries -ge $max_retries ]
    do
        sentry-cli --url $SENTRY_URL --auth-token $SENTRY_AUTH_TOKEN upload-dif --org sentry --project $SENTRY_PROJECT --include-sources $CI_DERIVED_DATA_PATH && break
        retries=$((retries+1))
        echo "Retry $retries/$max_retries for sentry-cli failed."
        sleep 2
    done

    if [ $retries -eq $max_retries ]; then
        echo "sentry-cli failed after $max_retries attempts."
        exit 1
    fi
else
    echo "Archive path isn't available. Unable to run dSYMs uploading script."
fi
