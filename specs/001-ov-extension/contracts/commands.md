# Contract: user-facing commands

Every command template follows `core_pack/extensions/git/commands/*.md`: `description:`
frontmatter, `## User Input` with `$ARGUMENTS`, and an `## Execution` section that runs its
script from `.specify/extensions/ov/scripts/bash/`. Scripts are idempotent and never overwrite
an existing target file (FR-007): they report `exists, kept: <path>` instead. Exit codes:
0 = done, 1 = refused or error with a message, 3 = needs human input (the prompt then asks).

| Skill | Script | Writes | Human dialogue | Spec |
|-------|--------|--------|----------------|------|
| `/speckit-ov-init` | `ov-init.sh` | `AGENTS.md` (from `ov-agents.md`), `docs/srs/`, `docs/srs/modules/`, `docs/c4/`, each with an empty `.gitkeep` | none | FR-008, FR-009, FR-014 |
| `/speckit-ov-help` | `ov-status.sh` | **nothing** | none | FR-010–FR-013 |
| `/speckit-ov-srs` | `ov-srs.sh template` / `ov-srs.sh split` | `docs/srs/SRS.md` (template), `docs/srs/modules/*.md` | walks the human through each template section; the human writes the text | FR-020–FR-023 |
| `/speckit-ov-c4-context` | `ov-c4.sh skeleton` / `ov-c4.sh includes` | `docs/workspace.dsl`, `!include` lines | builds C1/C2 with the human | FR-040 |
| `/speckit-ov-c4-code` | `ov-c4.sh includes` | `docs/c4/<module>.dsl` (one module) | asks which module if not given | FR-041, FR-042 |
| `/speckit-ov-nogo` | `ov-nogo.sh` | `.aiignore`, `.github/workflows/ov-aiignore.yml` | asks which paths to add | FR-030–FR-033 |
| `/speckit-ov-pr` | `ov-pr.sh` | `ov-config.yml`, `CONTRIBUTING.md`, `.github/ov-ruleset-main.json`, optional `ov-ai-review.yml`, `ov-automerge.yml`, `.claude/settings.json` `attribution.commit` (trailer mode only) | 3 questions (authorship `coauthor`\|`trailer`, auto-merge, ai_review) | FR-050–FR-058 |

## Per-command specifics

- **`/speckit-ov-init`**:
  - verifies the ov `after_implement` entry in `.specify/extensions.yml` and the ov
    `PreToolUse` event in `.claude/settings.json`;
  - if either is disabled it runs `specify extension enable ov`; if either is absent it prints
    `specify extension add <source> --dev --force` and exits 1 (FR-009);
  - `AGENTS.md` states the Bash-write gap (FR-014) and contains, verbatim, "ov enforces
    autonomous agent loops. Augmented coding (human asks, human approves each edit) is
    outside its scope and reviewed manually by the owner." (FR-015).
- **`/speckit-ov-help`**:
  - `ov-status.sh` prints JSON with one entry per once-per-project step (data-model table) and
    exits 0 even when steps are missing;
  - the prompt renders both groups in this order, one sentence each. Each group opens with one
    sentence saying why the split exists (FR-010). For example: once-per-project steps set up
    the policy and the architecture skeleton that every feature relies on; per-module steps
    repeat for each unit of work and trace back to that setup.
    - once per project: `/speckit-ov-init`, `/speckit-ov-srs`, `/speckit-ov-c4-context`,
      `/speckit-ov-nogo`, `/speckit-constitution`, `/speckit-ov-pr`;
    - once per module or feature: `/speckit-specify`, `/speckit-clarify`, `/speckit-plan`,
      `/speckit-tasks`, `/speckit-implement`, `/speckit-converge`, `/speckit-ov-c4-code`, PR;
  - if any step is missing it names them with the producing command and stops (FR-011). It
    never runs a step itself.
- **`/speckit-ov-srs`**:
  - the agent never writes SRS prose;
  - it reads each section's guidance to the human and waits for the human to edit the file;
  - it runs `split` only after the human confirms (Principle II).
- **`/speckit-ov-pr`**:
  - `ov-pr.sh --authorship coauthor|trailer --auto-merge Y --ai-review W` is
    non-interactive; the prompt gathers the answers first (defaults `coauthor`, `off`, `on`);
  - the `CONTRIBUTING.md` block states that a commit is an agent commit only when it carries
    an agent trailer, whatever its branch (FR-051);
  - re-running with new answers rewrites only ov-owned files: config, ruleset and workflows it
    installed. `CONTRIBUTING.md` is only rewritten between `<!-- ov:pr:begin -->` and
    `<!-- ov:pr:end -->` markers;
  - switching from `trailer` to `coauthor` removes the `attribution.commit` key that ov
    set, and touches no other settings.
