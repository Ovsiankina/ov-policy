<!--
Sync Impact Report
- Version change: 1.1.0 → 1.2.0 (MINOR: Principle I exception 1 widened)
- 1.2.0 amendment (2026-10-15, author decision D-1 during /speckit-plan):
  - I. The `ov-` Prefix: exception 1 now covers command names imposed by spec-kit.
    spec-kit 1.2.0 always registers Claude extension skills as `speckit-<ext>-<cmd>`, so
    ov commands are `/speckit-ov-*`.
- 1.1.0 change: 1.0.0 → 1.1.0 (MINOR: expanded guidance in I and V)
- Amended principles:
  - I. The `ov-` Prefix: added exception for conventionally named files installed
    into target projects (AGENTS.md, CONTRIBUTING.md, .aiignore, docs/workspace.dsl)
  - V. Mechanisms Over Prose: added explicit `mechanism: review` for judgment rules
- Initial adoption (1.0.0) defined:
- Principles defined (template placeholders → concrete):
  - [PRINCIPLE_1] → I. The `ov-` Prefix
  - [PRINCIPLE_2] → II. Human-Authored Specs Are the Only Source of Truth
  - [PRINCIPLE_3] → III. Pure Extension, No Fork
  - [PRINCIPLE_4] → IV. Claude Code Is the Sole Target Integration
  - [PRINCIPLE_5] → V. Mechanisms Over Prose
  - added       → VI. Human-Owned Extension Documentation
  - added       → VII. Keep It Small
- Added sections: Scope & Constraints, Development Workflow, Governance
- Removed sections: none
- Templates: none modified (templates read the constitution at runtime)
- Deferred TODOs:
  - Principle V applies to Principles I, II and VI: the mechanisms enforcing them
    (prefix lint, protected-file hook for README.md/POLICY.md) do not exist yet.
  - Principle II conflicts with stock `/speckit-specify`, which generates spec.md;
    the `ov` workflow must define how a human-authored spec enters the pipeline.
-->
# ov Constitution

## Core Principles

### I. The `ov-` Prefix

Every artifact the project ships MUST carry the `ov` namespace: slash commands are named
`/ov-*`, or `/speckit-ov-*` where spec-kit imposes its `speckit-` prefix, and shipped files
(commands, hooks, scripts, templates, settings fragments) are named `ov-*`.
The only exceptions are:

1. command and file names whose form is imposed by spec-kit or Claude Code (e.g. the
   `/speckit-ov-*` skill names, `speckit.ov.*.md`, `extension.yml`);
2. the human-owned documents named in Principle VI;
3. files installed into target projects whose name is a convention read by other tools
   (e.g. `AGENTS.md`, `CONTRIBUTING.md`, `.aiignore`, `docs/workspace.dsl`).

Any other unprefixed file MUST be justified against one of these exceptions.

Rationale: a single prefix makes `ov` artifacts trivially distinguishable from spec-kit core
and from user files, and makes the prefix rule checkable by a script.

### II. Human-Authored Specs Are the Only Source of Truth

Humans write specifications; agents execute them. A specification produced or rewritten by an
agent MUST NOT be treated as a source of truth. Agents MAY propose changes to a spec, but a
proposal has no authority until a human has authored or explicitly accepted it.
Agent-generated artifacts (plans, tasks, code) are derived outputs and MUST trace back to a
human-authored spec.

Rationale: the purpose of `ov` is to remove ambiguity from agent work; a generated spec
reintroduces the very ambiguity spec-driven development is meant to eliminate.

### III. Pure Extension, No Fork

`ov` MUST be installable with `specify extension add ov --dev` against unmodified upstream
spec-kit. It MUST NOT require a fork, patch, or vendored copy of spec-kit, and MUST use only
the extension, preset, and bundle mechanisms spec-kit exposes.

Rationale: a fork turns every upstream release into a merge burden and prevents adoption by
anyone already using stock spec-kit.

### IV. Claude Code Is the Sole Target Integration

Claude Code is the only supported agent integration. Features MAY rely on Claude Code
specifics (hooks, settings, skills, slash commands). Support for other integrations MUST NOT
be added without a constitution amendment.

Rationale: targeting one integration allows enforcement through its real mechanisms instead
of a lowest-common-denominator abstraction.

### V. Mechanisms Over Prose

Every enforcement rule MUST ship as an executable or machine-read mechanism: a Claude Code
hook, a CI check, a git hook, or a settings file. A rule that exists only as prose in a prompt,
command, or document is incomplete and MUST NOT be described as enforced. Each rule in
POLICY.md MUST name the mechanism that enforces it.

Exception: a rule that is a human judgment call (e.g. "the owner decides type-state vs enum",
"the agent asks before touching the API boundary") and that no hook or check can evaluate
MAY declare `mechanism: review`. Its enforcer is then the constitution injected into agent
context plus the owner's review of PRs touching owned zones. POLICY.md MUST label such rules
`enforced by: constitution + owner review`. A rule MUST NOT use `mechanism: review` if an
automated check for it is feasible, and placeholder scripts that check nothing are forbidden.

Rationale: agents do not reliably follow prose; a rule that cannot fail a check is a
suggestion. Labeling judgment rules honestly as review-enforced is better than inventing
mechanisms that do nothing.

### VI. Human-Owned Extension Documentation

`README.md` (narrative) and `POLICY.md` (normative, numbered rules) are written exclusively by
the project author. Agents MUST NOT create, rewrite, or edit these two files. Agents MAY
point out inconsistencies or suggest wording in conversation or in a separate file, never by
modifying them. Per Principle V, this restriction MUST be enforced by a mechanism.

Rationale: these documents state the author's intent; they are the human source of truth
for `ov` itself, in the same sense that Principle II protects feature specs.

### VII. Keep It Small

The project ships exactly one extension manifest, a small number of commands, and no changes
to the `specify` CLI. Each new command, hook, or file MUST justify why an existing one cannot
absorb its purpose.

Rationale: a small surface is easier to audit, to keep compatible with upstream spec-kit,
and to understand fully.

## Scope & Constraints

- Distribution: a spec-kit extension, preset, and bundle, all under the `ov` name.
- Installation: `specify extension add ov --dev` is the reference install path and MUST work
  on a fresh spec-kit project.
- Integration: Claude Code only (Principle IV).
- Out of scope: modifying spec-kit core, modifying the `specify` CLI, multi-integration support.

## Development Workflow

- Features start from a human-authored spec (Principle II); agents plan, task, and implement
  from it.
- Every change that adds or alters a rule MUST include its enforcing mechanism in the same
  change (Principle V).
- Changes MUST NOT touch `README.md` or `POLICY.md` unless authored by the project author
  (Principle VI).
- Reviews MUST check new names against the `ov-` prefix rule (Principle I) and new files or
  commands against Principle VII.

## Governance

This constitution supersedes other project practices. Amendments are made by the project
author only, and each amendment MUST update the version and Last Amended date below.

Versioning follows semantic versioning:
- MAJOR: removal or redefinition of a principle.
- MINOR: a new principle or section, or materially expanded guidance.
- PATCH: clarifications and wording fixes with no semantic change.

Compliance: every plan produced by `/speckit-plan` MUST pass a constitution check against
these principles, and any justified deviation MUST be recorded in the plan's complexity
tracking. POLICY.md holds the normative, numbered rules derived from this constitution.

**Version**: 1.2.0 | **Ratified**: 2026-10-14 | **Last Amended**: 2026-10-15
