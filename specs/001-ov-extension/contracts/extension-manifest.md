# Contract: `extensions/ov/extension.yml`

The manifest MUST validate under spec-kit 1.2.0 `ExtensionManifest` (no warnings) and use only
documented keys, modeled on `core_pack/extensions/git/extension.yml`.

## Required shape

| Key | Value | Spec |
|-----|-------|------|
| `schema_version` | `"1.0"` | — |
| `extension.id` | `ov` | FR-001 |
| `extension.version` | semver, starts `0.1.0` | — |
| `extension.author` / `license` / `repository` | the author's values; agent leaves `TODO(author)` | Principle VI spirit |
| `requires.speckit_version` | `">=1.2.0"` (agent events, `provides.config`) | research D-2 |
| `requires.tools` | `git` (required), `jq` (required), `gh` (optional) | R-5, R-8 |
| `provides.commands` | 8 entries, below | FR-001, FR-005 |
| `provides.config` | `{name: ov-config.yml, template: ov-config-template.yml, required: false}` | R-8 |
| `hooks.after_implement` | `{command: speckit.ov.c4-code, optional: true, prompt: "Update the C4 model (C3/C4) for the module just implemented?"}` | FR-042 |
| `events.pre_tool_use` | `{command: speckit.ov.guard, matcher: "Edit\|Write\|MultiEdit\|NotebookEdit", timeout: 10}` | FR-032, D-2 |

## Commands

| Canonical name | File | Claude skill | User-facing |
|----------------|------|--------------|-------------|
| `speckit.ov.init` | `commands/speckit.ov.init.md` | `/speckit-ov-init` | yes |
| `speckit.ov.help` | `commands/speckit.ov.help.md` | `/speckit-ov-help` | yes |
| `speckit.ov.srs` | `commands/speckit.ov.srs.md` | `/speckit-ov-srs` | yes |
| `speckit.ov.c4-context` | `commands/speckit.ov.c4-context.md` | `/speckit-ov-c4-context` | yes |
| `speckit.ov.c4-code` | `commands/speckit.ov.c4-code.md` | `/speckit-ov-c4-code` | yes |
| `speckit.ov.nogo` | `commands/speckit.ov.nogo.md` | `/speckit-ov-nogo` | yes |
| `speckit.ov.pr` | `commands/speckit.ov.pr.md` | `/speckit-ov-pr` | yes |
| `speckit.ov.guard` | `commands/speckit.ov.guard.md` | `/speckit-ov-guard` | **no**: carries `scripts.sh: scripts/bash/ov-guard.sh` for the event |

No `aliases` (D-1).

## Install-time effects (all performed by spec-kit, none by ov)

1. `.specify/extensions/ov/` = copy of `extensions/ov/` minus `.extensionignore` entries.
2. `.specify/extensions/ov/ov-config.yml` created from the template if absent.
3. `.specify/extensions.yml` gains `hooks.after_implement` → `speckit.ov.c4-code`.
4. `.claude/skills/speckit-ov-*/SKILL.md` × 8.
5. `.claude/settings.json` gains one `PreToolUse` matcher group (tagged `__speckit_event__`)
   calling `.specify/events.py speckit.ov.guard pre_tool_use …`.

`specify extension remove ov` reverses 1, 3, 4 and 5. Files that ov commands wrote into the
project (AGENTS.md, workflows, …) are project content and stay.
