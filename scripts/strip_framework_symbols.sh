#!/bin/bash
set -euo pipefail

if [[ "${CONFIGURATION}" != "Release" ]]; then
    exit 0
fi

frameworks_directory="${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"
if [[ ! -d "${frameworks_directory}" ]]; then
    exit 0
fi

for framework in "${frameworks_directory}"/*.framework; do
    [[ -d "${framework}" ]] || continue
    executable=$(/usr/libexec/PlistBuddy -c "Print :CFBundleExecutable" "${framework}/Info.plist")
    binary="${framework}/${executable}"
    if /usr/bin/codesign --verify --test-requirement="anchor apple" "${binary}" &>/dev/null; then
        echo "Skipping Apple-signed framework: ${framework}"
        continue
    fi
    before=$(stat -f %z "${binary}")

    # Keep exported symbols for dynamic linking; dSYMs remain outside the app bundle.
    chmod u+w "${binary}"
    xcrun strip -S -x "${binary}"

    # Embed Frameworks signs on copy, so refresh that signature before the app is signed.
    if [[ "${CODE_SIGNING_ALLOWED:-NO}" == "YES" && -n "${EXPANDED_CODE_SIGN_IDENTITY:-}" ]]; then
        /usr/bin/codesign --force --sign "${EXPANDED_CODE_SIGN_IDENTITY}" \
            --preserve-metadata=identifier,entitlements,flags "${framework}"
    fi

    after=$(stat -f %z "${binary}")
    echo "Stripped ${executable}: $((before - after)) bytes saved"
done
