#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"
mkdir -p build/module-cache
export CLANG_MODULE_CACHE_PATH="$ROOT/build/module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$ROOT/build/module-cache"
swiftc Sources/Calabel/AgendaLogic.swift Sources/Calabel/AppLanguage.swift Sources/Calabel/CalendarPreferences.swift Sources/Calabel/EventURLBuilder.swift \
  Tests/CalabelTests/main.swift \
  -parse-as-library \
  -o build/calabel-logic-checks
build/calabel-logic-checks
