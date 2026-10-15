---

description: "Task list for the ov spec-kit extension, preset and bundle"
---

# Tasks: ov spec-kit extension, preset and bundle

**Input**: Design documents from `specs/001-ov-extension/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md),
[data-model.md](./data-model.md), [contracts/](./contracts/), [quickstart.md](./quickstart.md)

**Tests**: Included. The plan (Testing, R-12) and the contracts name bash test scripts as
enforcement mechanisms (`tests/ov-guard.test.sh`, `tests/ov-guard-latency.test.sh` for SC-007,
`tests/ov-ci-aiignore.test.sh`, `tests/ov-init.test.sh`). Each story writes its tests first.
They should fail until that story's implementation tasks are done.

**Organization**: Tasks are grouped by user story. Story labels keep the spec's numbering
(US1–US8), so `[US8]` is "Initialize the project". Phases run in priority order: P1 (US1, US2,
US8), then P2 (US3, US4, US6), then P3 (US5, US7).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependency on an incomplete task)
- **[Story]**: The user story the task belongs to (US1 … US8)

## Ground rules for every task

- **Do not ask the author questions during `/speckit-implement`.** When a task is ambiguous,
  take the safest default and keep going. Then add an entry under "Defaults taken during
  implementation" in the Notes at the end of this file. Mark the entry `[DEFAULT]` and give
  the task ID, what was ambiguous, the default chosen, and why it is the safest. The author
  reviews the Notes at the end. Never reopen decisions recorded in the spec's Review log.
- **No branch-based logic anywhere.** There is no agent branch prefix and no branch mode.
  An agent commit is a commit carrying an agent trailer (FR-034), on every branch (FR-031).
- **Never create or edit `README.md` or `POLICY.md`** (Principle VI, FR-061). The author
  writes both.
- Every new shipped or repo-tooling file is named `ov-*`. The only exceptions are the names
  spec-kit imposes (`extension.yml`, `preset.yml`, `bundle.yml`, `.extensionignore`,
  `commands/speckit.ov.*.md`) and the installed convention names (`AGENTS.md`,
  `CONTRIBUTING.md`, `.aiignore`, `docs/workspace.dsl`) (Principle I, R-3).
- Scripts: `#!/usr/bin/env bash`, `set -euo pipefail`, Bash ≥ 4, no GNU-only flags (macOS is a
  target), `jq` for JSON, no YAML library (flat `key: value` parsing). They must pass
  `shellcheck -x`.
- Exit codes for command scripts (contracts/commands.md): `0` = done, `1` = refused or error
  with a message, `3` = needs human input.
- No template copy overwrites an existing target file. The script prints
  `exists, kept: <path>` and leaves the file alone (FR-007).
- Scratch projects for tests and validation are created under `${TMPDIR:-/tmp}` with
  `mktemp -d`, never inside this repo. Per R-1 the install command is
  `specify init <dir> --integration claude && cd <dir> && specify extension add <repo>/extensions/ov --dev`.
- Installed-package references (`agents.py`, `events/__init__.py`, `presets/_manifest.py`, …)
  are under `~/.local/share/uv/tools/specify-cli/lib/python3.12/site-packages/specify_cli/`.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Repository layout and the shared test helper.

- [X] T001 Create the directory layout from plan.md "Source Code": `extensions/ov/commands/`, `extensions/ov/scripts/bash/`, `extensions/ov/templates/`, `presets/ov-policy/templates/`, `bundles/ov/`, `scripts/`, `tests/fixtures/`, `.github/workflows/`. Leave `README.md` untouched and do not create `POLICY.md`.
- [X] T002 [P] Create the test helper `tests/ov-test-lib.sh`, sourced by every `tests/ov-*.test.sh`. It sets `OV_REPO` (the repo root, resolved from the helper's own path) and provides:
  - `ov_t_scratch`: `mktemp -d` plus a cleanup trap;
  - `ov_t_git_init <dir>`: `git init` with a local test identity;
  - `ov_t_install_copy <dir>`: copies `extensions/ov` to `<dir>/.specify/extensions/ov` and creates `ov-config.yml` from `ov-config-template.yml`, to simulate `extension add` without `specify`;
  - `ov_t_skip <reason>`: prints `SKIP: <reason>` and exits 0, used when `specify` is not on PATH;
  - asserts: `assert_eq`, `assert_exit <code> <cmd…>`, `assert_contains`, `assert_not_contains`, `assert_file`, `assert_no_file`;
  - `ov_t_snapshot <dir>`: sorted path + sha256 list of every file, to compare trees for read-only and idempotency checks;
  - `ov_t_done`: prints a pass/fail summary and exits non-zero on any failure.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: The shared script library, the `.aiignore` matcher (R-4: used by the guard, the CI
check and the AI review), the prefix lint (Principle I mechanism) and the repo CI.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

### Tests for Foundational

- [X] T003 [P] Write `tests/ov-common.test.sh` for `ov-common.sh`:
  - `ov_config_get`/`ov_config_set` round-trip;
  - `ov_config_set` with an unchanged value leaves the file byte-identical;
  - `ov_copy_template` creates missing parent dirs, and prints `exists, kept: <path>` without changing an existing target;
  - `ov_hook_registered` is true for an inline `.specify/extensions.yml` fixture with an `after_implement` entry for `speckit.ov.c4-code`, and false when the entry is missing or carries `enabled: false`;
  - `ov_event_registered` is true for an inline `.claude/settings.json` fixture whose `hooks.PreToolUse` contains a command mentioning `speckit.ov.guard`, and false otherwise.
- [X] T004 [P] Write `tests/ov-aiignore-match.test.sh` for the R-4 cases:
  - `src/core/` matches `src/core/a/b.rs` but not `src/corex.rs`;
  - `*.lock` + `!keep.lock` matches `a.lock` but not `keep.lock`;
  - `docs/**/x.md` works;
  - paths that do not exist on disk still match;
  - `--stdin` mode prints only the matching paths;
  - neither a `.gitignore` in the cwd nor a global `core.excludesFile` (set through a temp `HOME`) leaks in;
  - the same patterns content reuses one cache dir under `${TMPDIR}`, and changed content gets a new one;
  - exit codes are 0 (match), 1 (no match) and 2 (usage error).
- [X] T005 [P] Write `tests/ov-lint-prefix.test.sh`. Build a fake tree in a scratch dir and run `scripts/ov-lint-prefix.sh <root>`:
  - passes for `ov-x.sh`, `extension.yml`, `commands/speckit.ov.init.md`;
  - fails and names the file for `helper.sh` and for `commands/speckit.ov.init.md` placed outside `commands/`;
  - fails for an `extension.yml` command name that does not match `^speckit\.ov\.[a-z0-9-]+$`.

### Implementation for Foundational

- [X] T006 [P] Implement `extensions/ov/scripts/bash/ov-common.sh` (sourced, no top-level side effects):
  - `ov_project_root` returns `${CLAUDE_PROJECT_DIR}`, else `git rev-parse --show-toplevel`, else `pwd`.
  - Variables: `OV_EXT_DIR=<root>/.specify/extensions/ov`, `OV_TEMPLATES=$OV_EXT_DIR/templates`, `OV_CONFIG=$OV_EXT_DIR/ov-config.yml`.
  - `ov_config_get <key> [file]` and `ov_config_set <key> <value> [file]`: flat `key: value` lines; replace or append; write only when the content changes.
  - `ov_copy_template <template-name> <dest-relpath>`: no overwrite (FR-007); prints `created: <path>` or `exists, kept: <path>`.
  - `ov_write_if_changed <dest> <tmpfile>`: moves the file into place only when it differs (SC-006).
  - `ov_die <msg>`: prints `ov: <msg>` on stderr and exits 1.
  - `ov_sha256 <file>`: `sha256sum` or `shasum -a 256`.
  - `ov_hook_registered`: `.specify/extensions.yml` has an `after_implement` entry whose command is `speckit.ov.c4-code` and which is not `enabled: false`. Parse it with awk; the check must not depend on indentation width.
  - `ov_event_registered`: `jq -e '[.hooks.PreToolUse[]? | .. | strings | select(contains("speckit.ov.guard"))] | length > 0' .claude/settings.json`.
- [X] T007 [P] Implement `extensions/ov/scripts/bash/ov-aiignore-match.sh` (R-4). It works both sourced (it defines `ov_aiignore_match`) and as a CLI:
  - Usage: `ov-aiignore-match.sh <patterns-file> <relpath>…` or `ov-aiignore-match.sh <patterns-file> --stdin`. It prints matching paths and exits 0 on a match, 1 on no match, 2 on a usage error.
  - Cache: `${TMPDIR:-/tmp}/ov-aiignore-<sha256 of patterns-file>` holds a bare git dir whose `info/exclude` is the patterns content, plus an empty `wt/` work tree. Build it in a `mktemp -d` and `mv` it into place, discarding it if another process won the race.
  - Match: `GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null git --git-dir=<cache> --work-tree=<cache>/wt -c core.excludesFile=/dev/null check-ignore --no-index [--stdin] -- <paths>`.
- [X] T008 [P] Implement `scripts/ov-lint-prefix.sh [root]` (Principle I mechanism, R-12):
  - Scan every regular file under `extensions/ov/`, `presets/ov-policy/`, `bundles/ov/`, `scripts/`, `tests/` and `.github/workflows/`. Each basename must start with `ov-` or be on the allowlist: `extension.yml`, `preset.yml`, `bundle.yml`, `.extensionignore`, and `speckit.ov.*.md` (only directly under `extensions/ov/commands/`).
  - Every `name:` under `provides.commands` in `extensions/ov/extension.yml` must match `^speckit\.ov\.[a-z0-9-]+$`.
  - Exit 1 listing every offender, otherwise exit 0.
- [X] T009 Create the repo CI `.github/workflows/ov-ci.yml` (depends on T008). Trigger: `push` and `pull_request`. Jobs:
  - `shellcheck`: `shellcheck -x` on `extensions/ov/scripts/bash/*.sh scripts/*.sh tests/*.sh`;
  - `prefix`: `bash scripts/ov-lint-prefix.sh`;
  - `test`: install `jq`, plus spec-kit `specify` pinned to the version matching `requires.speckit_version` (use the install command from the spec-kit README); then run every `tests/ov-*.test.sh` and fail if any fails.

**Checkpoint**: `bash tests/ov-common.test.sh`, `tests/ov-aiignore-match.test.sh` and
`tests/ov-lint-prefix.test.sh` pass. Story work can begin.

---

## Phase 3: User Story 1 - Install ov into a fresh project (Priority: P1)

**Goal**: `specify extension add <repo>/extensions/ov --dev` succeeds on a fresh Claude project,
and the 7 user-facing commands show up as `/speckit-ov-*` skills.

**Independent Test**: quickstart.md §1. In a scratch project, both `specify init … --integration
claude` and `specify extension add … --dev` exit 0 with no warnings. `.claude/skills/` holds one
`speckit-ov-<cmd>` skill per manifest command (7 at the end of this story, 8 after US2), and
`.specify/extensions.yml` holds the `after_implement` → `speckit.ov.c4-code` hook.

### Tests for User Story 1

- [X] T010 [US1] Write `tests/ov-install.test.sh`. It runs `ov_t_skip` if `specify` is missing. In a scratch project with git initialised and committed before the install:
  - (1) `extension add <repo>/extensions/ov --dev` exits 0 and its output has no line matching `(?i)warn`;
  - (2) for every `name:` under `provides.commands` in `extensions/ov/extension.yml`, `.claude/skills/speckit-ov-<cmd>/SKILL.md` exists, and the `speckit-ov-*` skill count equals the manifest command count;
  - (3) `ov_hook_registered` (from `ov-common.sh`) returns 0;
  - (4) `.specify/extensions/ov/ov-config.yml` exists;
  - (5) Scenario 1.3: every path in `git status --porcelain` lies in the install-time locations of contracts/extension-manifest.md. Those are `.specify/extensions/ov/**`, `.specify/extensions.yml`, `.claude/skills/speckit-ov-*/**`, `.claude/settings.json`, plus `.specify/events.py` and any other spec-kit-owned registry file under `.specify/extensions/`. No file under `.specify/scripts/`, `.specify/templates/` or `.specify/memory/` changed;
  - (6) a second `extension add … --dev --force` leaves `.specify/extensions.yml` with a single ov `after_implement` entry;
  - (7) `specify extension remove ov` removes the skills and the hook entry.

### Implementation for User Story 1

- [X] T011 [P] [US1] Create `extensions/ov/ov-config-template.yml`. One flat line per key, with a one-line comment above each key quoting its constraint from data-model.md:
  - `authorship: coauthor` (values: "`coauthor` \| `trailer`");
  - `auto_merge: off` ("`on` \| `off`");
  - `ai_review: on` ("`on` \| `off`");
  - `configured: false` ("`true` \| `false`", set by `/speckit-ov-pr`).
- [X] T012 [P] [US1] Create `extensions/ov/.extensionignore` (format per `extensions/__init__.py:1257`). It excludes anything that must not ship into target projects (`*.test.sh`, `fixtures/`, editor and OS cruft).
- [X] T013 [P] [US1] Create the seven command templates in `extensions/ov/commands/`: `speckit.ov.init.md`, `speckit.ov.help.md`, `speckit.ov.srs.md`, `speckit.ov.c4-context.md`, `speckit.ov.c4-code.md`, `speckit.ov.nogo.md` and `speckit.ov.pr.md`. Use the format of `core_pack/extensions/git/commands/*.md` (R-3):
  - `description:` frontmatter taken from that command's row in contracts/commands.md;
  - a `## User Input` block with `$ARGUMENTS` and "You **MUST** consider the user input before proceeding (if not empty)";
  - an `## Execution` section naming its script under `.specify/extensions/ov/scripts/bash/` (as in the contracts/commands.md table) and the exit-code meanings 0/1/3.

  Each story phase below completes its own command's body.
- [X] T014 [US1] Create `extensions/ov/extension.yml` exactly per contracts/extension-manifest.md, minus the `speckit.ov.guard` command and the `events:` block (both are added in T029). Depends on T011 and T013.
  - `schema_version: "1.0"`;
  - `extension.id: ov`, `version: 0.1.0`, a name and a description; set `author`, `license` and `repository` to `TODO(author)`;
  - `requires.speckit_version: ">=1.2.0"`; `requires.tools`: `git` (required), `jq` (required), `gh` (optional);
  - `provides.commands`: the 7 user-facing entries, no `aliases` (D-1);
  - `provides.config`: `{name: ov-config.yml, template: ov-config-template.yml, required: false}`;
  - `hooks.after_implement`: `{command: speckit.ov.c4-code, optional: true, prompt: "Update the C4 model (C3/C4) for the module just implemented?"}`.
- [X] T015 [US1] Validate the install in a scratch project per R-1. Fix any validation error or warning in `extensions/ov/extension.yml`. If the validator rejects `TODO(author)` in a field, do not invent a value: keep the field, and report it to the author. Check that `ov_hook_registered` in `extensions/ov/scripts/bash/ov-common.sh` holds against the real `.specify/extensions.yml`, and adjust the helper if spec-kit's YAML shape differs. Run `tests/ov-install.test.sh` until it passes.

**Checkpoint**: ov installs cleanly and the 7 user-facing commands are listed (their scripts
arrive in later stories).

---

## Phase 4: User Story 2 - Protect paths from agent edits (Priority: P1) 🎯 MVP

**Goal**: The PreToolUse guard denies Edit/Write/MultiEdit/NotebookEdit on paths in
`.aiignore` (Read is never blocked). The `ov-aiignore` CI check fails any PR where an agent
commit touches a path listed in the base branch's `.aiignore`. `/speckit-ov-nogo` creates
`.aiignore` and installs the workflow.

**Independent Test**: quickstart.md §3 and the offline §4.5. With `src/core/` listed, an Edit on
`src/core/x.rs` is denied, a Read is allowed, and an agent-trailer commit touching it fails
`tests/ov-ci-aiignore.test.sh`'s fixture PR.

### Tests for User Story 2

- [X] T016 [P] [US2] Create the guard payload fixtures. Each is a Claude Code PreToolUse JSON with tokens `__ROOT__` and `__PATH__` that the test substitutes:
  - `tests/fixtures/ov-guard-edit.json`, `ov-guard-write.json` and `ov-guard-multiedit.json` (`tool_input.file_path`);
  - `tests/fixtures/ov-guard-notebookedit.json` (`tool_input.notebook_path`);
  - `tests/fixtures/ov-guard-nopath.json` (no path field);
  - `tests/fixtures/ov-guard-malformed.json` (invalid JSON).
- [X] T017 [P] [US2] Write `tests/ov-guard.test.sh` against contracts/guard-hook.md:
  - For each of the 4 tools, test the decision table on 4 paths: listed `src/core/x.rs` → exit 2 with stderr containing `is read-only for agents (listed in .aiignore)`; unlisted `src/main.rs` → 0; outside the project (`/etc/hosts`, and `__ROOT__/../x`) → 0; no `.aiignore` → 0.
  - Malformed and no-path payloads → exit 0 with a warning.
  - Editing `.aiignore` itself → 2 (Scenario 2.3).
  - With the default `templates/ov-aiignore`: `docs/srs/SRS.md` → 2 and `docs/workspace.dsl` → 0 (FR-035).
  - A relative `file_path` is resolved against the payload `cwd`. With `CLAUDE_PROJECT_DIR` unset, the root falls back to the payload `cwd`.
  - The result is the same with `authorship: trailer` in `ov-config.yml` (mode-independent).
  - The project tree is unchanged after every call (`ov_t_snapshot`).
  - With `specify` available: one run through the real dispatcher. Read the exact hook command from the scratch project's `.claude/settings.json` with `jq`, pipe the listed-path payload into it, and assert exit 2.
- [X] T018 [P] [US2] Write `tests/ov-guard-latency.test.sh` per contracts/guard-hook.md:
  - `.aiignore` = the default template entries plus 20 extra patterns;
  - one discarded warm-up run, then 50 timed runs on the listed-path Edit payload, using `$EPOCHREALTIME` and falling back to `date +%s%N` (skip with a notice if neither gives sub-second time);
  - print the median, p90 and max; fail if the median is above 200 ms (SC-007).
- [X] T019 [P] [US2] Write `tests/ov-ci-aiignore.test.sh`. Build a fixture repo whose `main` has `.aiignore` (`.aiignore`, `src/core/`) and the shipped scripts. Run `ov-ci-aiignore.sh <base_sha> <head_sha>` for each case:
  - (a) a `Co-Authored-By: Claude <noreply@anthropic.com>` commit touching `src/core/x.rs` → exit 1, output contains `<sha> src/core/x.rs` (Scenario 2.2);
  - (b) the same with a lowercase `co-authored-by: claude <x>` → 1;
  - (c) an `Assisted-by: claude-code` commit → 1;
  - (d) a commit with no trailer touching `src/core/x.rs`, on a branch named `ai/demo` → 0, because branch names play no role (Scenario 2a);
  - (e) a human commit touching `src/core/x.rs` plus a trailer commit touching only `src/main.rs` → 0 (Scenario 2b);
  - (f) a `Co-Authored-By: Jane <j@x>` commit touching it → 0;
  - (g) an agent rename `src/core/x.rs` → `src/y.rs` → 1 (both sides count);
  - (h) an agent commit that adds `lib/` to `.aiignore` and changes `lib/a.rs` → 1, listing `.aiignore` and not `lib/a.rs` (Scenario 2.4);
  - (i) fork-shaped: an agent-trailer commit reachable only as `refs/pull/7/head` (no branch) → 1 (Scenario 2d);
  - (j) a base with no `.aiignore` → 0 with a notice;
  - (k) an agent merge commit whose merge result edits `src/core/x.rs` (an "evil merge") → 1, while a clean merge of `main` into the head adds no violation;
  - (l) with `GITHUB_STEP_SUMMARY` set, violations are written to it.
- [X] T020 [P] [US2] Write `tests/ov-nogo.test.sh`. Use a scratch project prepared with `ov_t_install_copy`, plus an inline `.claude/settings.json` carrying the ov PreToolUse command:
  - The first run creates `.aiignore` from the template. It lists `.aiignore` and `docs/srs/SRS.md` and not `docs/workspace.dsl` (FR-030, FR-035). It also creates `.github/workflows/ov-aiignore.yml`.
  - `--add src/core/` appends the pattern once; repeating it leaves the tree byte-identical (SC-006).
  - A pre-existing `.aiignore` is kept, with `exists, kept: .aiignore`.
  - Settings without the event → exit 1 with a `specify extension add` restore instruction.
  - `.claude/settings.json` is never modified by `ov-nogo.sh`.
- [X] T021 [P] [US2] Write `tests/ov-event-merge.test.sh` (FR-033; skip without `specify`). Before installing, seed `.claude/settings.json` with an unrelated `PreToolUse` group (matcher `Bash`) and a `permissions.allow` entry. Then:
  - after `extension add --dev`, both seeded entries are intact and there is exactly one group with matcher `Edit|Write|MultiEdit|NotebookEdit`;
  - after `extension add --dev --force`, there is still exactly one;
  - after `extension remove ov`, the ov group is gone and the seeded entries are intact.
- [X] T022 [P] [US2] Write `tests/ov-workflows.test.sh` with static assertions on `extensions/ov/templates/ov-aiignore.yml`:
  - the trigger is `pull_request_target` with types `opened, synchronize, reopened, edited`;
  - `permissions` is `contents: read`;
  - the job and status name is `ov-aiignore`;
  - checkout uses the base SHA with `persist-credentials: false`;
  - the PR head is fetched as `refs/pull/<n>/head` and never checked out;
  - no `run:` block interpolates `github.head_ref` or `github.event.pull_request.head.*` (they must come in through `env:`);
  - it calls `.specify/extensions/ov/scripts/bash/ov-ci-aiignore.sh`;
  - if `actionlint` is on PATH, it also runs on the template.

### Implementation for User Story 2

- [X] T023 [P] [US2] Implement `extensions/ov/scripts/bash/ov-guard.sh` following the contracts/guard-hook.md decision table (first match wins):
  - Read stdin once. Make one `jq` call for `tool_name`, `tool_input.file_path // tool_input.notebook_path` and `cwd`. If parsing fails or the path is missing, warn on stderr and exit 0.
  - The root is `CLAUDE_PROJECT_DIR`, falling back to the payload `cwd`. Make the path absolute, normalise `.` and `..` lexically in bash (no `realpath -m`; symlinks are not resolved), then strip `<root>/`. A path outside the root → exit 0.
  - No `<root>/.aiignore` → exit 0.
  - A match through `ov_aiignore_match` (source `ov-aiignore-match.sh`) → print `ov: <relpath> is read-only for agents (listed in .aiignore). Ask the human to change it.` on stderr and exit 2.
  - Otherwise exit 0.
  - Never read `ov-config.yml`, never write to the project. A warm call is one `jq` plus one `git check-ignore` (SC-007).
- [X] T024 [P] [US2] Create `extensions/ov/commands/speckit.ov.guard.md`:
  - frontmatter `description: "Internal: PreToolUse guard that denies agent edits to paths listed in .aiignore (run by spec-kit, not by users)"`;
  - a `scripts:` entry `sh: scripts/bash/ov-guard.sh`. Check the path base against how `events/__init__.py:289-326` resolves `scripts.sh`;
  - a body stating that the command is internal (D-2), is not part of the workflow, is not listed by `/speckit-ov-help`, and does nothing when invoked by hand.
- [X] T025 [P] [US2] Create `extensions/ov/templates/ov-aiignore`:
  - a comment header: gitignore syntax; listed paths are read-only for agents and Read is never blocked; edits through Bash are not intercepted, and CI is the backstop;
  - exactly these default entries (FR-035): `.aiignore`, `.claude/settings.json`, `.github/workflows/ov-*.yml`, `.github/ov-ruleset-main.json`, `.specify/extensions/ov/**`, `docs/srs/SRS.md`. Do **not** list `docs/workspace.dsl` (shared, FR-040);
  - a closing comment `# project paths (added by /speckit-ov-nogo)`.
- [X] T026 [P] [US2] Implement `extensions/ov/scripts/bash/ov-ci-aiignore.sh <base_sha> <head_sha>` per contracts/ci-checks.md and the data-model "Agent commit":
  - Read `.aiignore` from the base commit with `git show <base_sha>:.aiignore`. If it is missing, print `ov-aiignore: no .aiignore on the base branch, nothing to check` and exit 0.
  - For each commit in `git rev-list <base_sha>..<head_sha>`, decide whether it is an agent commit: `agent = message matches (?i)^co-authored-by:.*claude OR message matches ^Assisted-by: claude-code$`. Do not look at branch names.
  - For an agent commit, collect its paths with `git diff-tree --no-commit-id --no-renames -r --name-only <c>`. For merge commits, which plain `diff-tree` leaves empty, use `git diff-tree --no-commit-id --cc --name-only <c>`. Match them through `ov-aiignore-match.sh <base .aiignore tmpfile> --stdin`.
  - Print `<sha> <path>` per violation, append them to `$GITHUB_STEP_SUMMARY` when it is set, and exit 1 if any were found. Otherwise exit 0.
  - Never check out or execute head content.
- [X] T027 [P] [US2] Create the workflow template `extensions/ov/templates/ov-aiignore.yml`:
  - `on: pull_request_target: types: [opened, synchronize, reopened, edited]`; `permissions: contents: read`;
  - one job `ov-aiignore` with `name: ov-aiignore`, which must equal the ruleset status context;
  - `actions/checkout` at `${{ github.event.pull_request.base.sha }}` with `fetch-depth: 0` and `persist-credentials: false`;
  - `git fetch origin refs/pull/${PR_NUMBER}/head`;
  - then `bash .specify/extensions/ov/scripts/bash/ov-ci-aiignore.sh "$BASE_SHA" "$HEAD_SHA"`;
  - `BASE_SHA`, `HEAD_SHA` and `PR_NUMBER` are passed only through `env:`. Nothing from the PR head (branch name, title, repo name) is used or interpolated into `run:`.
- [X] T028 [US2] Implement `extensions/ov/scripts/bash/ov-nogo.sh [--add <pattern>]…` (depends on T025, T027):
  - `ov_copy_template ov-aiignore .aiignore`;
  - append each `--add` pattern that is not already a line in `.aiignore`. Reject empty or multi-line patterns with exit 1. Write through `ov_write_if_changed`;
  - `ov_copy_template ov-aiignore.yml .github/workflows/ov-aiignore.yml`;
  - check `ov_event_registered`. If it fails, print `ov: the .aiignore guard is not registered in .claude/settings.json. Restore it with: specify extension add <path-to-ov>/extensions/ov --dev --force` and exit 1;
  - finally, remind the human to commit these files as a **human** commit (quickstart "Setup commits");
  - never modify `.claude/settings.json`.
- [X] T029 [US2] Update `extensions/ov/extension.yml` (depends on T024):
  - add the `provides.commands` entry `speckit.ov.guard` → `commands/speckit.ov.guard.md`, described as internal;
  - add `events.pre_tool_use: {command: speckit.ov.guard, matcher: "Edit|Write|MultiEdit|NotebookEdit", timeout: 10}` (FR-032, D-2).
- [X] T030 [US2] Complete `extensions/ov/commands/speckit.ov.nogo.md` with the per-command flow:
  - show the current `.aiignore` read-only, if one exists;
  - ask the human which paths should be read-only for agents (one question; gitignore syntax);
  - run `ov-nogo.sh` with one `--add` per answer and relay `created:` and `exists, kept:` lines;
  - on exit 1, show the restore command;
  - state that Read is never blocked, that Bash writes are not intercepted and CI is the backstop (FR-014), and that the files must be committed by a human;
  - never edit `.aiignore` with Edit/Write tools.
- [X] T031 [US2] Re-install ov in a scratch project (R-1) and confirm two things: `jq '.hooks.PreToolUse' .claude/settings.json` shows exactly one group with matcher `Edit|Write|MultiEdit|NotebookEdit`, and `ov_event_registered` in `extensions/ov/scripts/bash/ov-common.sh` holds against it (adjust the helper if needed). Then run every US2 test plus `tests/ov-install.test.sh`, which now expects 8 skills.
- [X] T032 [US2] Dogfood the guard in this repo (R-12, Principle VI mechanism):
  - run `specify extension add extensions/ov --dev` at the repo root;
  - create the repo-root `.aiignore` with exactly `README.md`, `POLICY.md` and `.aiignore`. Do not use the default template here: it would lock `.github/workflows/ov-*.yml`, which later tasks still edit;
  - copy `extensions/ov/templates/ov-aiignore.yml` to `.github/workflows/ov-aiignore.yml`;
  - leave all of this uncommitted for the author to commit as a human commit, and say so.

**Checkpoint**: The guard and the CI check work on their own. Together with US1, this is the MVP.

---

## Phase 5: User Story 8 - Initialize the project (Priority: P1)

**Goal**: `/speckit-ov-init` writes `AGENTS.md` and the empty `docs/` skeleton, and verifies the
spec-kit hook and event (FR-008, FR-009).

**Independent Test**: quickstart.md §2.2. After `/speckit-ov-init`, `AGENTS.md` and
`docs/srs/`, `docs/srs/modules/` and `docs/c4/` exist, each holding an empty `.gitkeep`, and
`grep -F 'ov enforces autonomous agent loops.' AGENTS.md` matches. A second run changes nothing.

### Tests for User Story 8

- [X] T033 [P] [US8] Write `tests/ov-init.test.sh`. Use a scratch project from `ov_t_install_copy`, with inline `.specify/extensions.yml` and `.claude/settings.json` fixtures that carry the ov hook and event:
  - the first run creates `AGENTS.md` and the three dirs, each holding an empty `.gitkeep`;
  - a dir that already holds files still gets its `.gitkeep`, and its other files are untouched;
  - `grep -F` finds the exact FR-015 sentence "ov enforces autonomous agent loops. Augmented coding (human asks, human approves each edit) is outside its scope and reviewed manually by the owner." (R-13);
  - `AGENTS.md` states the Bash gap and the CI backstop (FR-014);
  - the second run leaves the tree byte-identical and prints `exists, kept: AGENTS.md` (Scenario 8.3, SC-006);
  - a pre-existing `AGENTS.md` is untouched;
  - a missing hook or a missing event → exit 1 with `specify extension add <source> --dev --force`;
  - an entry with `enabled: false` → `specify extension enable ov` is invoked (put a stub `specify` on `PATH` that records its arguments).

### Implementation for User Story 8

- [X] T034 [P] [US8] Create `extensions/ov/templates/ov-agents.md` (installed as `AGENTS.md`). Sections:
  - what ov enforces;
  - the FR-015 sentence, verbatim: "ov enforces autonomous agent loops. Augmented coding (human asks, human approves each edit) is outside its scope and reviewed manually by the owner.";
  - `.aiignore` paths are read-only for agents, and Read is allowed;
  - FR-014: the guard does not cover writes made through Bash, and the `ov-aiignore` CI check is the backstop;
  - authorship: agent commits carry an agent trailer, and that alone is what CI checks (branch names play no role); details in `CONTRIBUTING.md`;
  - the SRS is human-written and agents never author it (Principle II);
  - run `/speckit-ov-help` for the workflow order.

  Do not mention or reference `README.md` or `POLICY.md`.
- [X] T035 [US8] Implement `extensions/ov/scripts/bash/ov-init.sh` (contracts/commands.md):
  - `ov_copy_template ov-agents.md AGENTS.md`; `mkdir -p docs/srs/modules docs/c4`;
  - create an empty `.gitkeep` in `docs/srs/`, `docs/srs/modules/` and `docs/c4/` when it is absent, so git tracks the folders (FR-006). Never touch other files in them;
  - check `ov_hook_registered` and `ov_event_registered`;
  - if an entry exists but is disabled (`enabled: false`), run `specify extension enable ov`;
  - if one is absent, print `specify extension add <source> --dev --force` and exit 1 (FR-009);
  - exit 0 otherwise. Re-running changes nothing (SC-006).
- [X] T036 [US8] Complete `extensions/ov/commands/speckit.ov.init.md`: say it is the first once-per-project command, run `ov-init.sh`, relay its output, and on exit 1 show the restore command and stop. No human dialogue.

**Checkpoint**: US1, US2 and US8 (all of P1) work.

---

## Phase 6: User Story 3 - Know the order and refuse to skip steps (Priority: P2)

**Goal**: `/speckit-ov-help` prints both command groups, names every missing
once-per-project step with its producing command, refuses to go on when one is missing, and
never writes a file (FR-010–FR-013).

**Independent Test**: quickstart.md §2.1. In a repo without `docs/srs/SRS.md`, `/speckit-ov-help`
names `/speckit-ov-srs` as missing and stops. `git status` shows no change.

### Tests for User Story 3

- [X] T037 [P] [US3] Write `tests/ov-status.test.sh` for `ov-status.sh`:
  - in an empty scratch project, all 6 steps are `done: false`;
  - with every artifact from the data-model "Project setup state" table present, all steps are `done: true` and `all_done: true`;
  - each step goes missing alone when its artifact is removed;
  - an empty or comment-only `.aiignore` → `/speckit-ov-nogo` not done (spec edge case 1);
  - a constitution with `<!-- ov-policy -->` but a `[PROJECT_NAME]` placeholder → not done;
  - a constitution without the marker → not done; a constitution with the marker and a `- [X]` checkbox → done;
  - `ov-config.yml` with `authorship: branch` → reported in `config_errors`;
  - the exit code is 0 in every case;
  - three runs leave the tree byte-identical (`ov_t_snapshot`, FR-013).

### Implementation for User Story 3

- [X] T038 [US3] Implement `extensions/ov/scripts/bash/ov-status.sh` (read-only, writes nothing, not even temp files in the project). It prints JSON built with `jq -n`: `{"steps":[{"order":N,"step":"<command>","done":bool,"missing":["<artifact>",…]}…],"config_errors":[…],"all_done":bool}`. The steps, in data-model order:
  - 1 `/speckit-ov-init`: `AGENTS.md`, `docs/srs/`, `docs/srs/modules/`, `docs/c4/`, `ov_hook_registered`, `ov_event_registered`;
  - 2 `/speckit-ov-srs`: `docs/srs/SRS.md`;
  - 3 `/speckit-ov-c4-context`: `docs/workspace.dsl`;
  - 4 `/speckit-ov-nogo`: `.aiignore` with at least one non-comment, non-blank line, plus `ov_event_registered` and `.github/workflows/ov-aiignore.yml`;
  - 5 `/speckit-constitution`: `.specify/memory/constitution.md` contains `<!-- ov-policy -->` and no `[ALL_CAPS_IDENTIFIER]` placeholder, detected with `grep -Eq '\[[A-Z][A-Z0-9_]{2,}\]'`;
  - 6 `/speckit-ov-pr`: `ov-config.yml` has `configured: true`, and `CONTRIBUTING.md` and `.github/ov-ruleset-main.json` exist.

  `config_errors` lists every config value outside its allowed set: `authorship` "`coauthor` \| `trailer`", `auto_merge` "`on` \| `off`", `ai_review` "`on` \| `off`", `configured` "`true` \| `false`". Always exit 0.
- [X] T039 [US3] Complete `extensions/ov/commands/speckit.ov.help.md` (contracts/commands.md):
  - run `ov-status.sh`, then render the two groups in this exact order, one sentence per command;
  - each group opens with one sentence saying why the split exists (FR-010);
  - "once per project": `/speckit-ov-init`, `/speckit-ov-srs`, `/speckit-ov-c4-context`, `/speckit-ov-nogo`, `/speckit-constitution`, `/speckit-ov-pr`;
  - "once per module or feature": `/speckit-specify`, `/speckit-clarify`, `/speckit-plan`, `/speckit-tasks`, `/speckit-implement`, `/speckit-converge`, `/speckit-ov-c4-code`, PR;
  - mark each step done or missing; report `config_errors`;
  - if any step is missing, name each one with its producing command and stop (FR-011);
  - never run a step, never create, modify or delete a file (FR-013), and never list `speckit-ov-guard`.

**Checkpoint**: `/speckit-ov-help` reports the real state of any repo without touching it.

---

## Phase 7: User Story 4 - Write the SRS and derive module specs (Priority: P2)

**Goal**: `/speckit-ov-srs` drops the SRS template, guides the human section by section (the
agent writes no SRS prose), then splits the SRS into `docs/srs/modules/<name>.md` with a
deterministic script (FR-020–FR-023, R-9).

**Independent Test**: quickstart.md §5.1–5.2. Splitting a two-module SRS writes
`docs/srs/modules/a.md` and `b.md`, each starting with the GENERATED header. A second split
changes nothing.

### Tests for User Story 4

- [X] T040 [P] [US4] Create the SRS fixtures in `tests/fixtures/`:
  - `ov-srs-valid.md`: modules `a` and `b`, shared `## Purpose`/`## Scope`, `Paths:` lines, and a fenced code block containing a fake `## Module: fake` line;
  - `ov-srs-duplicate.md`: two `## Module: a`;
  - `ov-srs-no-paths.md`;
  - `ov-srs-bad-name.md`: `## Module: Bad_Name`;
  - `ov-srs-todo.md`: one `TODO(` left;
  - `ov-srs-stray-heading.md`: `## Glossary` after the first module.
- [X] T041 [P] [US4] Write `tests/ov-srs.test.sh` per contracts/srs-format.md:
  - `template` creates `docs/srs/SRS.md`, and keeps an existing one;
  - `split` on `ov-srs-valid.md` writes exactly `a.md` and `b.md`. Line 1 is `<!-- GENERATED from SRS.md, do not edit -->`, then every line before the first `## Module:` heading, then that module's section verbatim with `Paths:` included. `fake` is ignored;
  - a second `split` is byte-identical (SC-006);
  - duplicate, no-paths, bad-name and stray-heading → exit 1 naming the line, with nothing written and existing module files untouched (all-or-nothing);
  - `TODO(` left → exit 3 listing line numbers;
  - an orphan `modules/old.md` is reported and left in place (Scenario 4.3);
  - a missing SRS → exit 1 with "run /speckit-ov-srs to start from the template";
  - `list` prints `a` and `b`, one per line.

### Implementation for User Story 4

- [X] T042 [P] [US4] Create `extensions/ov/templates/ov-srs.md` (installed as `docs/srs/SRS.md`) following the contracts/srs-format.md grammar:
  - `# TODO(system name): Software Requirements Specification`, `## Purpose` and `## Scope`;
  - one example `## Module: TODO(module-name)` with a `Paths: TODO(gitignore globs, space-separated)` line and `### Responsibility`, `### Inputs`, `### Outputs`, `### Invariants`, `### Acceptance Tests`;
  - all guidance text wrapped in `TODO(…)`, plus a comment explaining that module names match `^[a-z0-9][a-z0-9-]*$` and are unique.
- [X] T043 [US4] Implement `extensions/ov/scripts/bash/ov-srs.sh` with subcommands `template` | `split` | `list`:
  - `template`: `ov_copy_template ov-srs.md docs/srs/SRS.md`.
  - `split`: refuse while any `TODO(` remains (exit 3, listing line numbers). Detect headings outside fenced code blocks. Validation from data-model.md: "module names unique; every module has a non-empty `Paths:` line", names match `^[a-z0-9][a-z0-9-]*$`, and any non-`## Module:` level-2 heading after the first module is an error (exit 1 naming the line).
  - `split` output: the shared part is every line before the first `## Module:` heading; a module section runs to the next `## Module:` or EOF. Render into a `mktemp -d`, then move each file into `docs/srs/modules/` with `ov_write_if_changed`. Report orphans (`modules/*.md` only, so `.gitkeep` is never one) without deleting them.
  - `list`: print the module names in SRS order.
  - Missing `docs/srs/SRS.md` → exit 1 with `run /speckit-ov-srs to start from the template`.
- [X] T044 [US4] Complete `extensions/ov/commands/speckit.ov.srs.md`:
  - run `ov-srs.sh template`;
  - walk the human through each template section in order, reading out that section's guidance;
  - wait for the human to edit the file. The agent never writes or rewrites SRS content (FR-023, Principle II), and the file is guarded by `.aiignore`;
  - run `ov-srs.sh split` only after the human confirms. On exit 3 or 1, show the reported lines and ask the human to fix them;
  - report the generated files and any orphans.

**Checkpoint**: The SRS flow works, and `ov-srs.sh list` is available for US5 and US6.

---

## Phase 8: User Story 6 - PR and authorship policy (Priority: P2)

**Goal**: `/speckit-ov-pr` asks the three questions, records the answers in config and
`CONTRIBUTING.md`, sets or removes `attribution.commit`, installs the optional workflows and
writes the ruleset template (FR-050–FR-058).

**Independent Test**: quickstart.md §7.1. Run
`ov-pr.sh --authorship trailer --auto-merge on --ai-review off`. Then
`.claude/settings.json` has `attribution.commit = "Assisted-by: claude-code"`, `CONTRIBUTING.md`
has the trailer-only agent-commit statement, the ruleset requires `ov-aiignore` only, and
`ov-automerge.yml` exists.

**Depends on**: US4 (`ov-srs.sh` for the AI review's module mapping, FR-057).

### Tests for User Story 6

- [X] T045 [P] [US6] Write `tests/ov-pr.test.sh`. Use a scratch project from `ov_t_install_copy` with a `.claude/settings.json` holding unrelated keys:
  - defaults → config `authorship: coauthor`, `auto_merge: off`, `ai_review: on`, `configured: true`, and no `branch_prefix` key; the `CONTRIBUTING.md` block records them (Scenario 6.1);
  - `trailer` → `jq -r .attribution.commit` = `Assisted-by: claude-code` (Scenario 6.2);
  - back to `coauthor` → the key is removed and other settings are intact;
  - `CONTRIBUTING.md` says a commit is an agent commit only when it carries an agent trailer, whatever its branch, and never mentions a branch prefix (Scenario 6.8);
  - `--ai-review off` → the ruleset contexts are exactly `["ov-aiignore"]` (Scenario 6.6), and `on` → they include `ov-ai-review` (Scenario 6.4);
  - auto-merge `on` installs `.github/workflows/ov-automerge.yml`; `off` removes it only if it is byte-identical to the template;
  - invalid values (`--authorship branch`, the removed `--prefix ai/` flag, `--auto-merge yes`) → exit 1;
  - the same answers twice → byte-identical tree (SC-006);
  - an existing `CONTRIBUTING.md` without markers keeps its content and gains the marked block once;
  - no `.githooks/` exists and `git config core.hooksPath` is unset.
- [X] T046 [P] [US6] Write `tests/ov-srs-map.test.sh` for `ov-srs.sh context`. Use `docs/srs/modules/a.md` (`Paths: src/a/**`) and `b.md` (`Paths: src/b/**`):
  - stdin `src/a/x.rs` → only `a.md`'s content;
  - `src/a/x.rs` plus `src/b/y.rs` → both;
  - `README` only → the shared sections of `docs/srs/SRS.md` only (FR-057);
  - the output is deterministic (sorted module order).
- [X] T047 [P] [US6] Extend `tests/ov-workflows.test.sh` with assertions on `extensions/ov/templates/ov-ai-review.yml` and `ov-automerge.yml`:
  - the AI review job and status name is `ov-ai-review`;
  - its first step is the fork check, writing `ov-ai-review: fork PR, AI review skipped`; the secret step comes after it and is skipped for forks;
  - the exact missing-secret message from contracts/ci-checks.md is present;
  - `--allowedTools` is limited to `Read,Grep,Glob` and Bash is not allowed;
  - automerge permissions are `contents: write` and `pull-requests: write`; the job has an `if:` restricting it to `github.event.pull_request.head.repo.full_name == github.repository` (forks never auto-merge, Scenario 6.3a); it runs `gh pr merge --auto --squash`; and it references no branch name or prefix;
  - in both templates, no head ref or head repo name is interpolated into `run:`.

### Implementation for User Story 6

- [X] T048 [P] [US6] Create `extensions/ov/templates/ov-contributing.md` (installed as `CONTRIBUTING.md`):
  - a short intro, then a block between `<!-- ov:pr:begin -->` and `<!-- ov:pr:end -->` with tokens `{{OV_AUTHORSHIP}}`, `{{OV_TRAILER}}`, `{{OV_AUTO_MERGE}}`, `{{OV_AI_REVIEW}}`;
  - the sentence "A commit is an agent commit only when it carries an agent trailer (`Co-Authored-By: Claude …` or `Assisted-by: claude-code`), whatever its branch." (FR-051);
  - when auto-merge is on: "Same-repo PRs merge automatically once the required checks pass; fork PRs are never auto-merged." (FR-054);
  - a reminder that ov setup files are committed by a human.
- [X] T049 [P] [US6] Create `extensions/ov/templates/ov-ruleset-main.json` (contracts/ci-checks.md "Ruleset template"): `"name": "ov-main"`, `"target": "branch"`, `"enforcement": "active"`, `conditions.ref_name.include: ["refs/heads/main"]` and `exclude: []`. Rules:
  - `pull_request` with `required_approving_review_count: 0` and the other boolean parameters `false`;
  - `non_fast_forward` and `deletion`;
  - `required_status_checks` with `required_status_checks: [{"context": "ov-aiignore"}]` and `strict_required_status_checks_policy: false`.
- [X] T050 [P] [US6] Create `extensions/ov/templates/ov-automerge.yml` (contracts/ci-checks.md):
  - `on: pull_request_target: types: [opened, reopened, ready_for_review]`;
  - permissions `contents: write` and `pull-requests: write`;
  - job `ov-automerge` with `if: github.event.pull_request.head.repo.full_name == github.repository`, so fork PRs never auto-merge (FR-054, Scenario 6.3a);
  - no checkout and no branch-name logic. A single step runs `gh pr merge --auto --squash "$PR_NUMBER"` with `PR_NUMBER`, `GH_TOKEN: ${{ github.token }}` and `GH_REPO: ${{ github.repository }}` passed through `env:`.
- [X] T051 [US6] Add the `context` subcommand to `extensions/ov/scripts/bash/ov-srs.sh` (FR-057; depends on T043):
  - read changed paths from stdin;
  - for each `docs/srs/modules/*.md`, turn its `Paths:` globs into a temp patterns file (one glob per line) and match the paths through `ov-aiignore-match.sh --stdin`;
  - print each matched module file's content, preceded by `=== module: <name> ===`, in sorted order;
  - if nothing matches, print the shared sections (the lines before the first `## Module:`) of `docs/srs/SRS.md`. Exit 0.
- [X] T052 [US6] Create `extensions/ov/templates/ov-ai-review.yml` (contracts/ci-checks.md, R-7; depends on T051):
  - `on: pull_request_target: types: [opened, synchronize, reopened]`; permissions `contents: read` and `pull-requests: read`; job `ov-ai-review` with `name: ov-ai-review`.
  - Step 1 (`id: fork`): compare `HEAD_REPO` (`github.event.pull_request.head.repo.full_name`, through `env:`) with `github.repository`. For a fork, append `ov-ai-review: fork PR, AI review skipped` to `$GITHUB_STEP_SUMMARY` and set the output `skip=true` (FR-058).
  - All later steps carry `if: steps.fork.outputs.skip != 'true'`.
  - Step 2: with `ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}` in `env:`, fail if it is empty, printing exactly `ov-ai-review: repository secret ANTHROPIC_API_KEY is not set (set it or run /speckit-ov-pr and choose ai_review: off)` (FR-056).
  - Then check out the base SHA (`persist-credentials: false`), fetch `refs/pull/<n>/head`, and pipe `git diff --name-only <base>...<head>` into `ov-srs.sh context`.
  - Build the prompt file: review instructions, the `git diff <base>...<head>`, the context, and the rule that the run must end with a line `OV-REVIEW: PASS` or `OV-REVIEW: FAIL`.
  - Install the Claude Code CLI and run `claude -p --output-format json --allowedTools "Read,Grep,Glob"` with the prompt on stdin.
  - Write `.result` to the job summary. Exit 0 only if its last non-empty line is `OV-REVIEW: PASS`; otherwise exit 1, including when the verdict is missing.
- [X] T053 [US6] Implement `extensions/ov/scripts/bash/ov-pr.sh --authorship coauthor|trailer --auto-merge on|off --ai-review on|off` (non-interactive, contracts/commands.md; depends on T048–T050, T052):
  - **Validate**: authorship "`coauthor` \| `trailer`", auto_merge "`on` \| `off`", ai_review "`on` \| `off`". Any other value or unknown flag → exit 1.
  - **Config**: `ov_config_set` for the 3 keys, then `configured: true`.
  - **CONTRIBUTING.md**: if absent, copy the template and fill the tokens. If present with the markers, rewrite only between them. If present without markers, append the filled marked block once and keep the existing content. The trailer is `Co-Authored-By: Claude <noreply@anthropic.com>` for `coauthor` and `Assisted-by: claude-code` for `trailer` (FR-052).
  - **Ruleset**: render `.github/ov-ruleset-main.json` with `jq`, adding `{"context":"ov-ai-review"}` when `ai_review: on`. Replace an existing file only if its `.name` is `ov-main`; otherwise keep it and report.
  - **Workflows**: `on` → `ov_copy_template` the workflow. `off` → remove `.github/workflows/ov-ai-review.yml` or `ov-automerge.yml` only if it is byte-identical to its template; otherwise keep it and report.
  - **`.claude/settings.json`**: `trailer` → `jq '.attribution.commit = "Assisted-by: claude-code"'`. `coauthor` → delete `.attribution.commit` only if it equals `Assisted-by: claude-code`, and drop `.attribution` if it becomes empty. Touch no other key; write only on change.
  - Install no git hooks and never set `core.hooksPath` (FR-053 removed).
  - Every write goes through `ov_write_if_changed` (SC-006).
- [X] T054 [US6] Complete `extensions/ov/commands/speckit.ov.pr.md`:
  - ask the three questions one at a time, each with its default: authorship `coauthor` | `trailer` (default `coauthor`), auto-merge on green for same-repo PRs (default `off`), AI review (default `on`). There is no branch-prefix question;
  - run `ov-pr.sh` with the answers and relay its output;
  - then tell the human to import `.github/ov-ruleset-main.json` (Settings → Rules → Rulesets → Import); to enable "Allow auto-merge" when auto-merge is on; to add the `ANTHROPIC_API_KEY` repository secret when `ai_review: on` (without it the required check fails loudly); and to commit the changes as a human commit.

**Checkpoint**: The authorship and merge policy is recorded and enforced. With US2, quickstart
§4 and §7 can run against a GitHub test repo.

---

## Phase 9: User Story 5 - C4 architecture model (Priority: P3)

**Goal**: `/speckit-ov-c4-context` builds C1/C2 in `docs/workspace.dsl` with the human and keeps
one `!include c4/<module>.dsl` per SRS module. `/speckit-ov-c4-code` writes C3/C4 for exactly one
module (FR-040–FR-042).

**Independent Test**: quickstart.md §5.3–5.4. `docs/workspace.dsl` includes `c4/a.dsl` and
`c4/b.dsl`. Running `/speckit-ov-c4-code a` changes only `docs/c4/a.dsl`.

**Depends on**: US4 (`ov-srs.sh list`).

### Tests for User Story 5

- [X] T055 [P] [US5] Write `tests/ov-c4.test.sh`:
  - `skeleton` creates `docs/workspace.dsl` and keeps an existing one;
  - with SRS modules `a` and `b`, `includes` adds exactly one `!include c4/a.dsl` and one `!include c4/b.dsl` between the include markers and creates stub `docs/c4/a.dsl` and `b.dsl` when absent;
  - a second `includes` is byte-identical (SC-006);
  - `includes a`, with an existing customised `docs/c4/b.dsl`, leaves `b.dsl` byte-identical (Scenario 5.3);
  - lines outside the markers are never touched;
  - a missing SRS → exit 1 naming `/speckit-ov-srs`.

### Implementation for User Story 5

- [X] T056 [P] [US5] Create `extensions/ov/templates/ov-workspace.dsl` (installed as `docs/workspace.dsl`), a Structurizr DSL skeleton. Check the syntax against the Structurizr DSL language reference.
  - `workspace "TODO(system name)" "TODO(description)" { !identifiers hierarchical; model { … } views { … } }`;
  - in `model`: commented C1 (people, software systems) and C2 (containers) sections, then a `// ov:includes:begin` / `// ov:includes:end` region for the `!include c4/<module>.dsl` lines;
  - `views`: `systemContext` and `container` views and `theme default`;
  - a header comment saying the file is shared: human and agent may both edit it (FR-040).
- [X] T057 [US5] Implement `extensions/ov/scripts/bash/ov-c4.sh` with subcommands `skeleton` | `includes [<module>]`:
  - `skeleton`: `ov_copy_template ov-workspace.dsl docs/workspace.dsl`.
  - `includes`: take the modules from `ov-srs.sh list`, or only `<module>` when one is given (it must be in that list, otherwise exit 1).
  - For each module, make sure `!include c4/<module>.dsl` sits once between the markers, keeping the lines sorted and writing through `ov_write_if_changed`. If `docs/c4/<module>.dsl` is absent, create a one-line stub `// C3/C4 for <module>: written by /speckit-ov-c4-code`; never overwrite an existing module file.
  - Missing markers in `workspace.dsl` → exit 1 asking the human to restore them.
- [X] T058 [P] [US5] Complete `extensions/ov/commands/speckit.ov.c4-context.md`:
  - run `ov-c4.sh skeleton`;
  - build C1 (people, external systems) and then C2 (containers) with the human: the agent proposes, the human confirms or corrects, one question at a time;
  - edit `docs/workspace.dsl` (shared, FR-040) outside the include markers;
  - finally run `ov-c4.sh includes`.
- [X] T059 [P] [US5] Complete `extensions/ov/commands/speckit.ov.c4-code.md`:
  - take the module from `$ARGUMENTS`, or ask which module when none is given (contracts/commands.md). This also applies when run as the optional `after_implement` hook;
  - run `ov-c4.sh includes <module>`;
  - write C3 (components) and C4 (code) for that module only into `docs/c4/<module>.dsl`. Use `!element <container identifier> { … }` to add components to the container declared in `workspace.dsl`. Structurizr has no code-level element type, so C4 code elements are components tagged `Code`, inside a `group` named after their C3 component;
  - never touch another module's `.dsl`, the SRS, or `workspace.dsl`'s include region.

**Checkpoint**: The C4 model updates per module.

---

## Phase 10: User Story 7 - Constitution always carries POLICY.md (Priority: P3)

**Goal**: The `ov-policy` preset prepends a byte-for-byte copy of POLICY.md to the
constitution template (FR-002, R-10).

**Independent Test**: quickstart.md §6. After `specify preset add --dev <repo>/presets/ov-policy`,
the first line of the resolved `constitution-template` is `<!-- ov-policy -->`.

**Author prerequisite (not an agent task)**: The author writes `POLICY.md`. Its first line is
`<!-- ov-policy -->` and its marker section holds the FR-015 sentence (Principle VI). Until then
the preset ships the marker-only copy from T061. No task creates or edits `POLICY.md`.

### Tests for User Story 7

- [X] T060 [P] [US7] Write `tests/ov-preset.test.sh`:
  - `ov-sync-policy.sh` in a temp copy of the repo (`OV_REPO_ROOT` pointed at it, never at the real repo):
    - POLICY.md absent and the copy marker-only → `--check` exits 0 and prints `POLICY.md not written yet`;
    - POLICY.md absent and the copy holding other content → 1;
    - POLICY.md without the marker → 1 in both modes;
    - matching → 0; differing → `--check` 1, and sync then makes the copy byte-identical.
  - With `specify` available: `specify preset add --dev` on a temp copy of `presets/ov-policy`. `.specify/scripts/bash/resolve-template.sh constitution-template --json | jq -r .TEMPLATE_CONTENT` starts with the copy's content, followed by the core template (Scenario 7.1). Edit the temp copy, re-add with `--force`, and the new text appears (Scenario 7.2).

### Implementation for User Story 7

- [X] T061 [P] [US7] Create `presets/ov-policy/templates/ov-policy.md` containing exactly one line, `<!-- ov-policy -->`. It is a placeholder until the author writes POLICY.md; after that only `scripts/ov-sync-policy.sh` writes this file.
- [X] T062 [P] [US7] Create `presets/ov-policy/preset.yml` per contracts/preset-bundle.md:
  - `schema_version: "1.0"`;
  - `preset.id: ov-policy`, with the name, version, description and author fields `presets/_manifest.py` requires (author `TODO(author)`);
  - `requires.speckit_version: ">=1.2.0"`;
  - `provides.templates: [{type: template, name: constitution-template, file: templates/ov-policy.md, strategy: prepend, description: "Prepend POLICY.md to the constitution template"}]`.
- [X] T063 [P] [US7] Implement `scripts/ov-sync-policy.sh [--check]` (R-10). The root is `${OV_REPO_ROOT:-<repo root>}`.
  - Sync mode: refuse (exit 1) if `POLICY.md` is missing or its first line is not `<!-- ov-policy -->`; otherwise `cp` it byte for byte to `presets/ov-policy/templates/ov-policy.md`.
  - `--check`: exit 1 if the marker is missing or the copy differs. If `POLICY.md` is absent, print `POLICY.md not written yet` and exit 0 only when the copy is exactly the marker line.
  - Never write `POLICY.md`.
- [X] T064 [US7] Add a `policy-sync` job running `bash scripts/ov-sync-policy.sh --check` to `.github/workflows/ov-ci.yml`.

**Checkpoint**: The constitution template always starts with the policy text.

---

## Phase 11: Polish & Cross-Cutting Concerns

**Purpose**: The bundle (FR-003), checks that span every story, and end-to-end validation.

- [X] T065 Create `bundles/ov/bundle.yml` per contracts/preset-bundle.md and R-11:
  - `schema_version: "1.0"`;
  - `bundle:` with id `ov`, plus name, version, role and description; `author` and `license` set to `TODO(author)`;
  - `requires.speckit_version: ">=1.2.0"`; `integration: {id: claude}`;
  - `extensions: [{id: ov, source: ../../extensions/ov}]` and `presets: [{id: ov-policy, source: ../../presets/ov-policy, strategy: prepend}]`.

  Run `specify bundle validate bundles/ov/bundle.yml`. If local `source:` values are rejected, switch them to release-URL placeholders marked `TODO(author)`, and record in the task outcome that dev installs use `extension add` + `preset add` (the R-11 fallback).
- [X] T066 [P] Write `tests/ov-idempotency.test.sh` (SC-006). In a scratch project from `ov_t_install_copy`, run `ov-init.sh`, `ov-srs.sh template`, `ov-c4.sh skeleton`, `ov-nogo.sh --add src/core/` and `ov-pr.sh` with the default answers once, take an `ov_t_snapshot`, run them all again, and assert the tree is byte-identical.
- [X] T067 [P] Write `tests/ov-protected-docs.test.sh` (FR-061, Principle VI): `grep -rnE 'README\.md|POLICY\.md' extensions/ov` finds nothing, so no shipped command, script or template references, and therefore writes, the human-owned docs.
- [X] T068 Run `shellcheck -x` on `extensions/ov/scripts/bash/*.sh scripts/*.sh tests/*.sh` and `bash scripts/ov-lint-prefix.sh`, and fix every finding in the files they name.
- [X] T069 Refresh the dogfood install in this repo with `specify extension add extensions/ov --dev --force`, so `.specify/extensions/ov/` matches the final sources. Check that the repo-root `.aiignore` from T032 is unchanged. Run every `tests/ov-*.test.sh`.
- [X] T070 Run quickstart.md §1–§8 end to end and record pass/fail per step, with any deviation, in `specs/001-ov-extension/checklists/ov-quickstart-results.md`. §1–§3 and §5–§8 need a scratch project and an interactive Claude Code session; §4 needs a GitHub test repo, `gh`, a fork and, for §7.4, no `ANTHROPIC_API_KEY` secret. Hand the steps you cannot run to the author.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)** → **Foundational (Phase 2)** → user stories → **Polish (Phase 11)**.
- **US1** depends on Foundational and blocks every other story, because the manifest is
  required to install anything.
- **US2** depends on US1.
- **US8** depends on US1 and US2, since `ov-init.sh` verifies both the hook and the event.
- **US3** depends on US1. It can run in parallel with US2, US8 and US4.
- **US4** depends on US1.
- **US6** depends on US1 and US4 (`ov-srs.sh` for T051).
- **US5** depends on US1 and US4 (`ov-srs.sh list`).
- **US7** depends only on Foundational, so it can start right after Phase 2.
- **Polish**: T065 needs US1 and US7. T066 needs US2, US4, US5, US6 and US8. T069 and T070 need
  everything.

### Story completion graph

```text
Setup ─► Foundational ─┬─► US1 ─┬─► US2 ─► US8
                       │        ├─► US3
                       │        └─► US4 ─┬─► US6
                       │                 └─► US5
                       └─► US7
                                   all ─► Polish
```

### Within each story

- Tests first; they must fail before implementation.
- Templates and fixtures before the scripts that copy or read them.
- Scripts before the command template that calls them.
- `extensions/ov/extension.yml` is edited by T014 and T029 only, in that order.
- `extensions/ov/scripts/bash/ov-srs.sh` is edited by T043, then T051.
- `tests/ov-workflows.test.sh` is edited by T022, then T047.
- `.github/workflows/ov-ci.yml` is edited by T009, then T064.

### Parallel Opportunities

- Phase 2: T003–T008 are all [P] (six different files). T009 waits for T008.
- After US1: US2, US3, US4 and US7 can proceed in parallel.
- After US4: US5 and US6 can proceed in parallel.
- Within each story, every [P] test task and every [P] template task can run together.

---

## Parallel Example: User Story 2

```bash
# Tests together (different files):
Task: "T016 Guard payload fixtures in tests/fixtures/ov-guard-*.json"
Task: "T017 tests/ov-guard.test.sh"
Task: "T018 tests/ov-guard-latency.test.sh"
Task: "T019 tests/ov-ci-aiignore.test.sh"
Task: "T020 tests/ov-nogo.test.sh"
Task: "T021 tests/ov-event-merge.test.sh"
Task: "T022 tests/ov-workflows.test.sh"

# Then independent implementation files together:
Task: "T023 extensions/ov/scripts/bash/ov-guard.sh"
Task: "T024 extensions/ov/commands/speckit.ov.guard.md"
Task: "T025 extensions/ov/templates/ov-aiignore"
Task: "T026 extensions/ov/scripts/bash/ov-ci-aiignore.sh"
Task: "T027 extensions/ov/templates/ov-aiignore.yml"
# Then in order: T028 (ov-nogo.sh) → T029 (manifest) → T030 (nogo command) → T031 (verify) → T032 (dogfood)
```

## Parallel Example: User Story 6

```bash
Task: "T045 tests/ov-pr.test.sh"
Task: "T046 tests/ov-srs-map.test.sh"
Task: "T047 extend tests/ov-workflows.test.sh"
Task: "T048 extensions/ov/templates/ov-contributing.md"
Task: "T049 extensions/ov/templates/ov-ruleset-main.json"
Task: "T050 extensions/ov/templates/ov-automerge.yml"
# Then: T051 (ov-srs.sh context) → T052 (ov-ai-review.yml) → T053 (ov-pr.sh) → T054 (pr command)
```

---

## Implementation Strategy

### MVP First (US1 + US2)

US1 on its own only lists commands. The first increment that enforces anything is US1 plus
US2: the guard plus the CI check, which is the spec's main mechanism (Principle V).

1. Phase 1 Setup, then Phase 2 Foundational.
2. Phase 3 (US1): install works, 7 commands listed.
3. Phase 4 (US2): guard + `ov-aiignore` CI + `/speckit-ov-nogo`, dogfooded in this repo (T032).
4. **STOP and VALIDATE**: quickstart §1, §3 and §4.5 (offline), plus all tests green.

### Incremental Delivery

1. MVP (US1 + US2): enforcement of read-only paths.
2. Add US8, the `/speckit-ov-init` + `AGENTS.md` scope statement. P1 is now complete.
3. Add US3 `/speckit-ov-help`, then US4 SRS, then US6 PR policy and AI review (P2).
4. Add US5 C4 and US7 preset (P3), then the Polish bundle and end-to-end quickstart.

Each increment leaves every earlier test green; the CI in T009 runs them all.

---

## Notes

- [P] = different files, no dependency on an incomplete task. [USn] = the spec's user story
  number.
- Commit after each task or logical group. Files that the default `.aiignore` lists in
  target projects are committed by a human (quickstart "Setup commits").
- Avoid: writing `README.md`/`POLICY.md`, unprefixed files (other than the allowed
  exceptions), any branch-name logic, interpolating PR-controlled values (`github.head_ref`,
  head repo name, title) in `run:`, overwriting existing target files.

### Author decisions applied to this task list (2026-10-15, spec Review log)

- **No branch prefix, no branch mode**: agent commits are identified by trailer only, on every
  branch (FR-031, FR-050, FR-051, FR-053). No `branch_prefix` config key and no prefix
  question. T011, T019, T026, T027, T034, T045, T048 and T053 reflect this.
- **Auto-merge applies to same-repo PRs only**: fork PRs are never auto-merged (FR-054,
  Scenario 6.3a). See T047 and T050.
- **`.gitkeep` in the `docs/` skeleton**: `docs/srs/`, `docs/srs/modules/` and `docs/c4/` each
  get an empty `.gitkeep`, so a fresh clone keeps them (FR-006). It is a convention name
  (Principle I exception 3). See T033 and T035.
- **No questions during `/speckit-implement`**: see the first ground rule.

### Decisions recorded during task generation

- **Merge commits in the `ov-aiignore` check (T026)**: plain `git diff-tree` prints nothing for
  merge commits, so an agent's "evil merge" would slip past. T026 uses `--cc` for merge
  commits (only paths that differ from every parent), and T019(k) tests it.

### Defaults taken during implementation

<!-- /speckit-implement appends one entry per ambiguity here, without asking the author:
- [DEFAULT] T0NN: <what was ambiguous> → <default chosen>. Why safest: <reason>.
-->

Run of 2026-10-15 (Phases 1–4, stopped at the US2 checkpoint):

- [DEFAULT] T001: `presets/ov-policy/templates/` and `bundles/ov/` stay empty until US7/Polish, so
  git does not track them yet → no `.gitkeep` there. Why safest: the prefix lint (T008) would
  reject an unprefixed `.gitkeep` in those dirs, and the `.gitkeep` rule covers `docs/` only.
- [DEFAULT] T002: `ov_t_scratch` sets `OV_T_DIR` instead of printing the path, and `ov_t_run`
  (used by `assert_exit`) runs the command in a subshell. Why safest: a `$(...)` call would lose
  the cleanup trap, and a function that calls `exit` (e.g. `ov_die`) would end the test.
- [DEFAULT] T002: the test helper exports `GIT_CONFIG_GLOBAL=/dev/null` and
  `GIT_CONFIG_NOSYSTEM=1`; `ov_t_snapshot` skips `.git/` and lists directories as well as files.
  Why safest: the author's git config (signing, hooks, identity) cannot change test results,
  and a created empty directory still shows up as a tree change.
- [DEFAULT] T006: `ov_hook_registered` returns 2 (not just non-zero) when the ov entry exists
  only with `enabled: false`, 1 when it is missing. Why safest: T035 must tell "disabled" (run
  `specify extension enable ov`) from "missing" (exit 1), and both are still "false" for T003.
- [DEFAULT] T006: `ov_write_if_changed` writes with `cat tmp > dest` rather than `mv`. Why
  safest: `mktemp` files are mode 0600, so `mv` would silently change a target's permissions.
  `ov_init_paths` runs once when the library is sourced; it only sets variables.
- [DEFAULT] T007: a cache dir under `${TMPDIR}` that belongs to another user is never used; the
  matcher builds a private, uncached copy instead. `GIT_LITERAL_PATHSPECS` is not set
  (`check-ignore` rejects it; it already treats paths literally, verified), and git runs with
  `-C <cache>/wt` so relative paths resolve against the empty work tree. A warm call is one
  sha256 plus one `git check-ignore` (plus one `jq` in the guard): the hash finds the cache.
  Why safest: `/tmp` is shared, and a foreign git dir must not decide what is protected.
- [DEFAULT] T009: CI installs spec-kit with `uv tool install "specify-cli==1.2.0"` (the README's
  `uv tool install specify-cli`, version pinned) through `astral-sh/setup-uv@v6`. Why safest:
  it is the documented installer, pinned to the version the manifest requires.
- [DEFAULT] T013: contracts/commands.md has no description column, so each `description:` is
  written from that row's "Writes" and "Human dialogue" cells; `extension.yml` uses the same
  text. Commands with two subcommands (`srs`, `c4-context`) list each on its own line.
- [DEFAULT] T010/T015: with the event declared, `extension add` also updates
  `.specify/integrations/claude.manifest.json`, spec-kit's own file-tracking registry (it
  records `.specify/events.py` and `.claude/settings.json`). The install test allows exactly
  that file, and only if nothing else in it changed. Why safest: spec-kit writes it, ov does
  not, and the narrow check still fails on any other edit. The validator accepts
  `TODO(author)` for `author`, `repository` and `license`, with no warning; the fields are kept
  for the author to fill.
- [DEFAULT] T023: when `CLAUDE_PROJECT_DIR` and the payload `cwd` are both empty, the root falls
  back to `$PWD` (the dispatcher runs in the project root). Why safest: it protects instead of
  allowing everything.
- **Author decision 2026-10-15 (replaces the T023 matcher-error default)**: when `.aiignore`
  exists but cannot be checked (unreadable, not a regular file, a dangling symlink, or a
  matcher error), the guard denies with exit 2 and a message naming the error (fail closed).
  A missing `.aiignore` stays fail-open. The contract's decision table (guard-hook.md, row 4)
  and `tests/ov-guard.test.sh` cover it. In CI the same error fails the job (exit 2).
- [DEFAULT] T026: `diff-tree` also gets `--root`, so a root commit in the range lists its files;
  `\r` is stripped from messages before trailer matching; violations print full SHAs; usage
  and git errors exit 2. Why safest: each closes a way for an agent commit to pass unchecked.
- [DEFAULT] T027: the fetch step passes the job token through a one-command
  `http.<server>/.extraheader`. Why safest: with `persist-credentials: false`, `git fetch` fails
  on private repos; this keeps the token out of `.git/config` and still never checks out or
  runs head content.
- [DEFAULT] T028: every `--add` is validated before anything is written, and each pattern
  prints `added:` or `already listed:`. The event check runs after the copies, in the task's
  order, so an exit 1 still leaves `.aiignore` and the workflow created. Why safest: invalid
  input changes nothing, and the files left behind are inert until the guard is restored.
- [DEFAULT] T022: the workflow test also asserts that no `run:` block contains `${{` at all,
  stricter than "no head ref". Why safest: every value then reaches scripts through `env:`.
- [DEFAULT] T018: latency is measured on `ov-guard.sh` itself, as the contract says (median
  11–18 ms here). The spec-kit Python dispatcher adds interpreter start-up on top; SC-007 does
  not cover it.
- [DEFAULT] Setup (ignore files): this is a git repo, so a minimal root `.gitignore` was added
  (OS and editor cruft only; nothing here builds). It is repo tooling, not a shipped artifact,
  so Principle I's prefix rule does not apply.
Run of 2026-10-15 (Phases 5–11, stopped before T070):

- [DEFAULT] T035: the restore command prints `<source>` literally, with a note that it is the
  `extensions/ov` directory of the ov checkout (spec-kit's registry records only `local`, not
  the path). A disabled extension with no `specify` on PATH → exit 1 with
  `specify extension enable ov`. After `enable`, both checks run again. Why safest: no
  guessed path, and a failed enable is never reported as done.
- [DEFAULT] T038: a missing key or a missing `ov-config.yml` is also listed in
  `config_errors`. Step 1 checks that the three `docs/` dirs exist, as T038 lists, not their
  `.gitkeep`. Why safest: every broken config is visible, and the check matches the task.
- [DEFAULT] T043: `list` also validates module names and duplicates (not `TODO(` or `Paths:`),
  so the template's `TODO(module-name)` never reaches `ov-c4.sh` as a file name. An SRS with no
  `## Module:` section is an error. `split` prints `created:`/`updated:`/`unchanged:` per file
  and `orphan:` lines, still exiting 0. Why safest: an invalid name never becomes a path.
- [DEFAULT] T048/T053: the CONTRIBUTING template has two extra tokens, `{{OV_AUTO_MERGE_NOTE}}`
  and `{{OV_AI_REVIEW_NOTE}}`, so the FR-054 sentence appears only when auto-merge is on.
  A broken marker pair (one marker only, or out of order) → exit 1, nothing written. Why
  safest: the block never claims auto-merge when it is off, and a half-marked human file is
  never rewritten.
- [DEFAULT] T053: a flag left out keeps the current valid config value, else the default.
  Invalid JSON in `.claude/settings.json` → exit 1. In `coauthor` mode with no settings file,
  none is created. Settings are compared with `jq -S`, so a formatting-only difference is no
  rewrite. Why safest: re-running with one changed answer never resets the other two, and the
  human's settings file is never clobbered.
- [DEFAULT] T050: the auto-merge job also skips draft PRs (`draft == false`);
  `ready_for_review` catches them later. Why safest: `gh pr merge --auto` fails on drafts.
- [DEFAULT] T052: the prompt truncates the diff to 200000 bytes; `--max-turns 30`;
  `--disallowedTools` lists Bash, Edit, Write, MultiEdit, NotebookEdit, WebFetch and WebSearch
  on top of `--allowedTools "Read,Grep,Glob"`; the head fetch uses the same one-command token
  header as T027; the CLI comes from `npm install -g @anthropic-ai/claude-code` on the runner's
  Node. Why safest: bounded input and cost, and write/network tools denied twice over.
- [DEFAULT] T056: the skeleton declares real placeholder elements (`user`, `system`,
  `system.app`) rather than commented-out ones, so its views are valid DSL. Syntax checked
  against docs.structurizr.com (dsl/language, dsl/basics, dsl/includes): `!include` of a
  subdirectory file is inlined, so it works inside `model`.
- [DEFAULT] T057: lines already in the include region stay (sorted, deduplicated) even when
  their module left the SRS; `includes` refuses without `docs/workspace.dsl` (naming
  `/speckit-ov-c4-context`) and unless each marker appears exactly once, in order. Why safest:
  nothing the human or agent wrote is dropped.
- [DEFAULT] T060: spec-kit 1.2.0 has no `preset add --force`; the re-add is
  `specify preset remove ov-policy` then `specify preset add --dev`.
- [DEFAULT] T065: the bundle follows spec-kit 1.2.0's real schema: components under
  `provides.extensions` / `provides.presets`, `version` pins, preset `priority: 10`. In 1.2.0
  `source:` is a catalog name, not a path, so local sources are rejected (the R-11 risk); a
  release-URL placeholder would be read as a catalog name too, so `source:` is left out, with
  a `TODO(author)` comment to add the catalog name once ov is published. Outcome:
  `specify bundle validate` exits 0 offline, and 0 in any project where the extension and the
  preset are installed; online in this repo it exits 1, because the preset is not installed
  here and ov is in no catalog. Dev installs use `extension add` + `preset add` (R-11
  fallback). contracts/preset-bundle.md updated to match.
- [DEFAULT] T069: only the extension is dogfooded in this repo, as T069 says; the preset is
  not installed here. Why safest: installing it would change this repo's
  `/speckit-constitution` template without the author asking.
- [DEFAULT] No commits were made (commit only when the author asks). T032's dogfood files
  (`.aiignore`, `.github/workflows/ov-aiignore.yml`, `.specify/extensions/ov/`,
  `.specify/extensions.yml`, `.claude/settings.json`, `.claude/skills/speckit-ov-*`) are left
  uncommitted for a human commit.

Run of 2026-10-15 (T070, quickstart end to end; results in
[checklists/ov-quickstart-results.md](./checklists/ov-quickstart-results.md)):

- [DEFAULT] T070: headless `claude -p` in the scratch project stands in for the interactive
  session wherever a step needs no human answer (Haiku; Sonnet for two cross-checks). It ran
  with the project hooks, no MCP servers, a per-step `--allowedTools` list, Bash disallowed
  for the guard run, and never with permission bypass. Dialogue steps got their answers as
  command arguments, and the dialogue itself is handed to the author. Why safest: real Claude
  Code and real hooks, nothing can act outside the scratch dir, nothing is guessed about
  human answers.
- [DEFAULT] T070: no GitHub repo or fork was created (§4.1–4.4, §7.4). Creating them publishes
  to an external service. §4.1–4.3 were simulated with `ov-ci-aiignore.sh` on the scratch
  repo instead. Why safest: nothing outward-facing without the author.
- [DEFAULT] T070: the results file uses tables, no checkboxes. Why safest: the
  `/speckit-implement` checklist gate counts every checkbox under `checklists/`, so
  checkboxes would block or confuse future runs.
- [DEFAULT] T070 → T039 fix: Haiku dropped the per-feature group from `/speckit-ov-help` when
  steps were missing. `speckit.ov.help.md` now says to copy headings and opening sentences
  verbatim and print both groups in full before the stop. Why safest: wording only, FR-010
  unchanged.
- [DEFAULT] T070 → T056 fix: `theme default` removed from `ov-workspace.dsl`, replacing what
  T056 asked for. The theme loads from `static.structurizr.com`, which no longer resolves since
  the Structurizr cloud end of life (2026-09-30), so `structurizr validate` failed. A comment
  in the template says why. Why safest: the default look is lost, but every workspace
  validates.
- [DEFAULT] T070 → T038 fix: the constitution placeholder check now ignores HTML comments.
  `/speckit-constitution` always writes a Sync Impact Report comment naming the placeholders
  it replaced, so a valid constitution was reported "not done". The marker check still reads
  the raw file. data-model.md is updated to match. Why safest: placeholders in visible text
  still fail (3 new test cases).
- Correction to the T065 note: `specify bundle validate` takes `--path`, and it resolves
  references against the project that contains `bundle.yml`, not the cwd. `bundles/ov/bundle.yml`
  is therefore always checked against this repo (preset not installed): exit 1 online from any
  cwd. A copy inside a project with both components installed exits 0. quickstart §8 and
  contracts/preset-bundle.md are corrected.
