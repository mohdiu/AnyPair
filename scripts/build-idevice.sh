#!/usr/bin/env bash
# Builds libidevice_ffi.a for iOS (arm64) from upstream idevice at a pinned commit,
# with patches/idevice-random-identity.patch applied. Needs a Mac with Xcode + Rust.
set -euo pipefail

IDEVICE_REPO="https://github.com/jkcoxson/idevice.git"
IDEVICE_COMMIT="26a28f6a46b5d85a28043c2e62febfa394c8b0a6"

root="$(cd "$(dirname "$0")/.." && pwd)"
src="$root/.idevice-src"

if [ ! -d "$src/.git" ]; then
  git init -q "$src"
  git -C "$src" remote add origin "$IDEVICE_REPO"
fi
git -C "$src" fetch -q --depth 1 origin "$IDEVICE_COMMIT"
git -C "$src" checkout -q -f "$IDEVICE_COMMIT"
git -C "$src" clean -qfdx -e target
git -C "$src" apply "$root/patches/idevice-random-identity.patch"

rustup target add aarch64-apple-ios
cd "$src/ffi"
BINDGEN_EXTRA_CLANG_ARGS="--sysroot=$(xcrun --sdk iphoneos --show-sdk-path)" \
IPHONEOS_DEPLOYMENT_TARGET=18.0 \
  cargo build --release --target aarch64-apple-ios --no-default-features --features remote_pairing,ring

cp "$src/target/aarch64-apple-ios/release/libidevice_ffi.a" "$root/Vendor/idevice/"
cp "$src/ffi/idevice.h" "$root/Vendor/idevice/"
grep -q pairable_host_prepare_custom "$root/Vendor/idevice/idevice.h"
echo "Built Vendor/idevice/libidevice_ffi.a"
