#!/usr/bin/env bash
set -euo pipefail

CONTROL_ROOT="${1:?control root required}"
REQUEST_DIR="${2:?request dir required}"
MANIFEST="$CONTROL_ROOT/$REQUEST_DIR/manifest.json"
PATCH="$CONTROL_ROOT/$REQUEST_DIR/changes.patch"
READY="$CONTROL_ROOT/$REQUEST_DIR/request.ready"
TARGETS="$CONTROL_ROOT/config/targets.json"

fail(){ echo "::error::$*" >&2; exit 1; }

[[ "$REQUEST_DIR" =~ ^requests/[A-Za-z0-9._-]+$ ]] || fail "Invalid request directory"
[[ -f "$MANIFEST" && -f "$PATCH" && -f "$READY" ]] || fail "Request must contain manifest.json, changes.patch and request.ready"
[[ "$(tr -d '\r\n' < "$READY")" == "READY" ]] || fail "request.ready must contain READY"
[[ -s "$PATCH" ]] || fail "Patch is empty"
grep -Eq '^(GIT binary patch|Binary files )' "$PATCH" && fail "Binary patches are not allowed"

jq -e '.version == 1' "$MANIFEST" >/dev/null || fail "Unsupported manifest version"
target_repo="$(jq -r '.target_repo // empty' "$MANIFEST")"
target_branch="$(jq -r '.target_branch // empty' "$MANIFEST")"
base_sha="$(jq -r '.base_sha // empty' "$MANIFEST")"
mode="$(jq -r '.mode // empty' "$MANIFEST")"
commit_message="$(jq -r '.commit_message // empty' "$MANIFEST")"
preset="$(jq -r '.validation_preset // empty' "$MANIFEST")"

[[ "$target_repo" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || fail "Invalid target_repo"
[[ "$target_branch" =~ ^[A-Za-z0-9._/-]+$ && "$target_branch" != *".."* ]] || fail "Invalid target_branch"
[[ "$base_sha" =~ ^[0-9a-fA-F]{40}$ ]] || fail "base_sha must be a full 40-char SHA"
[[ "$mode" == "direct_commit" || "$mode" == "branch_pr" ]] || fail "Invalid mode"
[[ "$preset" =~ ^(php|node|docs|none)$ ]] || fail "Invalid validation_preset"
[[ -n "$commit_message" && ${#commit_message} -le 200 && "$commit_message" != *$'\n'* ]] || fail "Invalid commit_message"

jq -e '.allowed_paths | type=="array" and length>0 and length<=100 and all(.[]; type=="string")' "$MANIFEST" >/dev/null || fail "allowed_paths must contain 1..100 paths"
while IFS= read -r path; do
  [[ -n "$path" && "$path" != /* && "$path" != *".."* && "$path" != .git/* ]] || fail "Unsafe allowed path: $path"
done < <(jq -r '.allowed_paths[]' "$MANIFEST")

entry="$(jq -c --arg r "$target_repo" --arg b "$target_branch" '.targets[$r].branches[$b] // empty' "$TARGETS")"
[[ -n "$entry" ]] || fail "Target repo/branch is not allowlisted"
jq -e --arg r "$target_repo" --arg m "$mode" '.targets[$r].branches[$ENV.TARGET_BRANCH].modes // empty | index($m) != null'   --argjson dummy 0 "$TARGETS" >/dev/null 2>&1 || {
    jq -e --arg r "$target_repo" --arg b "$target_branch" --arg m "$mode" '.targets[$r].branches[$b].modes | index($m) != null' "$TARGETS" >/dev/null || fail "Mode not allowed"
  }
jq -e --arg r "$target_repo" --arg b "$target_branch" --arg p "$preset" '.targets[$r].branches[$b].validation_presets | index($p) != null' "$TARGETS" >/dev/null || fail "Validation preset not allowed"

allow_deletions="$(jq -r --arg r "$target_repo" '.targets[$r].allow_deletions // false' "$TARGETS")"
allow_workflows="$(jq -r --arg r "$target_repo" '.targets[$r].allow_workflows // false' "$TARGETS")"
request_id="$(basename "$REQUEST_DIR")"
branch_name="source-commit/$request_id"

{
  echo "target_repo=$target_repo"
  echo "target_branch=$target_branch"
  echo "base_sha=$base_sha"
  echo "mode=$mode"
  echo "commit_message=$commit_message"
  echo "validation_preset=$preset"
  echo "allow_deletions=$allow_deletions"
  echo "allow_workflows=$allow_workflows"
  echo "request_id=$request_id"
  echo "branch_name=$branch_name"
  echo "manifest=$MANIFEST"
  echo "patch=$PATCH"
} >> "$GITHUB_OUTPUT"
