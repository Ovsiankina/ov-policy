# Data Model: ov

**Feature**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Date**: 2026-10-15

Everything is a file in the target project. Below, "owner" is the command whose script creates
the file, and "writer" is who edits it afterwards.

## Entities

### SRS (master): `docs/srs/SRS.md`

- **Owner**: `/speckit-ov-srs` copies `templates/ov-srs.md` (FR-006, FR-007: never overwrites).
- **Writer**: the human only (Principle II). Listed in the default `.aiignore`.
- **Structure** (grammar in [contracts/srs-format.md](./contracts/srs-format.md)):
  - shared sections: `## Purpose`, `## Scope`;
  - one `## Module: <name>` section per module (`<name>` matches `^[a-z0-9][a-z0-9-]*$`)
    containing `Paths:`, `### Responsibility`, `### Inputs`, `### Outputs`, `### Invariants`,
    `### Acceptance Tests`.
- **Validation**: module names unique; every module has a non-empty `Paths:` line; the
  template's `TODO(` placeholders must be gone before the split runs.

### Module spec: `docs/srs/modules/<name>.md`

- **Owner/writer**: `ov-srs.sh split` only (generated, FR-021).
- **Fields**: line 1 `<!-- GENERATED from SRS.md, do not edit -->` (FR-022), then the shared
  sections, then that module's section verbatim, `Paths:` included.
- **Relationship**: exactly one per `## Module:` section. A module file with no matching
  section is an **orphan**: reported, never deleted (Scenario 4.3).

### Read-only list: `.aiignore`

- **Owner**: `/speckit-ov-nogo` copies `templates/ov-aiignore`.
- **Writer**: the human. Lists itself (FR-030).
- **Format**: gitignore syntax, evaluated by git's matcher (research R-4).
- **Default entries**: `.aiignore`, `.claude/settings.json`, `.github/workflows/ov-*.yml`,
  `.github/ov-ruleset-main.json`, `.specify/extensions/ov/**`, `docs/srs/SRS.md` (FR-035).
  `docs/workspace.dsl` is **not** listed (shared, FR-040).
- **Readers**: guard (working-tree copy), CI check (base-branch copy).

### ov config: `.specify/extensions/ov/ov-config.yml`

- **Owner**: spec-kit `provides.config` copies `ov-config-template.yml` at install.
- **Writer**: `/speckit-ov-pr` (via `ov-pr.sh`), the human.
- **Format**: flat `key: value`, no nesting.

| Key | Values | Default | Read by |
|-----|--------|---------|---------|
| `authorship` | `coauthor` \| `trailer` | `coauthor` | `ov-pr.sh` (sets or removes `attribution.commit`), CONTRIBUTING.md |
| `auto_merge` | `on` \| `off` | `off` | `ov-pr.sh` (installs/removes `ov-automerge.yml`) |
| `ai_review` | `on` \| `off` | `on` | `ov-pr.sh` (workflow + ruleset), CI |
| `configured` | `true` \| `false` | `false` | `/speckit-ov-help` (FR-012: set by `/speckit-ov-pr`) |

- **Validation**: unknown values make `ov-pr.sh` exit non-zero, and `/speckit-ov-help`
  reports them.

### Workspace model: `docs/workspace.dsl` + `docs/c4/<name>.dsl`

- **Owner**: `/speckit-ov-c4-context` copies `templates/ov-workspace.dsl`.
  `/speckit-ov-c4-code` writes `docs/c4/<name>.dsl`.
- **Writers**: `workspace.dsl` is **shared**: the human and the agent may both edit it
  (C1/C2), and it is not in the default `.aiignore`. `docs/c4/<name>.dsl` is generated per
  module (C3/C4).
- **Relationship**: `workspace.dsl` holds one `!include c4/<name>.dsl` per SRS module.
  `ov-c4.sh includes` adds any missing include lines idempotently.

### Constitution marker

- `POLICY.md` (ov repo, human) starts with `<!-- ov-policy -->`. Its marker section also holds
  the FR-015 scope sentence, written by the author. `presets/ov-policy/templates/ov-policy.md`
  is its byte-for-byte copy (R-10). The preset prepends it to `constitution-template`.
- `/speckit-constitution` is **done** when `.specify/memory/constitution.md` contains
  `<!-- ov-policy -->` and no `[ALL_CAPS_IDENTIFIER]` placeholder outside HTML comments
  (FR-012). The Sync Impact Report comment that `/speckit-constitution` writes names the
  placeholders it replaced, so comment text is not checked.

### Agent commit (CI classification, computed)

- **Inputs**: the commit message only. Branch names play no role (agent branch prefix removed
  2026-10-15). Applies to every PR, forks included.
- **Rule** (FR-031, FR-034): `agent = message matches (?i)^co-authored-by:.*claude
  OR message matches ^Assisted-by: claude-code$`.
- **Violation**: (agent commit, path) where the path is touched by that commit
  (`diff-tree --no-renames`) and matches the base-branch `.aiignore`.

## Project setup state (read by `/speckit-ov-help`)

Once-per-project steps in order. Each step is *done* when its check holds (FR-012):

| # | Step | Done when |
|---|------|-----------|
| 1 | `/speckit-ov-init` | `AGENTS.md` exists; `docs/srs/`, `docs/srs/modules/`, `docs/c4/` exist (each with an empty `.gitkeep`, so a fresh clone keeps them); `.specify/extensions.yml` has the ov `after_implement` hook; `.claude/settings.json` has the ov PreToolUse event |
| 2 | `/speckit-ov-srs` | `docs/srs/SRS.md` exists |
| 3 | `/speckit-ov-c4-context` | `docs/workspace.dsl` exists |
| 4 | `/speckit-ov-nogo` | `.aiignore` exists, the PreToolUse event is registered, `.github/workflows/ov-aiignore.yml` exists |
| 5 | `/speckit-constitution` | constitution has the marker and no placeholders |
| 6 | `/speckit-ov-pr` | `ov-config.yml` has `configured: true`, `CONTRIBUTING.md` exists, `.github/ov-ruleset-main.json` exists |

`/speckit-ov-help` never changes state (FR-013). It prints the full order and lists every
step that isn't done. If any step is missing, it refuses to continue past the listing (FR-011).
Steps are reported independently, so re-running an earlier step never invalidates a later one.
