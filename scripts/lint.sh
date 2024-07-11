eval "$($HOME/.local/bin/mise activate -C $SRCROOT bash --shims)"

if which swiftlint >/dev/null; then
  swiftlint --config "$SRCROOT/.swiftlint.yml" --path "$SRCROOT/"
else
  echo "warning: SwiftLint not installed, download from https://github.com/realm/SwiftLint"
fi
