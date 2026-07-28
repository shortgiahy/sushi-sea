#!/usr/bin/env bash
# docs/PRD.md is a read-only mirror of the canonical PRD in the MIMIR vault.
# Run with --check to detect drift (CI-friendly), no args to pull the vault copy in.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VAULT_PRD="${MIMIR_VAULT:-$(dirname "$REPO_ROOT")/MIMIR}/Projects/Sushi Sea/PRD.md"
REPO_PRD="$REPO_ROOT/docs/PRD.md"

if [[ ! -f "$VAULT_PRD" ]]; then
  echo "vault PRD not found at: $VAULT_PRD" >&2
  echo "clone the MIMIR vault beside this repo, or set MIMIR_VAULT" >&2
  exit 2
fi

if [[ "${1:-}" == "--check" ]]; then
  if diff -q "$VAULT_PRD" "$REPO_PRD" >/dev/null; then
    echo "PRD in sync"
  else
    echo "PRD drift — run scripts/sync-prd.sh" >&2
    diff "$REPO_PRD" "$VAULT_PRD" >&2 || true
    exit 1
  fi
else
  cp "$VAULT_PRD" "$REPO_PRD"
  echo "synced docs/PRD.md from vault"
fi
