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

# Make newly added files visible to git diff without staging their contents.
# This keeps allowed_paths, workflow/symlink checks and git diff --check exact
# for patches that create files; publish.sh still performs the real git add.
git add -N -- .

mapfile -t actual < <(git diff --name-only | sort)
mapfile -t expected < <(jq -r '.allowed_paths[]' "$MANIFEST" | sort -u)
[[ "${#actual[@]}" -gt 0 ]] || fail "Patch produced no diff"

if ! diff -u <(printf '%s\n' "${expected[@]}") <(printf '%s\n' "${actual[@]}"); then
  fail "Actual changed paths do not exactly match allowed_paths"
fi

if [[ "$ALLOW_DELETIONS" != "true" ]] && [[ -n "$(git diff --name-only --diff-filter=D)" ]]; then
  fail "File deletions are not allowed for this target"
fi

workflow_changed=false
for p in "${actual[@]}"; do
  if [[ "$p" == .github/workflows/* ]]; then
    workflow_changed=true
    [[ "$ALLOW_WORKFLOWS" == "true" ]] || fail "Workflow changes are not allowed for this target"
  fi
done
if [[ "$workflow_changed" == "true" && "$PRESET" != "actions" ]]; then
  fail "Workflow changes require validation_preset=actions"
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
      if jq -e '.scripts.check' package.json >/dev/null; then CI=1 pnpm run check; fi
      if jq -e '.scripts.lint' package.json >/dev/null; then CI=1 pnpm run lint; fi
      if jq -e '.scripts.test' package.json >/dev/null; then CI=1 pnpm test; fi
    elif [[ -f package-lock.json ]]; then
      npm ci
      if jq -e '.scripts.check' package.json >/dev/null; then CI=1 npm run check; fi
      if jq -e '.scripts.lint' package.json >/dev/null; then CI=1 npm run lint; fi
      if jq -e '.scripts.test' package.json >/dev/null; then CI=1 npm test; fi
    else
      fail "Supported lockfile not found"
    fi
    ;;
  actions)
    command -v ruby >/dev/null || fail "ruby is unavailable for workflow YAML syntax checks"
    for p in "${actual[@]}"; do
      if [[ "$p" == *.sh || "$p" == *.bash ]]; then
        bash -n "$p"
      elif [[ "$p" == *.json ]]; then
        jq -e . "$p" >/dev/null
      elif [[ "$p" == .github/workflows/*.yml || "$p" == .github/workflows/*.yaml ]]; then
        ruby -e 'require "yaml"; YAML.load_file(ARGV.fetch(0), aliases: true)' "$p" >/dev/null
      elif [[ "$p" == *.py ]]; then
        python3 -m py_compile "$p"
      fi
    done
    ;;
  docs|none) ;;
  *) fail "Unknown preset: $PRESET" ;;
esac
