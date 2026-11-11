#!/bin/bash
set -euo pipefail
export PATH="$HOME/.cargo/bin:$PATH"
: "${SRCROOT:=$(cd "$(dirname "$0")/.." && pwd)}"
: "${RAZON_RUST_TARGET:?Xcode must provide RAZON_RUST_TARGET}"
case "$RAZON_RUST_TARGET" in
  x86_64-apple-darwin) export MACOSX_DEPLOYMENT_TARGET=10.13 ;;
  aarch64-apple-darwin) export MACOSX_DEPLOYMENT_TARGET=11.0 ;;
  *) echo "Unsupported Rust target: $RAZON_RUST_TARGET" >&2; exit 1 ;;
esac
export CARGO_TARGET_DIR="$SRCROOT/razon-core/target"
cargo build --locked --manifest-path "$SRCROOT/razon-core/Cargo.toml" --release --target "$RAZON_RUST_TARGET"
