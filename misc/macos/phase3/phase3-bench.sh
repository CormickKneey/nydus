#!/usr/bin/env bash
# Phase 3 cold-start benchmark stub.
# Refuses to invent timings without golden disk / blob / (optional) mount.
# Does NOT start rund/QEMU and does NOT claim speedup.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
NYDUS_BIN="${NYDUS_BIN:-$ROOT/target/release/nydus}"
ARTIFACT_DIR="${MACOS_ARTIFACT_DIR:-$ROOT/misc/macos/artifacts}"
BUILD_TREE="${MACOS_BUILD_TREE:-$ROOT/misc/macos/examples/build-tree.example}"
BLOB="${MACOS_BLOB:-$ARTIFACT_DIR/macos-disk.blob}"
BOOTSTRAP="${MACOS_BOOTSTRAP:-$ARTIFACT_DIR/macos-disk.boot}"
MOUNTPOINT="${MACOS_NYDUS_MOUNTPOINT:-/run/nydus/macos-a}"
DISK_REL="${MACOS_DISK_RELATIVE_PATH:-disk.raw}"
DISK_PATH="${MACOS_DISK_PATH:-$MOUNTPOINT/$DISK_REL}"
RESULTS_OUT="${MACOS_PHASE3_RESULTS:-$ARTIFACT_DIR/phase3-results.md}"

echo "== experiment/v3-macos Phase 3 bench (prereq only) =="
echo "ROOT=$ROOT"
echo "BLOB=$BLOB BOOTSTRAP=$BOOTSTRAP"
echo "DISK_PATH=$DISK_PATH"

fail=0
warn=0

have_bin() { command -v "$1" >/dev/null 2>&1; }

if [[ -x "$NYDUS_BIN" ]] || have_bin nydus; then
  echo "[ok] nydus available"
else
  echo "[fail] nydus binary missing (run: make release)"
  fail=1
fi

disk_ok=0
if [[ -e "$DISK_PATH" || -L "$DISK_PATH" ]]; then
  if [[ -r "$DISK_PATH" ]]; then
    echo "[ok] readable mounted/path disk: $DISK_PATH"
    disk_ok=1
  else
    echo "[fail] disk exists but not readable: $DISK_PATH"
    fail=1
    disk_ok=1
  fi
elif [[ -e "$BUILD_TREE/disk.raw" || -L "$BUILD_TREE/disk.raw" ]]; then
  echo "[ok] build-tree disk.raw present: $BUILD_TREE/disk.raw"
  disk_ok=1
fi

if [[ "$disk_ok" -eq 0 ]]; then
  echo "[fail] no disk.raw — cannot run cold-start comparison"
  echo "       provide golden APFS raw (do not commit); see docs/experiment-v3-macos-phase3-coldstart.md"
  fail=1
fi

if [[ -f "$BLOB" ]]; then
  echo "[ok] blob: $BLOB"
else
  echo "[fail] missing blob $BLOB (make macos-phase1-build)"
  fail=1
fi

if [[ -f "$BOOTSTRAP" ]]; then
  echo "[ok] bootstrap: $BOOTSTRAP"
else
  echo "[warn] bootstrap not at $BOOTSTRAP — set MACOS_BOOTSTRAP if named differently"
  warn=$((warn + 1))
fi

if [[ -e /dev/kvm ]]; then
  echo "[ok] /dev/kvm exists"
else
  echo "[warn] /dev/kvm missing — T_runtime/T_ready need KVM lab host"
  warn=$((warn + 1))
fi

if [[ "$fail" -ne 0 ]]; then
  echo "-- summary: FAIL (exit=1) warnings=$warn"
  echo "-- refusing to fabricate T_pull/T_runtime/T_ready numbers"
  echo "-- template only: misc/macos/phase3/results.example.md"
  exit 1
fi

echo "-- summary: prereq OK (exit=0) warnings=$warn"
echo "-- Next (manual): run B0/B1/B2/B3 per docs/experiment-v3-macos-phase3-coldstart.md §5"
echo "-- Fill results into: $RESULTS_OUT (copy from results.example.md)"
echo "-- This stub does not start VMs or write benchmark numbers."
exit 0
