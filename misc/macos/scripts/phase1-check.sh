#!/usr/bin/env bash
# Phase 1 toolchain / layout check. Does NOT download IPSW or claim e2e.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
BUILD_TREE="${MACOS_BUILD_TREE:-$ROOT/misc/macos/examples/build-tree.example}"
ARTIFACT_DIR="${MACOS_ARTIFACT_DIR:-$ROOT/misc/macos/artifacts}"
NYDUS_BIN="${NYDUS_BIN:-$ROOT/target/release/nydus}"

echo "== experiment/v3-macos Phase 1 check =="
echo "ROOT=$ROOT"

ok=0
warn=0

if [[ -x "$NYDUS_BIN" ]]; then
  echo "[ok] nydus binary: $NYDUS_BIN"
  "$NYDUS_BIN" --help >/dev/null 2>&1 || true
else
  echo "[warn] nydus not built at $NYDUS_BIN (run: make release)"
  warn=$((warn + 1))
fi

if [[ -d "$BUILD_TREE" ]]; then
  echo "[ok] build tree dir: $BUILD_TREE"
else
  echo "[fail] missing build tree: $BUILD_TREE"
  ok=1
fi

if [[ -e "$BUILD_TREE/disk.raw" || -L "$BUILD_TREE/disk.raw" ]]; then
  if [[ -f "$BUILD_TREE/disk.raw" || -L "$BUILD_TREE/disk.raw" ]]; then
    echo "[ok] disk.raw present (user-provided)"
  fi
else
  echo "[warn] no disk.raw in build tree — expected until a golden image is supplied"
  warn=$((warn + 1))
fi

mkdir -p "$ARTIFACT_DIR"
echo "[ok] artifact dir: $ARTIFACT_DIR"

if [[ ! -e /dev/kvm ]]; then
  echo "[warn] /dev/kvm missing — Phase 2 VMM smoke will need KVM"
  warn=$((warn + 1))
else
  echo "[ok] /dev/kvm exists"
fi

echo "-- summary: exit=$ok warnings=$warn (warnings are OK for Phase 1 scaffolding)"
exit "$ok"
