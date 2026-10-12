#!/bin/bash
# Every check that runs without Roblox: type check, formatting, unit tests,
# and a place build. Run from anywhere: scripts/check.sh
set -euo pipefail
cd "$(dirname "$0")/.."

echo "== Type check (luau-lsp, strict, Roblox API types)"
rojo sourcemap default.project.json -o sourcemap.json >/dev/null
out="$(luau-lsp analyze --sourcemap=sourcemap.json --definitions=types/globalTypes.d.luau --platform=roblox src 2>&1 \
  | grep -v -E '^\[INFO\]|didChangeWatchedFiles' || true)"
if [ -n "$out" ]; then
  echo "$out"
  exit 1
fi
echo "ok"

echo "== Formatting (stylua)"
stylua --check src tests
echo "ok"

echo "== Unit tests (lune)"
lune run tests/unit/run.luau

echo "== Build place file (rojo)"
rojo build default.project.json -o build/StealASlime.rbxlx
