#!/usr/bin/env bash
set -euo pipefail

TARGET_ROOT="${1:?target root required}"
TARGET_REPO="${2:?target repo required}"
TARGET_BRANCH="${3:?target branch required}"
MODE="${4:?mode required}"
BRANCH_NAME="${5:?branch name required}"
COMMIT_MESSAGE="${6:?commit message required}"

fail(){ echo "::error::$*" >&2; exit 1; }
: "${GH_TOKEN:?GH_TOKEN is required}"

cd "$TARGET_ROOT"
git config user.name "source-commit-actions[bot]"
git config user.email "source-commit-actions[bot]@users.noreply.github.com"

if [[ "$MODE" == "branch_pr" ]]; then
  git switch -c "$BRANCH_NAME"
fi

git add --all
git diff --cached --quiet && fail "Nothing to commit"
git commit -m "$COMMIT_MESSAGE"
new_sha="$(git rev-parse HEAD)"

gh auth setup-git
if [[ "$MODE" == "direct_commit" ]]; then
  git push origin "HEAD:$TARGET_BRANCH"
  remote_sha="$(git ls-remote origin "refs/heads/$TARGET_BRANCH" | awk '{print $1}')"
  [[ "$remote_sha" == "$new_sha" ]] || fail "Remote SHA verification failed"
  echo "new_sha=$new_sha" >> "$GITHUB_OUTPUT"
  echo "result_url=https://github.com/$TARGET_REPO/commit/$new_sha" >> "$GITHUB_OUTPUT"
else
  git push origin "HEAD:$BRANCH_NAME"
  remote_sha="$(git ls-remote origin "refs/heads/$BRANCH_NAME" | awk '{print $1}')"
  [[ "$remote_sha" == "$new_sha" ]] || fail "Remote branch SHA verification failed"
  pr_body="Automated source commit request.

Request branch: \`$BRANCH_NAME\`
Commit: \`$new_sha\`"
  pr_json="$(gh api --method POST "repos/$TARGET_REPO/pulls" \
    -f title="$COMMIT_MESSAGE" \
    -f head="$BRANCH_NAME" \
    -f base="$TARGET_BRANCH" \
    -f body="$pr_body")"
  pr_url="$(printf '%s' "$pr_json" | jq -r '.html_url // empty')"
  [[ "$pr_url" == https://github.com/* ]] || fail "Pull request creation returned no GitHub URL"
  echo "new_sha=$new_sha" >> "$GITHUB_OUTPUT"
  echo "result_url=$pr_url" >> "$GITHUB_OUTPUT"
fi
