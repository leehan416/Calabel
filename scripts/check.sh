#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"
mkdir -p build/module-cache
export CLANG_MODULE_CACHE_PATH="$ROOT/build/module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$ROOT/build/module-cache"
exec swift build --disable-sandbox --cache-path build/swiftpm-cache -c debug \
  --product Calabel --build-path build/swift-build
