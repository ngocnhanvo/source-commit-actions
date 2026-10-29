# Security

This repository is a privileged source-control automation plane.

- Never commit token values, passwords, cookies, private keys, or production credentials.
- Keep `SOURCE_REPO_PAT` only in GitHub Actions Secrets.
- Keep target repositories explicitly allowlisted in `config/targets.json`.
- Requests may never contain shell commands.
- Do not allow self-modification of `ngocnhanvo/source-commit-actions` through the bot.
- Keep `persist-credentials: false` for target checkout so validation/test code cannot read the source-write token from Git config.
- The token is exposed only to the final publish step.
- Use non-force pushes. A moved target branch must fail rather than overwrite newer work.
- Review any proposal to enable workflow changes or deletions for a target repository.
