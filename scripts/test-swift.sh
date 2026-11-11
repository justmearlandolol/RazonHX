#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
: "${RAZON_RUST_TARGET:?Set RAZON_RUST_TARGET to the native test architecture}"
case "$RAZON_RUST_TARGET" in
  x86_64-apple-darwin) triple=x86_64-apple-macosx10.13 ;;
  aarch64-apple-darwin) triple=arm64-apple-macosx11.0 ;;
  *) exit 1 ;;
esac
mkdir -p build/tests
for name in FoundationTests SettingsSmokeTests; do
  xcrun swiftc -swift-version 5 -parse-as-library -target "$triple" \
    -sdk "$(xcrun --sdk macosx --show-sdk-path)" \
    -import-objc-header Sources/Bridge/RazonHXBridge.h \
    Sources/Bridge/RazonHXBridge.swift Sources/Components/Views/NativeViews.swift \
    Sources/Interface/RazonSettings/SettingsWindowController.swift \
    "Tests/SwiftTests/$name.swift" \
    -L "razon-core/target/$RAZON_RUST_TARGET/release" -lrazon_core -liconv \
    -framework AppKit -framework Security -framework SystemConfiguration \
    -o "build/tests/$name"
  "build/tests/$name"
done
