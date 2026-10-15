# Implementation Plan: ov spec-kit extension, preset and bundle

**Branch**: `001-ov-extension` | **Date**: 2026-10-15 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/001-ov-extension/spec.md` (accepted 2026-10-15)

**Status**: Phase 0 and Phase 1 complete. Author decisions D-1 (accept `/speckit-ov-*`) and
D-2 (hook as a spec-kit event) are recorded in [research.md](./research.md). Revised
2026-10-15 after plan review: `branch` authorship mode removed (no git hooks), fork handling,
shared `workspace.dsl`, guard latency test, scope statement. Revised again 2026-10-15 during
`/speckit-tasks`: the agent branch prefix is removed (agent commits are identified by trailer
only), auto-merge is limited to same-repo PRs, and the `docs/` folders get a `.gitkeep`.

## Summary

Ship `ov` as plain files only:
- a spec-kit extension (`extensions/ov/`): one manifest, markdown command templates, bash
  scripts, and the templates it installs (project files, GitHub workflows, ruleset);
- a preset (`presets/ov-policy/`) that prepends POLICY.md to the constitution template;
- a bundle (`bundles/ov/`) combining the two.

Enforcement runs through mechanisms spec-kit and Claude Code already provide:
- a PreToolUse guard (Edit/Write/MultiEdit/NotebookEdit) registered as a spec-kit agent
  event (D-2);
- `pull_request_target` CI checks that read policy from the base branch and cover every PR,
  forks included (the AI review reports pass-with-skip on forks);
- Claude Code's `attribution` setting (trailer mode) for authorship. No git hooks are installed.

Scope: ov enforces autonomous agent loops. Augmented coding (human asks, human approves each
edit) is outside its scope and reviewed manually by the owner (FR-015).

`.aiignore` matching reuses git's own gitignore engine (R-4).

## Technical Context

**Language/Version**: Bash ≥ 4 (scripts), Markdown (command templates), YAML (manifests,
workflows), JSON (ruleset, settings fragment)

**Primary Dependencies**:
- runtime: spec-kit `specify` ≥ 1.2.0, git, `jq`, Claude Code;
- CI: GitHub Actions, the `gh` CLI and the Claude Code CLI

**Storage**: Files only: `.aiignore`, `.specify/extensions/ov/ov-config.yml`, `docs/**`

**Testing**: bash test scripts under `tests/` plus `shellcheck` (R-12); end-to-end validation
in [quickstart.md](./quickstart.md)

**Target Platform**: Linux/macOS developer machines with Claude Code; GitHub-hosted runners

**Project Type**: spec-kit extension + preset + bundle (configuration/tooling, no service)

**Performance Goals**: The guard's median latency is ≤ 200 ms over 50 runs, enforced by
`tests/ov-guard-latency.test.sh` (SC-007), so the hook isn't noticeable while editing. The CI
check finishes in under 1 min on a 100-commit PR.

**Constraints**:
- no Python package and no `specify` CLI changes;
- no fork of spec-kit;
- `README.md` and `POLICY.md` are never written by agents;
- Claude Code is the only integration;
- the layout mirrors `core_pack/extensions/git` and `bug`.

**Scale/Scope**:
- 7 user-facing commands (`/speckit-ov-*`, D-1) + 1 internal guard command (D-2);
- 1 manifest per package (extension, preset, bundle);
- about 10 bash scripts and 9 shipped templates.


## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| # | Principle | Status | Evidence / issue |
|---|-----------|--------|------------------|
| I | `ov-` prefix | PASS (constitution 1.2.0) | Commands are `/speckit-ov-*`, allowed by exception 1 since 1.2.0 (D-1). Filenames comply: `speckit.ov.*.md` and the manifest names are imposed (exception 1); installed `AGENTS.md`, `CONTRIBUTING.md`, `.aiignore`, `docs/workspace.dsl` and the `docs/**/.gitkeep` placeholders (author decision 2026-10-15) are convention names (exception 3); everything else is `ov-*` (R-3). Mechanism: `scripts/ov-lint-prefix.sh` in repo CI (R-12). |
| II | Human specs are the source of truth | PASS | The SRS split is a deterministic script, so the agent never rewrites the SRS (R-9). Generated files carry the GENERATED header. This plan traces to the accepted spec. |
| III | Pure extension, no fork | PASS | Only `extension.yml` `hooks:`/`events:`/`config`, preset `prepend`, `bundle.yml`. No spec-kit file patched (R-2, D-2). |
| IV | Claude Code only | PASS | Only the `claude` integration is targeted; the bundle pins `integration: claude`. |
| V | Mechanisms over prose | PASS | Each rule has a mechanism: `.aiignore` (guard + CI, R-5/R-6), authorship (`attribution` settings file + CI trailer classification, R-6/R-8), AI review (required check, R-7), POLICY.md in constitution (preset + marker check, R-10), prefix (lint, R-12). Bash bypass: accepted gap, CI backstop, documented (FR-014). |
| VI | Human-owned docs | PASS | No task writes `README.md`/`POLICY.md`. The extension ships no README (R-1). The dogfooded `.aiignore` denies agent edits; CI fails agent commits touching them (R-12). |
| VII | Keep it small | PASS with note | One manifest per package, no CLI changes, no wrappers or aliases. +1 internal command `speckit.ov.guard` (justified below). |

**Post-design re-check (Phase 1)**: all seven principles still pass against
[data-model.md](./data-model.md) and [contracts/](./contracts/).
- Every shipped filename is `ov-*` or an allowed exception.
- No design element writes README.md or POLICY.md.
- Every enforcement rule in the contracts names its mechanism: the guard, `ov-aiignore`,
  `ov-ai-review`, the `attribution` setting, the preset + marker check, the prefix lint and the
  guard latency test.
- Re-checked after the plan review (branch mode removed, forks, shared `workspace.dsl`): still
  all PASS. Dropping the commit-msg hook removes a mechanism, but it only enforced the removed
  mode, so no remaining rule is left as prose only.

## Project Structure

### Documentation (this feature)

```text
specs/001-ov-extension/
├── spec.md              # accepted 2026-10-15
├── plan.md              # this file
├── research.md          # Phase 0 output (done)
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output: extension-manifest, commands, guard-hook,
│                        #   ci-checks, srs-format, preset-bundle
└── tasks.md             # Phase 2 output (/speckit-tasks)
```

### Source Code (repository root)

```text
extensions/ov/
├── extension.yml                      # commands, hooks: after_implement, events: pre_tool_use, config
├── ov-config-template.yml             # → .specify/extensions/ov/ov-config.yml
├── .extensionignore                   # keep tests/fixtures out of installs
├── commands/
│   ├── speckit.ov.init.md
│   ├── speckit.ov.help.md
│   ├── speckit.ov.srs.md
│   ├── speckit.ov.c4-context.md
│   ├── speckit.ov.c4-code.md
│   ├── speckit.ov.nogo.md
│   ├── speckit.ov.pr.md
│   └── speckit.ov.guard.md            # internal, carries scripts.sh for the PreToolUse event (D-2)
├── scripts/bash/
│   ├── ov-common.sh                   # paths, config read/write, no-overwrite copy (FR-007)
│   ├── ov-aiignore-match.sh           # git check-ignore wrapper (R-4)
│   ├── ov-guard.sh                    # PreToolUse deny logic (R-5)
│   ├── ov-init.sh
│   ├── ov-status.sh                   # read-only state report for /ov-help (FR-012/013)
│   ├── ov-srs.sh                      # template copy + split (R-9)
│   ├── ov-c4.sh                       # workspace skeleton copy, !include upkeep
│   ├── ov-nogo.sh
│   ├── ov-pr.sh
│   └── ov-ci-aiignore.sh              # per-commit CI logic (R-6)
└── templates/
    ├── ov-agents.md                   # → AGENTS.md
    ├── ov-contributing.md             # → CONTRIBUTING.md
    ├── ov-srs.md                      # → docs/srs/SRS.md
    ├── ov-workspace.dsl               # → docs/workspace.dsl
    ├── ov-aiignore                    # → .aiignore
    ├── ov-ruleset-main.json           # → .github/ov-ruleset-main.json
    ├── ov-aiignore.yml                # → .github/workflows/ov-aiignore.yml
    ├── ov-ai-review.yml               # → .github/workflows/ov-ai-review.yml
    └── ov-automerge.yml               # → .github/workflows/ov-automerge.yml

presets/ov-policy/
├── preset.yml                         # constitution-template, strategy: prepend
└── templates/ov-policy.md             # synced copy of POLICY.md (R-10)

bundles/ov/bundle.yml                  # extension ov + preset ov-policy (R-11)

scripts/                               # ov repo dev tooling, not shipped
├── ov-sync-policy.sh
└── ov-lint-prefix.sh

tests/                                 # ov repo only, not shipped
├── ov-test-lib.sh
└── ov-*.test.sh

.github/workflows/ov-ci.yml            # ov repo CI: shellcheck, tests, prefix lint, policy sync
```

**Structure Decision**: Three packages side by side (`extensions/`, `presets/`, `bundles/`),
each shaped like spec-kit's bundled equivalents. Repo-only tooling lives in `scripts/`,
`tests/` and `.github/` and is never shipped. `README.md` and `POLICY.md` stay at the root,
untouched.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| Internal 8th command `speckit.ov.guard` (D-2) | spec-kit events point at a command template's `scripts.sh` | Reusing `speckit.ov.nogo`'s `scripts:` would make that command's own script the guard |
