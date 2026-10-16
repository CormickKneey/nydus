#!/usr/bin/env bash
# Sample `nydus optimize` command lines for experiment/v3-macos (model A).
# This file is documentation-as-shell: it prints examples and exits 0.
# It does not contact the network or read a guest disk.
set -euo pipefail

cat <<'EXAMPLES'
# === experiment/v3-macos Phase 3: sample optimize commands ===
# Flags follow docs/nydus.md (Optimize). Adjust paths to your lab layout.

# --- A) Live trace from a running nydus fuse mount ---
# 1) Start fuse with apiserver, then boot rund/QEMU to agent-ready.
# 2) Optimize in place (mount still up):
nydus optimize \
  --apiserver unix:///run/nydus/macos-a.sock \
  --parent-bootstrap /var/lib/nydus-macos/artifacts/macos-disk.boot \
  --bootstrap /var/lib/nydus-macos/artifacts/macos-disk.opt.boot \
  --blob-dir /var/lib/nydus-macos/artifacts \
  --config /etc/nydus/macos-storage.yaml

# --- B) Offline trace file (same JSON as GET /trace) ---
# Save patterns after boot, then optimize on a build host:
#   {"version":1,"patterns":[{"blob_index":1,"chunk_group_index":0}, ...]}
nydus optimize \
  --trace-file /var/lib/nydus-macos/traces/boot-agent-ready.json \
  --parent-bootstrap /var/lib/nydus-macos/artifacts/macos-disk.boot \
  --bootstrap /var/lib/nydus-macos/artifacts/macos-disk.opt.boot \
  --blob-dir /var/lib/nydus-macos/artifacts \
  --config /etc/nydus/macos-storage.yaml

# --- C) Repo-local placeholders (after make macos-phase1-build) ---
nydus optimize \
  --trace-file misc/macos/artifacts/traces/boot-agent-ready.json \
  --parent-bootstrap misc/macos/artifacts/macos-disk.boot \
  --bootstrap misc/macos/artifacts/macos-disk.opt.boot \
  --blob-dir misc/macos/artifacts \
  --config misc/macos/config/storage.local.example.yaml

# Notes:
# - --apiserver and --trace-file are mutually exclusive; one is required.
# - Do not feed an ondemand blob as a source for another optimize.
# - Guest APFS paths are NOT valid optimize input; use host chunk-group trace.
# - See docs/experiment-v3-macos-phase3-coldstart.md
EXAMPLES
