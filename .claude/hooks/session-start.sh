#!/bin/bash
# Installs the Roblox toolchain in Claude Code cloud sessions so Claude can
# build the place file (rojo), type-check (luau-lsp), format (stylua) and
# run unit tests (lune). Idempotent: anything already installed is skipped.
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

export PATH="$HOME/.cargo/bin:$PATH"
BIN="$HOME/.cargo/bin"
mkdir -p "$BIN"

need() { ! command -v "$1" >/dev/null 2>&1; }

if need cargo; then
  echo "cargo not found; cannot install Roblox tools" >&2
  exit 0
fi

need rojo && cargo install rojo --version 7.7.1 --locked
need stylua && cargo install stylua --locked
need lune && cargo install lune --version 0.11.0 --locked

if need luau-lsp; then
  SRC="$(mktemp -d)"
  git clone --depth 1 --branch 1.70.1 --recurse-submodules --shallow-submodules \
    https://github.com/JohnnyMorganz/luau-lsp.git "$SRC/luau-lsp"
  # GCC 13 trips -Werror on a maybe-uninitialized warning in upstream code.
  sed -i 's/-Werror//g' "$SRC/luau-lsp/CMakeLists.txt"
  cmake -S "$SRC/luau-lsp" -B "$SRC/luau-lsp/build" -G Ninja -DCMAKE_BUILD_TYPE=Release >/dev/null
  cmake --build "$SRC/luau-lsp/build" --target Luau.LanguageServer.CLI -j"$(nproc)"
  cp "$SRC/luau-lsp/build/luau-lsp" "$BIN/luau-lsp"
  rm -rf "$SRC"
fi

if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  echo "export PATH=\"$BIN:\$PATH\"" >> "$CLAUDE_ENV_FILE"
fi
echo "Roblox tools ready: $(rojo --version), $(luau-lsp --version), $(stylua --version), $(lune --version)"
