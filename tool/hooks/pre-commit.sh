#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(git rev-parse --show-toplevel)"
cd "$ROOT_DIR"

mapfile -t CHANGED_FILES < <(git diff --cached --name-only --diff-filter=ACM)
if [[ ${#CHANGED_FILES[@]} -eq 0 ]]; then
  exit 0
fi

mapfile -t DART_FILES < <(
  printf '%s\n' "${CHANGED_FILES[@]}" | grep -E '\.dart$' || true
)

if [[ ${#DART_FILES[@]} -gt 0 ]]; then
  echo "🛠  Formatting Dart files"
  dart format "${DART_FILES[@]}"
  git add "${DART_FILES[@]}"
fi

declare -A PACKAGE_DIRS=()
for file in "${DART_FILES[@]}"; do
  dir="$(dirname "$file")"
  package_root=""
  while [[ "$dir" != "." && "$dir" != "" ]]; do
    if [[ -f "$dir/pubspec.yaml" ]]; then
      package_root="$dir"
      break
    fi
    dir="$(dirname "$dir")"
  done
  if [[ -z "$package_root" && -f "pubspec.yaml" ]]; then
    package_root="."
  fi
  if [[ -n "$package_root" ]]; then
    PACKAGE_DIRS["$package_root"]=1
  fi
done

for pkg in "${!PACKAGE_DIRS[@]}"; do
  echo "🔍 dart analyze ($pkg)"
  (cd "$pkg" && dart analyze)
done

declare -A TEST_TARGETS=()
for file in "${DART_FILES[@]}"; do
  if [[ "$file" != *"_test.dart" ]]; then
    continue
  fi
  dir="$(dirname "$file")"
  package_root=""
  while [[ "$dir" != "." && "$dir" != "" ]]; do
    if [[ -f "$dir/pubspec.yaml" ]]; then
      package_root="$dir"
      break
    fi
    dir="$(dirname "$dir")"
  done
  if [[ -z "$package_root" && -f "pubspec.yaml" ]]; then
    package_root="."
  fi
  if [[ -n "$package_root" ]]; then
    relative="${file#$package_root/}"
    TEST_TARGETS["$package_root"]+=" $relative"
  fi
done

for pkg in "${!TEST_TARGETS[@]}"; do
  targets="${TEST_TARGETS[$pkg]}"
  if [[ -z "${targets// /}" ]]; then
    continue
  fi
  echo "🧪 running tests ($pkg ->$targets)"
  if grep -q "sdk: flutter" "$pkg/pubspec.yaml"; then
    (cd "$pkg" && flutter test $targets)
  else
    (cd "$pkg" && dart test $targets)
  fi
done
