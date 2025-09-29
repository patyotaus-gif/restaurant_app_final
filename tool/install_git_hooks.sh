#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(git rev-parse --show-toplevel)"
HOOKS_DIR="$ROOT_DIR/.git/hooks"
SCRIPT_DIR="$ROOT_DIR/tool/hooks"

mkdir -p "$HOOKS_DIR"
cp "$SCRIPT_DIR/pre-commit.sh" "$HOOKS_DIR/pre-commit"
chmod +x "$HOOKS_DIR/pre-commit"

echo "Installed pre-commit hook -> $HOOKS_DIR/pre-commit"
