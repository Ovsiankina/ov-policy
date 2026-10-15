# Contract: SRS format and split

## `docs/srs/SRS.md` (human-written, from `templates/ov-srs.md`)

```text
# <System name>: Software Requirements Specification
## Purpose
## Scope
## Module: <name>            # one per module; <name> = ^[a-z0-9][a-z0-9-]*$, unique
Paths: <glob> [<glob> ...]   # gitignore syntax, space-separated, required
### Responsibility
### Inputs
### Outputs
### Invariants
### Acceptance Tests
```

- Sections before the first `## Module:` heading are **shared**.
- The template's guidance text is wrapped in `TODO(…)` markers. `ov-srs.sh split` refuses to
  run while any `TODO(` remains.

## `ov-srs.sh split` behavior

| Situation | Result |
|-----------|--------|
| valid SRS | writes `docs/srs/modules/<name>.md` per module: line 1 `<!-- GENERATED from SRS.md, do not edit -->`, then the shared sections, then the module section verbatim |
| unchanged SRS | output byte-identical (SC-006) |
| duplicate module name / missing `Paths:` / bad name | exit 1, names the line, writes nothing |
| `modules/<x>.md` with no `## Module: x` | reported as orphan, left in place |
| `docs/srs/SRS.md` missing | exit 1: "run /speckit-ov-srs to start from the template" |

Writing is all-or-nothing: the script writes into a temp dir and only then moves files into
place.
