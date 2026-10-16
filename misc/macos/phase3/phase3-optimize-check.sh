#!/usr/bin/env bash
# Phase 3 optimize prerequisite check.
# Verifies inputs for `nydus optimize` exist; does not run optimize unless
# MACOS_PHASE3_RUN_OPTIMIZE=1 and all artifacts + trace are present.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
NYDUS_BIN="${NYDUS_BIN:-$ROOT/target/release/nydus}"
ARTIFACT_DIR="${MACOS_ARTIFACT_DIR:-$ROOT/misc/macos/artifacts}"
PARENT_BOOT="${MACOS_PARENT_BOOTSTRAP:-$ARTIFACT_DIR/macos-disk.boot}"
OUT_BOOT="${MACOS_OPT_BOOTSTRAP:-$ARTIFACT_DIR/macos-disk.opt.boot}"
BLOB_DIR="${MACOS_BLOB_DIR:-$ARTIFACT_DIR}"
CONFIG="${MACOS_STORAGE_CONFIG:-$ROOT/misc/macos/config/storage.local.example.yaml}"
TRACE_FILE="${MACOS_TRACE_FILE:-$ARTIFACT_DIR/traces/boot-agent-ready.json}"
APISERVER="${MACOS_APISERVER:-}"

echo "== experiment/v3-macos Phase 3 optimize-check =="

fail=0
have_bin() { command -v "$1" >/dev/null 2>&1; }

if [[ -x "$NYDUS_BIN" ]]; then
  NYDUS="$NYDUS_BIN"
elif have_bin nydus; then
  NYDUS="$(command -v nydus)"
else
  echo "[fail] nydus not found"
  exit 1
fi
echo "[ok] nydus=$NYDUS"

if [[ -f "$PARENT_BOOT" ]]; then
  echo "[ok] parent bootstrap: $PARENT_BOOT"
else
  echo "[fail] missing parent bootstrap: $PARENT_BOOT"
  fail=1
fi

if [[ -f "$CONFIG" ]]; then
  echo "[ok] storage config: $CONFIG"
else
  echo "[fail] missing config: $CONFIG"
  fail=1
fi

trace_ok=0
if [[ -n "$APISERVER" ]]; then
  echo "[ok] will use live apiserver: $APISERVER"
  trace_ok=1
elif [[ -f "$TRACE_FILE" ]]; then
  echo "[ok] trace file: $TRACE_FILE"
  trace_ok=1
else
  echo "[fail] need MACOS_APISERVER or trace at $TRACE_FILE"
  echo "       capture GET /trace after a boot-to-ready on nydus fuse"
  fail=1
fi

mkdir -p "$BLOB_DIR" "$(dirname "$TRACE_FILE")" 2>/dev/null || true

if [[ "$fail" -ne 0 ]]; then
  echo "-- summary: FAIL (exit=1); see misc/macos/phase3/optimize-examples.sh"
  exit 1
fi

if [[ "${MACOS_PHASE3_RUN_OPTIMIZE:-0}" != "1" ]]; then
  echo "-- summary: prereq OK; dry-run only (set MACOS_PHASE3_RUN_OPTIMIZE=1 to execute)"
  echo "-- example:"
  if [[ -n "$APISERVER" ]]; then
    echo "   $NYDUS optimize --apiserver $APISERVER --parent-bootstrap $PARENT_BOOT --bootstrap $OUT_BOOT --blob-dir $BLOB_DIR --config $CONFIG"
  else
    echo "   $NYDUS optimize --trace-file $TRACE_FILE --parent-bootstrap $PARENT_BOOT --bootstrap $OUT_BOOT --blob-dir $BLOB_DIR --config $CONFIG"
  fi
  exit 0
fi

echo "-- running nydus optimize (MACOS_PHASE3_RUN_OPTIMIZE=1)"
if [[ -n "$APISERVER" ]]; then
  "$NYDUS" optimize \
    --apiserver "$APISERVER" \
    --parent-bootstrap "$PARENT_BOOT" \
    --bootstrap "$OUT_BOOT" \
    --blob-dir "$BLOB_DIR" \
    --config "$CONFIG"
else
  "$NYDUS" optimize \
    --trace-file "$TRACE_FILE" \
    --parent-bootstrap "$PARENT_BOOT" \
    --bootstrap "$OUT_BOOT" \
    --blob-dir "$BLOB_DIR" \
    --config "$CONFIG"
fi
echo "-- wrote $OUT_BOOT"
exit 0
