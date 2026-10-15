# Contract: CI checks installed into target projects

All workflows are templates under `extensions/ov/templates/`, copied by `ov-pr.sh` or
`ov-nogo.sh`. Every workflow uses `pull_request_target` and never executes PR code. Workflows
that need repository files check out the **base** branch, fetch the PR head without executing
it, and read `.aiignore` and the ov scripts from the base branch (research R-6).

## `ov-aiignore`: `.github/workflows/ov-aiignore.yml` (installed by `/speckit-ov-nogo`)

- **Job / status check name**: `ov-aiignore` (referenced by the ruleset).
- **Trigger**: `pull_request_target: [opened, synchronize, reopened, edited]` on any base
  branch, for **all PRs, forks included** (FR-031). The head is fetched as
  `refs/pull/<n>/head`, so fork commits are reachable without the fork's remote.
- **Permissions**: `contents: read`.
- **Algorithm**: `ov-ci-aiignore.sh <base_sha> <head_sha>`. For each commit in
  `base..head`:
  1. agent? (data-model "Agent commit": trailer only, branch names play no role);
  2. if agent, every path in `git diff-tree --no-renames -r --name-only <c>` is matched
     against base `.aiignore`. For merge commits, which plain `diff-tree` leaves empty,
     `git diff-tree --cc --name-only <c>` is used.
- **Result**: exit 1 listing `<sha> <path>` per violation; exit 0 otherwise. No base
  `.aiignore` → pass with a notice.
- **Tests**: a fixture repo with commits {trailer `Co-Authored-By: Claude <…>`, lowercase
  trailer, `Assisted-by: claude-code`, human} × {listed, unlisted} paths, plus:
  - a trailer-less commit on a branch named `ai/demo` (passes);
  - a rename out of a listed path;
  - a PR that edits `.aiignore` itself;
  - an agent merge commit;
  - a fork-shaped PR whose head is only reachable as `refs/pull/<n>/head`.

## `ov-ai-review`: `.github/workflows/ov-ai-review.yml` (installed by `/speckit-ov-pr` when `ai_review: on`)

- **Job / status check name**: `ov-ai-review`.
- **Trigger**: `pull_request_target: [opened, synchronize, reopened]`, all PRs.
- **Forks (first step)**: if `head.repo.full_name != github.repository`, write
  `ov-ai-review: fork PR, AI review skipped` to the job summary and exit 0 (pass-with-skip,
  FR-058). The secret is never read and the model never runs on fork content.
- **Secret (second step, same-repo PRs only)**: `ANTHROPIC_API_KEY`. Missing → the step fails with
  `ov-ai-review: repository secret ANTHROPIC_API_KEY is not set (set it or run /speckit-ov-pr and choose ai_review: off)` (FR-056).
- **Algorithm**:
  1. map changed files to modules via each `docs/srs/modules/*.md` `Paths:` line (R-4
     matcher, FR-057);
  2. run `claude -p` with `--output-format json` and read-only tools, giving it the diff and
     the matched module specs (shared SRS sections only if none match);
  3. require a final line `OV-REVIEW: PASS` or `OV-REVIEW: FAIL`.
- **Result**: PASS → exit 0; FAIL or missing verdict → exit 1. Findings go to the job summary.

## `ov-automerge`: `.github/workflows/ov-automerge.yml` (installed by `/speckit-ov-pr` when `auto_merge: on`)

- **Trigger**: `pull_request_target: [opened, reopened, ready_for_review]`, all PRs.
- **Forks**: the job runs only if `head.repo.full_name == github.repository`. Fork PRs are
  never auto-merged (FR-054).
- **Permissions**: `contents: write`, `pull-requests: write`.
- **Action**: `gh pr merge --auto --squash <number>` (FR-054). No checkout is needed. Merging
  still waits on the ruleset's required checks.

## Ruleset template: `.github/ov-ruleset-main.json` (written by `/speckit-ov-pr`)

GitHub ruleset JSON (import via repo Settings → Rules → Rulesets → Import), `target: branch`,
`conditions.ref_name.include: ["refs/heads/main"]`, `enforcement: active`:
- `pull_request` rule with `required_approving_review_count: 0` (this also blocks direct pushes);
- `non_fast_forward` (blocks force pushes) and `deletion`;
- `required_status_checks`: `ov-aiignore`, plus `ov-ai-review` only when `ai_review: on`
  (FR-055).

## No git hooks

ov installs no git hooks. The `branch` authorship mode, its commit-msg hook and the agent
branch prefix were removed on 2026-10-15 (FR-053). Authorship is recorded by Claude Code's `attribution` setting and
classified in CI (FR-031, FR-034).
