# Contract: PreToolUse guard (`scripts/bash/ov-guard.sh`)

Invoked by spec-kit's dispatcher for the `pre_tool_use` event (matcher
`Edit|Write|MultiEdit|NotebookEdit`). The cwd is the project root, and `CLAUDE_PROJECT_DIR`
is set.

## Input (stdin, Claude Code PreToolUse JSON)

| Field | Used |
|-------|------|
| `tool_name` | `Edit`, `Write`, `MultiEdit` → path from `tool_input.file_path`; `NotebookEdit` → `tool_input.notebook_path` |
| `cwd` | fallback project root if `CLAUDE_PROJECT_DIR` is unset |

## Decision table (first match wins)

| # | Condition | Exit | stderr |
|---|-----------|------|--------|
| 1 | stdin unparsable or path field missing | 0 | warning (fail-open, never wedges the session) |
| 2 | path resolves outside the project root | 0 | — |
| 3 | `.aiignore` missing | 0 | — |
| 4 | `.aiignore` exists but cannot be checked (unreadable, not a file, matcher error) | 2 | `ov: cannot check <path> against .aiignore, denying the call (fail closed): <error>. Ask the human to fix it.` (author decision 2026-10-15) |
| 5 | relative path matches `.aiignore` (R-4) | 2 | `ov: <path> is read-only for agents (listed in .aiignore). Ask the human to change it.` |
| 6 | otherwise | 0 | — |

The guard reads only `.aiignore`. It never reads `ov-config.yml`, so it behaves the same in
every authorship mode.

- `Read`, `Grep`, `Glob` and `Bash` never reach the guard (matcher). Bash writes are an accepted
  gap (FR-014).
- Latency budget: median ≤ 200 ms (SC-007). A warm call is one `jq` plus one
  `git check-ignore`; the temp git dir is cached per `.aiignore` content hash under
  `${TMPDIR:-/tmp}`.
- Never writes to the project.

## Tests (`tests/ov-guard.test.sh`)

Feed recorded JSON payloads for each tool × {listed, unlisted, outside project, no .aiignore}
and assert the exit code and stderr substring. Also run once through the real
`.specify/events.py` in a scratch project, so that exit 2 is known to propagate.

## Latency test (`tests/ov-guard-latency.test.sh`)

Run the guard 50 times on a listed-path payload, with `.aiignore` holding the default entries
plus 20 patterns, and the cache warmed by one discarded run. Fail if the median wall-clock
time is above 200 ms. Print the median, p90 and max.
