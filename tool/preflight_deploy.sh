#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

info() {
  echo -e "\033[1;34m==>\033[0m $*"
}

warn() {
  echo -e "\033[1;33m==>\033[0m $*"
}

info "Running deployment preflight checks"

# Flutter specific checks
if command -v flutter >/dev/null 2>&1; then
  info "\nChecking Flutter format/analyze/test"
  (cd "$ROOT_DIR" && flutter format --set-exit-if-changed lib test)
  (cd "$ROOT_DIR" && flutter analyze)
  (cd "$ROOT_DIR" && flutter test)
else
  warn "Flutter not available - skipping Flutter formatting/analyze/test"
fi

# Melos workspace sanity
if command -v melos >/dev/null 2>&1; then
  info "\nValidating Melos workspace"
  (cd "$ROOT_DIR" && melos bootstrap)
  (cd "$ROOT_DIR" && melos run analyze)
  (cd "$ROOT_DIR" && melos run test)
else
  warn "Melos not installed - skipping workspace checks"
fi

# Cloud Functions lint + tests
if command -v npm >/dev/null 2>&1; then
  info "\nRunning Cloud Functions lint"
  if [ ! -d "$ROOT_DIR/functions/node_modules" ]; then
    (cd "$ROOT_DIR/functions" && npm install)
  fi
  (cd "$ROOT_DIR/functions" && npm run lint)
  info "\nExecuting Cloud Functions tests"
  (cd "$ROOT_DIR/functions" && npm test)
else
  warn "npm not available - skipping Cloud Functions lint/test"
fi

info "\nAll preflight checks passed"
