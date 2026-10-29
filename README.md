# Source Commit Actions

Central, auditable commit/push control-plane for repositories owned by `ngocnhanvo`.

This repository **does not deploy websites, upload FTP files, or run arbitrary shell from requests**. It only applies a reviewed text patch to an explicitly allowlisted target repository, validates the resulting diff, runs a fixed validation preset, then either commits directly to an allowlisted branch or opens a PR.

## Request lifecycle

Each request is an immutable directory:

```text
requests/<request-id>/
├── manifest.json
├── changes.patch
└── request.ready   # create this LAST
```

Only creation/change of `request.ready` triggers the workflow. This prevents a run from starting before the manifest and patch are complete.

The runner then:

1. validates the request against `config/targets.json`;
2. checks out the target repository with `SOURCE_REPO_PAT` and immediately removes persisted credentials;
3. requires target `HEAD == base_sha`;
4. runs `git apply --check`, applies the patch, and verifies the actual changed paths exactly match `allowed_paths`;
5. rejects unapproved deletions, workflow changes, symlink/submodule changes, binary patches, dirty pre-existing worktrees, and path traversal;
6. runs a fixed validation preset (`php`, `node`, `docs`, or `none`);
7. commits and pushes only after validation succeeds;
8. verifies the remote SHA. In `branch_pr` mode it also creates a PR.

## Required secret

Create one repository Actions secret:

- `SOURCE_REPO_PAT` — a token/GitHub App token with only the repository permissions needed to read/write target repos and create PRs when requested.

Do **not** store PAT values in request files, patches, logs, or config.

## Modes

- `direct_commit`: commit directly to the allowlisted target branch. A normal non-force push is used; if the branch moved after checkout, the push fails safely.
- `branch_pr`: create `source-commit/<request-id>`, push it, then open a PR against the target branch.

The request chooses a mode only from modes allowed for that repo+branch in `config/targets.json`.

## Validation presets

- `php`: `php -l` for every changed PHP file, plus optional manifest `test_files` executed with PHP.
- `node`: installs dependencies from the detected lockfile, then runs existing `check`, `lint`, and `test` package scripts in CI mode.
- `docs`: diff/path validation only; intended for documentation repositories.
- `none`: no language-specific test, but all structural/diff safety checks still run.

Requests cannot provide shell commands.

## Example manifest

See `templates/manifest.example.json`.

Important fields:

- `base_sha`: exact 40-character target HEAD expected before applying the patch.
- `allowed_paths`: exact set of paths the patch must change.
- `validation_preset`: must be allowed by target config.
- `test_files`: optional; for `php` they must be safe relative `.php` paths and are executed only after the patch has been applied.

## Adding another project

Edit only `config/targets.json`. Add the exact `owner/repo`, target branch, allowed modes, allowed validation presets, and whether deletes or workflow changes are permitted.

The central bot is intentionally **not** allowlisted to modify `ngocnhanvo/source-commit-actions` itself.

## Triggering manually

The workflow also supports `workflow_dispatch` with a request directory such as:

```text
requests/20261029-example
```

The directory must already contain `manifest.json`, `changes.patch`, and `request.ready`.

## Audit model

Request directories are retained in Git history. Do not rewrite or delete old requests just to rerun them; create a new request ID with a fresh `base_sha`.
