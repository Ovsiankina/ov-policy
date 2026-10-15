# Quickstart: validate ov end-to-end

**Feature**: [spec.md](./spec.md) | Contracts: [contracts/](./contracts/)

Covers the spec's acceptance criteria (SC-001–SC-004) plus the per-story checks. `$OV` is this
repo's checkout.

## Prerequisites

- `specify` ≥ 1.2.0, git, `jq`, Claude Code; `gh` + a GitHub test repo for the CI steps.
- `POLICY.md` exists with first line `<!-- ov-policy -->`, and `scripts/ov-sync-policy.sh` has
  been run. Until the author writes it, use the marker-only placeholder copy.

## 1. Install (SC-001, SC-002, Story 1)

```bash
specify init scratch --integration claude
cd scratch
specify extension add "$OV/extensions/ov" --dev
specify preset add --dev "$OV/presets/ov-policy"
```

Expected:
- both commands exit 0, with no command-name warnings;
- `ls .claude/skills | grep speckit-ov-` lists 8 skills: 7 user-facing + `speckit-ov-guard`;
- in Claude Code, typing `/speckit-ov` offers all 7 user-facing commands;
- `jq '.hooks.PreToolUse' .claude/settings.json` shows one group with matcher
  `Edit|Write|MultiEdit|NotebookEdit`;
- re-running `specify extension add … --dev --force` does not duplicate it (FR-033).

## 2. Workflow order (Story 3, Story 8)

1. In Claude Code, run `/speckit-ov-help`. It prints both groups, each opening with one
   sentence on why the split exists (FR-010). It lists every once-per-project step as missing
   and refuses to go further. `git status` shows no changes (FR-013).
2. Run `/speckit-ov-init`, then `/speckit-ov-help` again: `/speckit-ov-init` is done.
   `docs/srs/.gitkeep`, `docs/srs/modules/.gitkeep` and `docs/c4/.gitkeep` exist.
   `AGENTS.md` mentions the Bash gap, and
   `grep -F 'ov enforces autonomous agent loops.' AGENTS.md` matches (FR-015).

## 3. Guard (SC-003, Story 2)

1. Run `/speckit-ov-nogo` and add `src/core/` when asked. `.aiignore` lists `.aiignore` and
   `src/core/`.
2. Ask Claude to edit `src/core/x.rs`: denied with the `read-only for agents` reason.
3. Ask Claude to edit `.aiignore`: denied.
4. Ask Claude to read `src/core/x.rs`: allowed.
5. Ask Claude to edit `src/main.rs`: allowed.
6. Ask Claude to edit `docs/workspace.dsl` (once it exists): allowed. It is shared and not in
   the default `.aiignore`. Editing `docs/srs/SRS.md` is denied (FR-035).
7. Scripted equivalent: `bash $OV/tests/ov-guard.test.sh` (contract: [guard-hook.md](./contracts/guard-hook.md)).
8. Latency: `bash $OV/tests/ov-guard-latency.test.sh` prints median/p90/max over 50 runs and
   fails if the median is above 200 ms (SC-007).

## 4. CI check (SC-004, Story 2)

In a GitHub test repo containing the scratch project, pushed to `main` with ov set up:

1. `git switch -c demo`, change `src/core/x.rs`, commit with
   `Co-Authored-By: Claude <noreply@anthropic.com>`, push and open a PR → `ov-aiignore` fails
   and names the commit and path.
2. From another branch: one human commit touching `src/core/x.rs` and one commit with
   `Co-Authored-By: Claude <noreply@anthropic.com>` touching `src/main.rs` → passes.
3. From a branch named `ai/demo`: a commit without an agent trailer touching `src/core/x.rs`
   → passes, because branch names play no role (Scenario 2a).
4. From a fork of the test repo, open a PR with an agent-trailer commit touching
   `src/core/x.rs` → `ov-aiignore` fails, as for a same-repo PR. If `ai_review: on`,
   `ov-ai-review` passes with the "fork PR, AI review skipped" summary (FR-058). If
   `auto_merge: on`, the fork PR is not set to auto-merge (FR-054).
5. Offline equivalent: `bash $OV/tests/ov-ci-aiignore.test.sh` (fixture repo, includes a
   fork-shaped `refs/pull/<n>/head` case).

## 5. SRS + C4 (Stories 4, 5)

1. Run `/speckit-ov-srs`. The template lands at `docs/srs/SRS.md`. Write two modules, each
   with a `Paths:` line, and confirm.
2. `docs/srs/modules/{a,b}.md` exist, each starting with the GENERATED header. Running the
   split again changes nothing.
3. Run `/speckit-ov-c4-context`; `docs/workspace.dsl` includes `c4/a.dsl` and `c4/b.dsl`.
4. Run `/speckit-implement` on a feature: the optional `after_implement` hook offers
   `/speckit-ov-c4-code`, which updates only that module's `.dsl`.

## 6. Constitution (Story 7)

```bash
.specify/scripts/bash/resolve-template.sh constitution-template --json | jq -r .TEMPLATE_CONTENT | head -1
```

Expected: `<!-- ov-policy -->`. After `/speckit-constitution`, `/speckit-ov-help` marks the
step done only if the marker survived.

## 7. PR policy (Story 6)

1. Run `/speckit-ov-pr` and choose `trailer`, auto-merge `on`, ai_review `off`.
   Expected:
   - `jq -r '.attribution.commit' .claude/settings.json` = `Assisted-by: claude-code`;
   - `CONTRIBUTING.md` states that a commit is an agent commit only when it carries an agent
     trailer, whatever its branch;
   - `.github/ov-ruleset-main.json` requires `ov-aiignore` only;
   - `ov-automerge.yml` is present;
   - no `.githooks/` directory exists and `git config core.hooksPath` is unset.
2. Let Claude commit a change: the message ends with `Assisted-by: claude-code`.
3. Re-run choosing `coauthor`: the `attribution.commit` key is gone, and Claude's commits carry
   `Co-Authored-By: Claude <noreply@anthropic.com>` again. The guard still denies listed paths
   in both modes.
4. Re-run choosing `ai_review: on` with no `ANTHROPIC_API_KEY` secret. Expected: on a
   same-repo PR, `ov-ai-review` fails with the missing-secret message, and the ruleset lists
   it as required.

## 8. Bundle

From the scratch project of §1 (extension and preset installed):

```bash
mkdir .ov-bundle && cp "$OV/bundles/ov/bundle.yml" .ov-bundle/
specify bundle validate --path .ov-bundle/bundle.yml
rm -r .ov-bundle
```

Expected: exit 0. The copy is needed because references resolve against the project that
contains `bundle.yml`, not the cwd (see the [preset-bundle.md](./contracts/preset-bundle.md)
fallback if local sources are rejected).

## Setup commits

Commit the files that ov's setup commands write (workflows, `.aiignore`, settings) as a
**human** commit (no agent trailer). The default `.aiignore` lists
those files, so an agent commit touching them fails `ov-aiignore` by design.
