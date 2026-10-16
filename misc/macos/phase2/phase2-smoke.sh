#!/usr/bin/env bash
# Phase 2 host-ondemand smoke prerequisites.
# Does NOT start a VM, does NOT invent disk.raw, does NOT claim e2e success.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
NYDUS_BIN="${NYDUS_BIN:-$ROOT/target/release/nydus}"
MOUNTPOINT="${MACOS_NYDUS_MOUNTPOINT:-/run/nydus/macos-a}"
DISK_REL="${MACOS_DISK_RELATIVE_PATH:-disk.raw}"
DISK_PATH="${MACOS_DISK_PATH:-$MOUNTPOINT/$DISK_REL}"
BUILD_TREE="${MACOS_BUILD_TREE:-$ROOT/misc/macos/examples/build-tree.example}"
ARTIFACT_DIR="${MACOS_ARTIFACT_DIR:-$ROOT/misc/macos/artifacts}"
BLOB="${MACOS_BLOB:-$ARTIFACT_DIR/macos-disk.blob}"

echo "== experiment/v3-macos Phase 2 smoke (prereq only) =="
echo "ROOT=$ROOT"
echo "MOUNTPOINT=$MOUNTPOINT"
echo "DISK_PATH=$DISK_PATH"

fail=0
warn=0

have_bin() {
  command -v "$1" >/dev/null 2>&1
}

if [[ -x "$NYDUS_BIN" ]]; then
  echo "[ok] nydus binary: $NYDUS_BIN"
else
  if have_bin nydus; then
    echo "[ok] nydus on PATH: $(command -v nydus)"
  else
    echo "[fail] nydus binary not found at $NYDUS_BIN and not on PATH (run: make release)"
    fail=1
  fi
fi

if have_bin fusermount3 || have_bin fusermount; then
  echo "[ok] fusermount available"
else
  echo "[warn] fusermount not found — fuse backend will need fuse3 userland"
  warn=$((warn + 1))
fi

if [[ -e /dev/kvm ]]; then
  echo "[ok] /dev/kvm exists"
else
  echo "[warn] /dev/kvm missing — rund/QEMU smoke needs KVM on the lab host"
  warn=$((warn + 1))
fi

# Prefer an already-mounted tree; else look for a user-provided golden in the build tree.
disk_found=0
if [[ -e "$DISK_PATH" || -L "$DISK_PATH" ]]; then
  if [[ -r "$DISK_PATH" ]]; then
    echo "[ok] readable disk at DISK_PATH=$DISK_PATH"
    disk_found=1
  else
    echo "[fail] disk path exists but is not readable: $DISK_PATH"
    fail=1
    disk_found=1
  fi
fi

if [[ "$disk_found" -eq 0 ]]; then
  if [[ -e "$BUILD_TREE/disk.raw" || -L "$BUILD_TREE/disk.raw" ]]; then
    echo "[ok] build-tree disk.raw present (not yet mounted via nydus): $BUILD_TREE/disk.raw"
    disk_found=1
  fi
fi

if [[ "$disk_found" -eq 0 ]]; then
  echo "[fail] no disk.raw found"
  echo "       looked for:"
  echo "         - mounted path: $DISK_PATH"
  echo "         - build tree:   $BUILD_TREE/disk.raw"
  echo "       Provide a user-owned golden APFS raw (do not commit it)."
  echo "       See docs/experiment-v3-macos-phase2-host-ondemand.md"
  fail=1
fi

if [[ -f "$BLOB" ]]; then
  echo "[ok] blob artifact present: $BLOB"
else
  echo "[warn] blob not built yet: $BLOB (need golden disk + make macos-phase1-build)"
  warn=$((warn + 1))
fi

if [[ -d "$MOUNTPOINT" ]]; then
  echo "[ok] mountpoint dir exists: $MOUNTPOINT"
else
  echo "[warn] mountpoint dir missing: $MOUNTPOINT (create before nydus fuse)"
  warn=$((warn + 1))
fi

# Never invent images or start VMs here.
if [[ "$fail" -ne 0 ]]; then
  echo "-- summary: FAIL (exit=1) warnings=$warn"
  echo "-- Phase 2 e2e is blocked until golden disk.raw + rund/VMM wiring exist."
  exit 1
fi

echo "-- summary: prereq OK (exit=0) warnings=$warn"
echo "-- This script does not start rund/QEMU or claim cold-start success."
exit 0
