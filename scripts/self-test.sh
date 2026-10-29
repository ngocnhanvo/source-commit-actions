#!/usr/bin/env bash
set -euo pipefail

fail(){ echo "::error::$*" >&2; exit 1; }

for script in scripts/*.sh; do
  bash -n "$script"
done

jq -e '.version == 1 and (.targets | type=="object" and length>0)' config/targets.json >/dev/null
jq -e '.version == 1 and (.target_repo|type=="string") and (.allowed_paths|type=="array")' templates/manifest.example.json >/dev/null

jq -e '.targets["ngocnhanvo/source-commit-actions"] == null' config/targets.json >/dev/null   || fail "The control repository must never self-modify through the bot"

while IFS= read -r repo; do
  [[ "$repo" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || fail "Invalid allowlisted repo: $repo"
done < <(jq -r '.targets | keys[]' config/targets.json)

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/control/config" "$tmp/control/requests/self-test" "$tmp/target"
cp config/targets.json "$tmp/control/config/targets.json"

cat > "$tmp/control/requests/self-test/manifest.json" <<'JSON'
{
  "version": 1,
  "target_repo": "ngocnhanvo/psevn-php",
  "target_branch": "master",
  "base_sha": "0123456789abcdef0123456789abcdef01234567",
  "mode": "direct_commit",
  "commit_message": "test: self-test request validation",
  "validation_preset": "php",
  "allowed_paths": ["sample.txt"]
}
JSON
cat > "$tmp/control/requests/self-test/changes.patch" <<'PATCH'
diff --git a/sample.txt b/sample.txt
--- a/sample.txt
+++ b/sample.txt
@@ -1 +1 @@
-old
+new
PATCH
printf 'READY\n' > "$tmp/control/requests/self-test/request.ready"

GITHUB_OUTPUT="$tmp/output" bash scripts/validate-request.sh "$tmp/control" "$tmp/control/requests/self-test" "self-test"
grep -q '^target_repo=ngocnhanvo/psevn-php$' "$tmp/output"
grep -q '^mode=direct_commit$' "$tmp/output"

git -C "$tmp/target" init -q
git -C "$tmp/target" config user.name self-test
git -C "$tmp/target" config user.email self-test@example.invalid
printf 'old\n' > "$tmp/target/sample.txt"
git -C "$tmp/target" add sample.txt
git -C "$tmp/target" commit -qm init

bash scripts/apply-and-test.sh   "$tmp/target"   "$tmp/control/requests/self-test/manifest.json"   "$tmp/control/requests/self-test/changes.patch"   none false false

[[ "$(cat "$tmp/target/sample.txt")" == "new" ]] || fail "Patch application self-test failed"

echo "SOURCE_COMMIT_SELF_TEST=PASS"
