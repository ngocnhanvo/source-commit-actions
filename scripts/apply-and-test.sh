#!/usr/bin/env bash
set -euo pipefail

TARGET_ROOT="${1:?target root required}"
MANIFEST="${2:?manifest required}"
PATCH="${3:?patch required}"
PRESET="${4:?preset required}"
ALLOW_DELETIONS="${5:-false}"
ALLOW_WORKFLOWS="${6:-false}"

fail(){ echo "::error::$*" >&2; exit 1; }
cd "$TARGET_ROOT"
[[ -z "$(git status --porcelain)" ]] || fail "Target worktree is not clean"

git apply --check "$PATCH"
git apply "$PATCH"

mapfile -t actual < <(git diff --name-only | sort)
mapfile -t expected < <(jq -r '.allowed_paths[]' "$MANIFEST" | sort -u)
[[ "${#actual[@]}" -gt 0 ]] || fail "Patch produced no diff"

if ! diff -u <(printf '%s\n' "${expected[@]}") <(printf '%s\n' "${actual[@]}"); then
  fail "Actual changed paths do not exactly match allowed_paths"
fi

if [[ "$ALLOW_DELETIONS" != "true" ]] && [[ -n "$(git diff --name-only --diff-filter=D)" ]]; then
  fail "File deletions are not allowed for this target"
fi

if [[ "$ALLOW_WORKFLOWS" != "true" ]]; then
  for p in "${actual[@]}"; do
    [[ "$p" != .github/workflows/* ]] || fail "Workflow changes are not allowed for this target"
  done
fi

if git diff --raw | grep -Eq '(^| )120000|(^| )160000'; then
  fail "Symlink/submodule changes are not allowed"
fi

git diff --check

case "$PRESET" in
  php)
    command -v php >/dev/null || fail "php CLI is unavailable"
    for p in "${actual[@]}"; do
      [[ "$p" == *.php ]] || continue
      [[ -f "$p" ]] || continue
      php -l "$p"
    done
    if jq -e '.test_files? | type=="array"' "$MANIFEST" >/dev/null 2>&1; then
      count="$(jq '.test_files | length' "$MANIFEST")"
      (( count <= 20 )) || fail "Too many test_files"
      while IFS= read -r t; do
        [[ "$t" == *.php && "$t" != /* && "$t" != *".."* && -f "$t" ]] || fail "Unsafe/missing PHP test: $t"
        php "$t"
      done < <(jq -r '.test_files[]' "$MANIFEST")
    fi
    ;;
  node)
    command -v node >/dev/null || fail "node is unavailable"
    [[ -f package.json ]] || fail "package.json not found"
    if [[ -f pnpm-lock.yaml ]]; then
      corepack enable
      pnpm install --frozen-lockfile
      jq -e '.scripts.check' package.json >/dev/null && CI=1 pnpm run check || true
      jq -e '.scripts.lint' package.json >/dev/null && CI=1 pnpm run lint || true
      jq -e '.scripts.test' package.json >/dev/null && CI=1 pnpm test || true
    elif [[ -f package-lock.json ]]; then
      npm ci
      jq -e '.scripts.check' package.json >/dev/null && CI=1 npm run check || true
      jq -e '.scripts.lint' package.json >/dev/null && CI=1 npm run lint || true
      jq -e '.scripts.test' package.json >/dev/null && CI=1 npm test || true
    else
      fail "Supported lockfile not found"
    fi
    ;;
  docs|none) ;;
  *) fail "Unknown preset: $PRESET" ;;
esac
