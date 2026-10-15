# Quickstart results: ov end-to-end validation (T070)

**Run**: 2026-10-15, `/speckit-implement` | **Guide**: [quickstart.md](../quickstart.md)

**Environment**: Linux, spec-kit `specify` 1.2.0, Claude Code 2.1.283, git 2.56.0, jq 1.8.2,
shellcheck 0.11.0 (uvx cache), structurizr (local build). Scratch project
`/tmp/ov-qs.ASytP7/scratch`, created with `specify init scratch --integration claude`. It is
disposable, and its preset was swapped for a stand-in copy during §6.

**How "Claude Code" steps were run**: headless `claude -p` in the scratch project, with the
real project hooks (`--setting-sources project,local`, no MCP servers, no permission bypass)
and a tight `--allowedTools` list per step. Haiku by default; Sonnet where noted. Steps that
need a human answer were run with the answer passed as the command argument, and the dialogue
itself is handed to the author.

Status values: **PASS**, **PASS after fix** (a deviation found and fixed in this run),
**FAIL** (not fixed), **AUTHOR** (needs a person, GitHub or an interactive UI; handed over).

This file uses tables, not checkboxes, because `/speckit-implement` counts every checkbox
under `checklists/` as an unchecked gate item.

## 1. Install

| Step | Status | Evidence / deviation |
|------|--------|----------------------|
| `specify extension add … --dev` and `specify preset add --dev …` exit 0, no warnings | PASS | both rc 0, no `warn` line |
| 8 `speckit-ov-*` skills | PASS | 7 user-facing + `speckit-ov-guard` |
| typing `/speckit-ov` offers the 7 user-facing commands | AUTHOR | interactive menu. Note: the guard skill has no "hide from menu" flag in its generated `SKILL.md`, so the menu will likely show 8 entries (accepted under D-2) |
| one PreToolUse group `Edit\|Write\|MultiEdit\|NotebookEdit` | PASS | `jq` shows exactly one group |
| `extension add … --dev --force` does not duplicate it (FR-033) | PASS | still 1 group, 1 `after_implement` entry |

`specify init` in 1.2.0 does not run `git init`; the scratch repo was initialised by hand.

## 2. Workflow order

| Step | Status | Evidence / deviation |
|------|--------|----------------------|
| 2.1 `/speckit-ov-help`: both groups, a "why" sentence each, all steps missing, refuses, no file change | PASS after fix | First run: Haiku paraphrased the first group's opening sentence and printed the second group without its 8 commands. `speckit.ov.help.md` now says to copy each heading and opening sentence verbatim and always print both groups in full before the stop. Re-run: everything correct, `git status` clean |
| 2.2 `/speckit-ov-init`: `.gitkeep` ×3 (empty), `AGENTS.md` with the Bash gap and the FR-015 sentence; help then shows init done | PASS | headless run; `ov-status.sh` step 1 `done: true` |

## 3. Guard (SC-003)

| Step | Status | Evidence / deviation |
|------|--------|----------------------|
| 3.1 `/speckit-ov-nogo`, add `src/core/` | PASS | headless with `src/core/` as argument: `.aiignore` = 6 defaults + `src/core/`, workflow created, Bash gap and human-commit reminders shown. The "which paths?" question itself: AUTHOR |
| 3.2 Edit `src/core/x.rs` denied | PASS | live hook: `ov: src/core/x.rs is read-only for agents (listed in .aiignore). Ask the human to change it.` |
| 3.3 Edit `.aiignore` denied | PASS | same message for `.aiignore` |
| 3.4 Read `src/core/x.rs` allowed | PASS | |
| 3.5 Edit `src/main.rs` allowed | PASS | file changed |
| 3.6 Edit `docs/workspace.dsl` allowed; `docs/srs/SRS.md` denied (FR-035) | PASS | as expected |
| 3.7 `tests/ov-guard.test.sh` | PASS | 91/91 |
| 3.8 `tests/ov-guard-latency.test.sh` (SC-007) | PASS | median 18.7 ms, p90 19.9 ms, max 20.3 ms |

Edit's own "read the file first" check runs before PreToolUse hooks, so a test prompt must
read each file before editing it, or the hook is never reached.

## 4. CI check (SC-004)

| Step | Status | Evidence / deviation |
|------|--------|----------------------|
| 4.1 agent-trailer commit on `src/core/x.rs` fails, names commit + path | AUTHOR (local PASS) | needs a GitHub test repo. Local: `ov-ci-aiignore.sh` on the scratch repo → rc 1, `<sha> src/core/x.rs` |
| 4.2 human commit on `src/core/x.rs` + agent commit on `src/main.rs` passes | AUTHOR (local PASS) | local rc 0: "2 commit(s) checked, 1 agent commit(s)" |
| 4.3 branch `ai/demo`, no trailer, touches `src/core/x.rs`, passes | AUTHOR (local PASS) | local rc 0 |
| 4.4 fork PR: `ov-aiignore` fails; AI review pass-with-skip; no auto-merge | AUTHOR | needs a fork. The fork-shaped `refs/pull/<n>/head` case is covered offline by T019(i) |
| 4.5 offline `tests/ov-ci-aiignore.test.sh` | PASS | 25/25 |

## 5. SRS + C4

| Step | Status | Evidence / deviation |
|------|--------|----------------------|
| 5.1 template lands at `docs/srs/SRS.md`; human writes two modules | PASS / AUTHOR | `ov-srs.sh template` created it; `split` on the untouched template → exit 3 listing every `TODO(` line. The SRS was simulated with `tests/fixtures/ov-srs-valid.md`; the guided dialogue: AUTHOR |
| 5.2 `modules/{a,b}.md` with GENERATED header; re-split changes nothing | PASS | second split prints `unchanged:` ×2 |
| 5.3 `workspace.dsl` includes `c4/a.dsl` and `c4/b.dsl` | PASS after fix | `ov-c4.sh includes` added both lines and stubs. The C1/C2 dialogue: AUTHOR. `structurizr validate` failed: the skeleton's `theme default` loads `static.structurizr.com`, which no longer resolves after the Structurizr cloud end of life (2026-09-30). The line was removed from `ov-workspace.dsl`; the template, and the workspace with an agent-written `a.dsl`, now validate (rc 0) |
| 5.4 after `/speckit-implement`, the optional hook offers `/speckit-ov-c4-code`, which changes only that module's `.dsl` | PASS / AUTHOR | headless `/speckit-ov-c4-code a` changed only `docs/c4/a.dsl` (components + `Code`-tagged groups, valid DSL). The hook offer works in this repo's own `/speckit-implement` (same `extensions.yml` entry); a full feature cycle in a target project: AUTHOR |

## 6. Constitution

| Step | Status | Evidence / deviation |
|------|--------|----------------------|
| resolved `constitution-template` starts with `<!-- ov-policy -->` | PASS | |
| after `/speckit-constitution`, help marks the step done only if the marker survived | PASS after fix | see below |

Findings:
- **Haiku drops the marker.** In two runs, one with the marker-only placeholder and one with a
  stand-in policy text under the marker in a temp preset copy, Haiku removed `<!-- ov-policy -->`.
  The core command allows comments to be removed. In the second run it also paraphrased the
  policy text. `ov-status.sh` correctly reported the step as not done.
- **Sonnet keeps it.** It kept the marker and the policy text verbatim, but `ov-status.sh`
  still reported "not done". The Sync Impact Report comment that `/speckit-constitution` always
  writes names the replaced placeholders (`[PRINCIPLE_1_NAME] → …`), and the placeholder grep
  matched them. **Fixed**: placeholders are now looked for outside HTML comments only
  (`ov-status.sh`, 3 new cases in `tests/ov-status.test.sh`). The Sonnet constitution now
  counts as done.
- With the real `POLICY.md`: AUTHOR. Whether the marker survives depends on the model.

## 7. PR policy

| Step | Status | Evidence / deviation |
|------|--------|----------------------|
| 7.1 `trailer` / auto-merge `on` / ai_review `off` | PASS | headless with the answers as arguments: `attribution.commit` = `Assisted-by: claude-code`; CONTRIBUTING has the trailer-only sentence; ruleset contexts `["ov-aiignore"]`; `ov-automerge.yml` present; no `.githooks/`, `core.hooksPath` unset. The three-question dialogue: AUTHOR |
| 7.2 Claude's commit ends with `Assisted-by: claude-code` | PASS | |
| 7.3 back to `coauthor`: key gone, commits carry `Co-Authored-By: Claude …`; guard still denies | PASS | `attribution` key removed; Haiku and Sonnet commits carry `Co-Authored-By: Claude <model> <noreply@anthropic.com>`; guard rc 2 |
| 7.4 `ai_review: on`, no secret: `ov-ai-review` fails with the missing-secret message and is required | AUTHOR (local PASS) | needs GitHub. Local: contexts `["ov-aiignore","ov-ai-review"]`; `ov-ai-review.yml` holds the exact message |

Observation for 7.3: trailers come from Claude Code's commit instructions, not from a
mechanism. A prompt saying "use git add and git commit directly" produced a commit with no
trailer at all (1 of 3 coauthor-mode commits). CI then counts it as a human commit. This is
the same class of gap as FR-014's Bash gap, on the authorship side.

## 8. Bundle

| Step | Status | Evidence / deviation |
|------|--------|----------------------|
| `specify bundle validate` exits 0 | PASS after fix | The quickstart command failed: 1.2.0 takes `--path`, not an argument (exit 2). It also resolves references against the project that **contains** `bundle.yml`, so `$OV/bundles/ov/bundle.yml` is always checked against this repo, where the preset is not installed: exit 1 online, 0 offline with a warning, from any cwd. A copy inside the scratch project validates with rc 0. quickstart §8 and contracts/preset-bundle.md are corrected |

## Handed to the author

1. §1: check the `/speckit-ov` menu (expect the guard to show as well).
2. §3.1, §5.1, §5.3, §7.1: the human dialogue of `/speckit-ov-nogo`, `/speckit-ov-srs`,
   `/speckit-ov-c4-context` and `/speckit-ov-pr`.
3. §4.1–4.4 and §7.4 on a GitHub test repo with a fork, `gh`, the imported ruleset and no
   `ANTHROPIC_API_KEY` secret.
4. §5.4: a full feature cycle in a target project, accepting the `/speckit-ov-c4-code` offer.
5. §6 with the real `POLICY.md`, in the model you use day to day.
