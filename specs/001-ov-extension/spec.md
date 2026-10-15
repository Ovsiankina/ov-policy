# Feature Specification: ov spec-kit extension, preset and bundle

**Feature Branch**: `001-ov-extension` [ADDED: no git branch created; no branch hook is installed]

**Created**: 2026-10-14

**Status**: Accepted by the project author on 2026-10-15, with four edits (see Review log)

**Input**: User description (source of truth, see "Source of Truth" below).

## Source of Truth

This spec is **derived**. The author's feature description is the source of truth (Constitution
Principle II). Wherever this file and the description disagree, the description wins. Every
statement not present in the description is marked **[ADDED]**. Unmarked statements restate the
description.

**Command naming (author decision D-1, 2026-10-15)**: spec-kit 1.2.0 registers every Claude
extension skill as `speckit-<ext>-<cmd>`. Throughout this spec, `/ov-<cmd>` stands for the
Claude Code skill **`/speckit-ov-<cmd>`** (canonical command id `speckit.ov.<cmd>`).
Constitution 1.2.0, Principle I exception 1, allows this.

## Upstream Facts Verified [ADDED]

These facts come from the spec-kit reference pages and the installed `specify` 1.2.0 source.
They constrain the requirements below.

- F-1: Extension command names MUST match `speckit.<extension>.<command>`; anything else is
  auto-renamed or rejected. Commands MAY declare free-form `aliases`.
- F-2: Presets compose templates through a priority stack (project overrides > presets >
  extensions > core) using `replace`, `prepend`, `append` or `wrap`.
- F-3: The public docs do not describe an extension installing files at the project root
  (CI workflows, `.claude/settings.json`, `AGENTS.md`), and they barely mention bundles.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Install ov into a fresh project (Priority: P1)

A developer creates a spec-kit project for Claude Code and adds `ov` from a local checkout.
All `/ov-*` commands become available in Claude Code.

**Why this priority**: [ADDED] Nothing else works until installation does.

**Independent Test**: Run `specify init scratch --integration claude && specify extension add
ov --dev`; open Claude Code in `scratch`; every `/ov-*` command is listed.

**Acceptance Scenarios**:

1. **Given** a fresh project from `specify init scratch --integration claude`, **When** the
   developer runs `specify extension add ov --dev`, **Then** the command succeeds.
2. **Given** ov is installed, **When** the developer opens Claude Code, **Then** `/ov-init`,
   `/ov-help`, `/ov-srs`, `/ov-c4-context`, `/ov-c4-code`, `/ov-nogo` and `/ov-pr` all appear,
   as `/speckit-ov-init` … `/speckit-ov-pr` (D-1).
3. [ADDED] **Given** ov is installed, **When** installation finishes, **Then** no spec-kit file
   outside spec-kit's documented extension/preset locations has been patched (Principle III).

---

### User Story 2 - Protect paths from agent edits (Priority: P1)

The human runs `/ov-nogo`. It creates `.aiignore` (gitignore syntax) listing read-only paths
for the agent, and makes sure that (a) a Claude Code PreToolUse hook in `.claude/settings.json`
denies Edit/Write/MultiEdit/NotebookEdit on matching paths (registered by spec-kit at
`extension add`, verified by `/ov-nogo`; D-2) and (b) a CI workflow that fails a PR if an
agent commit touches a path matching `.aiignore` as read from the base branch.
`.aiignore` lists itself. Listed paths are read-only: Read is never blocked.

**Why this priority**: [ADDED] This is the main enforcement mechanism (Principle V), and the
acceptance criteria test it directly.

**Independent Test**: List a path in `.aiignore`; ask Claude Code to edit it (blocked); open a
PR with an agent commit that changes it (CI fails).

**Acceptance Scenarios**:

1. **Given** `.aiignore` lists `src/core/**`, **When** the agent attempts Edit, Write,
   MultiEdit or NotebookEdit on `src/core/x.rs`, **Then** the hook denies the call.
2. **Given** the same `.aiignore` on the base branch, **When** a PR on any branch contains a
   commit carrying the trailer `Co-Authored-By: Claude <noreply@anthropic.com>` that touches
   `src/core/x.rs`, **Then** the CI check fails.
2a. **Given** a PR from a branch named `ai/demo`, **When** a commit without an agent trailer
   touches `src/core/x.rs`, **Then** the CI check passes: branch names play no role (FR-031).
2b. **Given** a PR, **When** a human commit without an agent trailer touches `src/core/x.rs`
   and agent commits in the same PR touch only unlisted paths, **Then** the CI check passes.
2c. **Given** `.aiignore` lists `src/core/**`, **When** the agent Reads `src/core/x.rs`,
   **Then** the read is allowed.
2d. **Given** a PR from a fork, **When** an agent commit touches `src/core/x.rs`, **Then** the
   CI check fails, exactly as for a same-repo PR.
3. **Given** `.aiignore` lists itself, **When** the agent tries to edit `.aiignore`, **Then**
   the hook denies it.
4. [ADDED] **Given** an agent commit in a PR adds a new pattern to `.aiignore` and also
   changes a file only that new pattern matches, **When** CI runs, **Then** the check uses the
   base branch's `.aiignore` and fails because `.aiignore` itself changed.
5. [ADDED] **Given** the agent attempts an edit on a path not listed, **When** the hook runs,
   **Then** the edit proceeds.

---

### User Story 3 - Know the order and refuse to skip steps (Priority: P2)

The human runs `/ov-help` and sees the command order with one sentence per command, split into
"once per project" (`/ov-init`, `/ov-srs`, `/ov-c4-context`, `/ov-nogo`, `/speckit-constitution`,
`/ov-pr`)
and "once per module or feature" (`/speckit-specify`, clarify, plan, tasks, implement, converge,
`/ov-c4-code`, PR). If a once-per-project step is missing from the repo, it refuses to proceed.
`/ov-help` is read-only and can be rerun any number of times.

**Why this priority**: [ADDED] It guides the workflow but enforces nothing on its own.

**Independent Test**: Run `/ov-help` in a repo missing `docs/srs/SRS.md`; it names the missing
step and refuses.

**Acceptance Scenarios**:

1. **Given** all once-per-project steps are present, **When** `/ov-help` runs, **Then** it
   prints both groups in order with one sentence each.
2. **Given** a once-per-project step is missing, **When** `/ov-help` runs, **Then** it refuses
   to proceed and [ADDED] names each missing step and the command that produces it.
3. **Given** any repo state, **When** `/ov-help` runs any number of times, **Then** no file in
   the repo is created, modified or deleted.

---

### User Story 8 - Initialize the project (Priority: P1)

The human runs `/ov-init` as the first once-per-project command. It writes `AGENTS.md` and the
`docs/` skeleton, and registers the spec-kit hooks.

**Why this priority**: [ADDED] Every other once-per-project step builds on what it writes.

**Independent Test**: Run `/ov-init` in a fresh project with ov installed; `AGENTS.md` and the
`docs/` skeleton exist, the spec-kit hooks are registered, and `/ov-help` reports `/ov-init`
as done.

**Acceptance Scenarios**:

1. **Given** a fresh project with ov installed, **When** `/ov-init` runs, **Then** `AGENTS.md`
   and the `docs/` skeleton exist and the spec-kit hooks (including `after_implement` →
   `/ov-c4-code`) are registered.
2. **Given** `/ov-init` has not run, **When** `/ov-help` runs, **Then** it reports `/ov-init` as
   missing and refuses to proceed.
3. [ADDED] **Given** `/ov-init` already ran, **When** it runs again, **Then** it changes nothing
   and overwrites no existing file (FR-007).

---

### User Story 4 - Write the SRS and derive module specs (Priority: P2)

The human runs `/ov-srs`. It guides them through writing `docs/srs/SRS.md` from a trimmed
IEEE-830-style template (purpose, scope, per-module responsibility, inputs/outputs, invariants,
acceptance tests). It then generates `docs/srs/modules/<module>.md` for each module from the
master. Every generated file starts with the header "GENERATED from SRS.md, do not edit".

**Why this priority**: [ADDED] The SRS is the human-authored source of truth that later steps
trace back to (Principle II).

**Independent Test**: Write a two-module SRS; run `/ov-srs`; two module files exist, each with
the header and only its module's content.

**Acceptance Scenarios**:

1. **Given** no `docs/srs/SRS.md`, **When** `/ov-srs` runs, **Then** it walks the human through
   the template sections; [ADDED] the human writes the content and the agent does not author
   section bodies.
2. **Given** a completed `SRS.md` with modules A and B, **When** generation runs, **Then**
   `docs/srs/modules/A.md` and `B.md` exist with the GENERATED header.
3. [ADDED] **Given** a module is removed from `SRS.md`, **When** generation reruns, **Then**
   the orphaned module file is reported, not silently kept as if current.

---

### User Story 5 - C4 architecture model (Priority: P3)

`/ov-c4-context` builds C1 (system context) and C2 (container) with the human in
`docs/workspace.dsl` (Structurizr DSL), which `!include`s `docs/c4/<module>.dsl` per module.
`/ov-c4-code` generates or updates C3 (component) and C4 (code) for ONE module into
`docs/c4/<module>.dsl` and is registered as an `after_implement` hook.

**Why this priority**: [ADDED] Useful documentation, but no enforcement depends on it.

**Independent Test**: Run `/ov-c4-context`, then run `/speckit-implement` on one module; that
module's `.dsl` is created or updated and is included from `workspace.dsl`.

**Acceptance Scenarios**:

1. **Given** no `docs/workspace.dsl`, **When** `/ov-c4-context` runs, **Then** C1 and C2 are
   built with the human and an `!include` exists for each module.
2. **Given** an implemented module, **When** `/speckit-implement` completes, **Then** the
   `after_implement` hook offers or runs `/ov-c4-code` for that module only.
3. [ADDED] **Given** `docs/c4/<module>.dsl` exists, **When** `/ov-c4-code` runs for another
   module, **Then** the first file is unchanged.

---

### User Story 6 - PR and authorship policy (Priority: P2)

The human runs `/ov-pr`, which asks three questions and records the answers in
`CONTRIBUTING.md` and config:

- Authorship mode:
  - `coauthor` (default);
  - `trailer`: commits carry "Assisted-by: claude-code".
- Auto-merge on green: default off; when on, `gh pr merge --auto` on same-repo PRs once checks
  pass. PRs from forks are never auto-merged.
- AI review (`ai_review`): `on` (default) or `off`.

There is no agent branch prefix: a commit is an agent commit only when it carries an agent
trailer (FR-034), on every branch.

It also generates a GitHub ruleset template for `main`: PRs required, direct push blocked,
0 required approvals, required checks: the aiignore check, plus the AI review against the module
SRS when `ai_review: on`.

**Why this priority**: [ADDED] It makes authorship and merge policy explicit and enforced.

**Independent Test**: Run `/ov-pr` choosing `trailer`; let Claude Code commit (the message
carries `Assisted-by: claude-code`); inspect `CONTRIBUTING.md`, the config and the ruleset
template.

**Acceptance Scenarios**:

1. **Given** the human accepts all defaults, **When** `/ov-pr` finishes, **Then**
   `CONTRIBUTING.md` and config record `coauthor`, auto-merge off and `ai_review: on`.
2. **Given** mode `trailer`, **When** the agent commits, **Then** the message carries
   `Assisted-by: claude-code` instead of `Co-Authored-By: Claude <...>`.
3. **Given** auto-merge on, **When** a same-repo PR's checks pass, **Then** it is set to merge
   automatically.
3a. **Given** auto-merge on, **When** a PR comes from a fork, **Then** it is never set to merge
   automatically.
4. **Given** `/ov-pr` finished, **Then** a ruleset template for `main` exists with the listed
   rules.
5. *Removed 2026-10-15: there is no branch prefix.*
6. **Given** `ai_review: off`, **When** `/ov-pr` finishes, **Then** the ruleset template does not
   list the AI review as a required check.
7. **Given** `ai_review: on` and no API key secret, **When** a same-repo PR's checks run,
   **Then** the AI review fails loudly.
8. **Given** `/ov-pr` finished, **Then** `CONTRIBUTING.md` states that a commit counts as an
   agent commit only when it carries an agent trailer, whatever its branch.
9. **Given** `ai_review: on`, **When** a PR comes from a fork, **Then** the AI review reports
   pass-with-skip.

---

### User Story 7 - Constitution always carries POLICY.md (Priority: P3)

The preset `ov-policy` prepends POLICY.md to the constitution template, so
`/speckit-constitution` cannot drop it.

**Why this priority**: [ADDED] It protects the policy text but depends on POLICY.md, which the
author has not written yet.

**Independent Test**: Install the preset; run `/speckit-constitution`; the resolved template
starts with POLICY.md's content.

**Acceptance Scenarios**:

1. **Given** the preset is installed, **When** the constitution template is resolved, **Then**
   POLICY.md's content comes first, followed by the core template.
1a. **Given** POLICY.md's first line is `<!-- ov-policy -->`, **When** `/speckit-constitution`
   writes the constitution, **Then** the marker is present, and `/ov-help` uses it to count
   the step as done (FR-012).
2. [ADDED] **Given** POLICY.md changes in the ov source, **When** the preset is re-added,
   **Then** the resolved template reflects the new text.

---

### Edge Cases [ADDED]

- `.aiignore` missing or empty: the hook allows all edits and the CI check passes, but
  `/ov-help` reports `/ov-nogo` as missing.
- A path the agent edits through Bash (e.g. `sed -i`) rather than Edit/Write/MultiEdit/NotebookEdit: the
  author accepts this gap. The hook covers those three tools only; the CI check is the
  backstop, and `AGENTS.md` states this (FR-014).
- A human commit (no agent trailer) touching a listed path: allowed, see FR-031.
- The user runs `/speckit-constitution` before the preset is installed: POLICY.md is absent from
  the constitution, the `<!-- ov-policy -->` marker is missing, and `/ov-help` reports
  `/speckit-constitution` as not done (FR-012).
- A Claude Code `.claude/settings.json` already exists with other hooks: `/ov-nogo` must merge
  its hook, not overwrite the file.
- Re-running any once-per-project command: it must not duplicate hooks, workflows or config
  entries.

## Requirements *(mandatory)*

### Functional Requirements

**Packaging**

- **FR-001**: An extension `ov` with one `extension.yml` MUST provide the commands `/ov-init`,
  `/ov-help`, `/ov-srs`, `/ov-c4-context`, `/ov-c4-code`, `/ov-nogo` and `/ov-pr`, surfaced
  in Claude Code as `/speckit-ov-<cmd>` (D-1).
- **FR-002**: A preset `ov-policy` MUST prepend POLICY.md to the constitution template.
- **FR-003**: A bundle `ov` MUST contain the extension and the preset.
- **FR-004**: `specify init scratch --integration claude && specify extension add ov --dev`
  MUST succeed.
- **FR-005**: Each command MUST have the canonical name `speckit.ov.<cmd>`, which spec-kit
  registers as the Claude Code skill `/speckit-ov-<cmd>`. No wrapper skills, aliases or plugin
  are added to produce `/ov-*` names (D-1). [ADDED] One internal command,
  `speckit.ov.guard`, exists only to carry the PreToolUse guard script (FR-032); it is not
  part of the user workflow and `/ov-help` does not list it.
- **FR-006**: Project files MUST be installed into target projects: `AGENTS.md`,
  `CONTRIBUTING.md`, a `docs/workspace.dsl` skeleton, a `docs/srs/SRS.md` template and an
  `.aiignore` template. (Q3 answer: C) They ship under `.specify/extensions/ov/templates/` and
  are copied into place by the command that owns each one:
  - `AGENTS.md` and the `docs/` skeleton (folders `docs/srs/`, `docs/srs/modules/`,
    `docs/c4/`, each holding an empty `.gitkeep` so git tracks it): `/ov-init`
  - `docs/srs/SRS.md` template: `/ov-srs`
  - `docs/workspace.dsl` skeleton: `/ov-c4-context`
  - `.aiignore`: `/ov-nogo`
  - `CONTRIBUTING.md`: `/ov-pr`
- **FR-007** [ADDED]: A command MUST NOT overwrite an existing target file when copying a
  template; it reports the conflict and leaves the file as is.

**/ov-init**

- **FR-008**: `/ov-init` MUST be the first once-per-project command. It MUST write `AGENTS.md`
  and the `docs/` skeleton and MUST register the spec-kit hooks.
- **FR-009** [ADDED]: Registering hooks MUST go through spec-kit's own hook registry
  (`.specify/extensions.yml`), not a patched spec-kit file (Principle III). If installing
  the extension already registers its hooks, `/ov-init` verifies them and re-registers any
  that are missing.
- **FR-014**: `AGENTS.md` MUST state that the `.aiignore` hook does not cover writes made through
  Bash, and that the CI check is the backstop for that gap.
- **FR-015**: The `AGENTS.md` template MUST contain, verbatim: "ov enforces autonomous agent loops. Augmented coding (human asks, human approves each edit) is outside its scope and reviewed manually by the owner."
  The same sentence belongs in POLICY.md's marker section, which the author writes
  (Principle VI).

**/ov-help**

- **FR-013**: `/ov-help` MUST be read-only: it MUST NOT create, modify or delete any file, and
  rerunning it MUST be safe.
- **FR-010**: MUST print the command order in two groups with one sentence per command, using
  exactly the grouping in the description. Each group MUST open with one sentence explaining
  why the split exists: what "once per project" and "once per module or feature" each cover.
- **FR-011**: MUST refuse to proceed if any once-per-project step is missing from the repo.
- **FR-012**: A step counts as present when its artifact exists: `AGENTS.md`, the three
  `docs/` folders and the registered hooks (`/ov-init`); `docs/srs/SRS.md` (`/ov-srs`);
  `docs/workspace.dsl` (`/ov-c4-context`); `.aiignore` plus the registered PreToolUse hook and
  the CI workflow (`/ov-nogo`); a constitution that contains the `<!-- ov-policy -->` marker and no
  template placeholders (`/speckit-constitution`); the `/ov-pr` config (`/ov-pr`).

**/ov-srs**

- **FR-020**: MUST guide the human to write `docs/srs/SRS.md` from a template containing:
  purpose, scope, per-module responsibility, inputs/outputs, invariants, acceptance tests.
  Each module section MUST also have a `Paths:` line of gitignore-syntax globs naming the
  code that belongs to the module (author decision, 2026-10-15).
- **FR-021**: MUST generate `docs/srs/modules/<module>.md` per module from the master.
- **FR-022**: Each generated file MUST carry the header "GENERATED from SRS.md, do not edit".
- **FR-023** [ADDED]: Generated module files are derived artifacts; the agent MUST NOT author
  SRS content (Principle II).

**/ov-nogo**

- **FR-030**: MUST create `.aiignore` (gitignore syntax) and MUST list `.aiignore` in it.
- **FR-035**: The default `.aiignore` template MUST list `docs/srs/SRS.md`. It MUST NOT list
  `docs/workspace.dsl`, which is shared and agent-editable (FR-040).
- **FR-031**: MUST install a CI workflow that checks a PR against `.aiignore` read from the base
  branch, evaluated **per commit**. The check fails only if an agent commit touches a listed
  path. A commit is an agent commit if and only if it carries an agent trailer (FR-034).
  Branch names play no role. Other commits in the same PR MAY touch listed paths. The check
  applies to all PRs, including PRs from forks. (Q2 answer: C, refined at acceptance; branch
  prefix removed 2026-10-15.)
- **FR-034**: Agent trailers are a line matching `co-authored-by:.*claude`, case-insensitive
  (Claude Code writes `Co-Authored-By: Claude <...>`), or the `trailer`-mode line
  `Assisted-by: claude-code`.
- **FR-032**: A PreToolUse hook in `.claude/settings.json` MUST deny Edit, Write, MultiEdit
  and NotebookEdit on matching paths. Read MUST never be blocked: listed paths are read-only,
  not hidden. The hook is declared as a spec-kit agent event in `extension.yml`, so spec-kit
  installs it at `extension add` and removes it at `extension remove`. `/ov-nogo` verifies that
  it is registered and reports how to restore it if not (D-2). Until `.aiignore` exists the
  hook allows everything. The guard is active in every authorship mode and depends only on
  `.aiignore`.
- **FR-033** [ADDED]: The hook MUST be merged into an existing `.claude/settings.json` without
  removing existing entries, and re-installing MUST NOT duplicate it (spec-kit's event merge
  provides this; tests verify it).

**/ov-c4-context and /ov-c4-code**

- **FR-040**: `/ov-c4-context` MUST build C1 and C2 with the human in `docs/workspace.dsl`
  (Structurizr DSL), which `!include`s `docs/c4/<module>.dsl` per module. `docs/workspace.dsl`
  is shared: the human and the agent may both edit it.
- **FR-041**: `/ov-c4-code` MUST generate or update C3 and C4 for exactly one module in
  `docs/c4/<module>.dsl`.
- **FR-042**: `/ov-c4-code` MUST be registered as an `after_implement` hook.

**/ov-pr**

- **FR-050**: MUST ask three questions: authorship mode (`coauthor` | `trailer`), auto-merge on
  green and AI review, with defaults `coauthor`, off and `ai_review: on`.
- **FR-051**: MUST record the answers in `CONTRIBUTING.md` and config. `CONTRIBUTING.md` MUST
  state that a commit is an agent commit only when it carries an agent trailer (FR-034),
  whatever its branch (FR-031).
- **FR-052**: Mode `trailer` MUST produce the trailer "Assisted-by: claude-code".
- **FR-053**: *Removed 2026-10-15.* The `branch` authorship mode, its commit-msg hook, the
  `core.hooksPath` setup and the off-prefix guard logic are dropped. The agent branch prefix
  (`branch_prefix`) is dropped as well: no ov rule depends on a branch name.
- **FR-054**: Auto-merge on MUST cause `gh pr merge --auto` on same-repo PRs when checks
  pass. PRs from forks MUST NOT be auto-merged.
- **FR-055**: MUST generate a GitHub ruleset template for `main`: PRs required, direct push
  blocked, 0 required approvals, required checks: aiignore check, plus AI review against
  the module SRS only when `ai_review: on`; when `off`, the ruleset MUST NOT list it as
  required. (Q1 answer: A) The AI review is a CI job that runs Claude Code against the
  `docs/srs/modules/<module>.md` file(s) for the modules a PR touches, and it requires an API
  key secret in the repository.
- **FR-056**: When `ai_review: on` and the API key secret is missing, the AI review job MUST
  fail loudly, with a message naming the missing secret, never pass silently. Because it is a
  required check, this blocks merges until the key is configured or `ai_review` is set to
  `off`.
- **FR-058**: On PRs from forks, the AI review job MUST run and report pass-with-skip: it
  succeeds with a notice that fork PRs are not AI-reviewed, and never passes the API key or
  runs the model on fork content. The fork check comes before the key check (FR-056).
- **FR-057**: The AI review maps changed files to modules by matching each file against the
  module's `Paths:` globs (FR-020). Files matching no module are reviewed against the shared
  SRS sections only.

**Constitution compliance** [ADDED]

- **FR-060**: Every shipped command and file MUST follow the `ov-` prefix rule or one of its
  exceptions (Principle I).
- **FR-061**: No `/ov-*` command may create or modify the ov repo's own `README.md` or
  `POLICY.md` (Principle VI).

### Key Entities

- **SRS (master)**: the human-written `docs/srs/SRS.md`; the source of truth for modules.
- **Module spec**: the generated `docs/srs/modules/<module>.md`, derived from the SRS.
- **`.aiignore`**: gitignore-syntax list of paths that are read-only for the agent.
- **ov config**: [ADDED: location unspecified in the description; decided in the plan] the
  authorship mode, auto-merge flag and `ai_review`.
- **Workspace model**: `docs/workspace.dsl` plus the per-module `docs/c4/<module>.dsl` files.
- **POLICY.md**: the author-written normative rules, prepended to the constitution template.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: `specify init scratch --integration claude && specify extension add ov --dev`
  exits successfully on a fresh project.
- **SC-002**: All 7 user-facing commands appear in Claude Code after install, as `/speckit-ov-*`.
- **SC-003**: An Edit on a listed path is blocked by the `/ov-nogo` hook.
- **SC-004**: The CI check fails a PR touching a listed path.
- **SC-005** [ADDED]: Write, MultiEdit, NotebookEdit and the self-protection of `.aiignore` are each blocked
  (Scenarios 2.1 and 2.3).
- **SC-006** [ADDED]: Re-running every once-per-project command a second time leaves the repo
  byte-identical, apart from intended answer changes.
- **SC-007**: The guard's median latency over 50 runs is at most 200 ms. The latency test fails
  above that.

## Assumptions [ADDED]

- POLICY.md does not exist yet; the author writes it (Principle VI) and starts it with the
  marker line `<!-- ov-policy -->`. The preset is built and tested against a placeholder
  POLICY.md supplied by the author, which also starts with the marker. The author adds the
  FR-015 scope sentence to POLICY.md's marker section.
- "Config" in `/ov-pr` means a version-controlled file under `.specify/extensions/ov/`, the
  location spec-kit documents for extension config (F-3).
- The GitHub ruleset is a template file the human applies; ov does not call the GitHub API to
  apply it.
- Bundle packaging follows whatever `specify bundle` in spec-kit 1.2.0 supports; the format is
  settled in the plan.

## Open Questions

### Clarifications — Session 2026-10-14

- Q1: What runs the "AI review against the module SRS" check? → A: a CI job running Claude
  Code against the module SRS, using an API key secret.
- Q2: Which PRs does the aiignore CI check cover? → C: `<prefix>*` branches plus any PR with
  agent-trailer commits. *Superseded 2026-10-15: the prefix is gone; every PR is checked and
  agent commits are identified by trailer only.*
- Q3: When do the project files land? → C: shipped under `.specify/extensions/ov/templates/`,
  copied by the owning command.

### Review log

- Review 2026-10-14: FR-006 assignment of `AGENTS.md` to `/ov-help` rejected → new `/ov-init`
  (FR-008); `/ov-help` read-only (FR-013). FR-056 accepted with the `ai_review` option.
- Review 2026-10-14 (2): FR-009 accepted. `docs/` skeleton = empty folders only; `SRS.md`
  stays with `/ov-srs`, `workspace.dsl` with `/ov-c4-context`; FR-012 checks file existence.
- Acceptance 2026-10-15, with four edits: (1) FR-031 evaluated per commit; (2) trailer match
  `co-authored-by:.*claude`, case-insensitive (FR-034, FR-053); (3) Read never blocked
  (FR-032); (4) POLICY.md starts with `<!-- ov-policy -->`, and FR-012 checks the marker plus
  no placeholders. Bash bypass accepted as a known gap, documented in `AGENTS.md` (FR-014).
- Plan decisions 2026-10-15: D-1 accept `/speckit-ov-*` names (FR-001, FR-005; constitution
  1.2.0); D-2 hook installed as a spec-kit event, verified by `/ov-nogo` (FR-032, FR-033);
  NotebookEdit added to the guard (FR-032); SRS module `Paths:` line added (FR-020, FR-057).
- Plan review 2026-10-15:
  - (1) forks: `ov-ai-review` reports pass-with-skip (FR-058); `ov-aiignore` covers all PRs,
    forks included (FR-031, Scenario 2d);
  - (2) `branch` authorship mode removed (FR-053 removed; FR-050 is `coauthor` | `trailer`);
    the prefix stays independent, and the guard is active in every mode;
  - (3) `docs/workspace.dsl` is shared and not in the default `.aiignore` (FR-035, FR-040);
  - (4) `docs/srs/SRS.md` stays in the default `.aiignore` (FR-035);
  - fixes: guard latency test (SC-007); `/ov-help` explains the split (FR-010);
    CONTRIBUTING.md prefix statement (FR-051); scope sentence in AGENTS.md (FR-015).
- Author decisions 2026-10-15 (during `/speckit-tasks`):
  - (1) the branch-based approach is scrapped completely. There is no agent branch prefix;
    a commit is an agent commit only when it carries an agent trailer, on every branch
    (FR-031, FR-050, FR-051, FR-053; Scenarios 2.2, 2a, 2b, 2.4, 6.1, 6.5, 6.8);
  - (2) auto-merge applies to same-repo PRs only; fork PRs are never auto-merged (FR-054,
    Scenarios 6.3, 6.3a);
  - (3) each `docs/` skeleton folder gets an empty `.gitkeep` so git tracks it (FR-006);
  - (4) during `/speckit-implement`, ambiguities are resolved with the safest default and
    recorded as `[DEFAULT]` in the Notes of `tasks.md`, without asking the author.
