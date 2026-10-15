#!/usr/bin/env bash
# Re-running every once-per-project script leaves the tree byte-identical
# (T066, SC-006).
set -euo pipefail
# shellcheck source-path=SCRIPTDIR
# shellcheck source=ov-test-lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/ov-test-lib.sh"

ov_t_scratch
p="$OV_T_DIR/proj"
ov_t_git_init "$p"
ov_t_install_copy "$p"
mkdir -p "$p/.claude"
cat >"$p/.specify/extensions.yml" <<'EOF'
installed:
- ov
hooks:
  after_implement:
  - extension: ov
    command: speckit.ov.c4-code
    enabled: true
    optional: true
EOF
cat >"$p/.claude/settings.json" <<'EOF'
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Edit|Write|MultiEdit|NotebookEdit",
        "hooks": [
          {"type": "command", "command": "python3 \"${CLAUDE_PROJECT_DIR}/.specify/events.py\" speckit.ov.guard pre_tool_use 10", "timeout": 15, "__speckit_event__": true}
        ]
      }
    ]
  }
}
EOF
export CLAUDE_PROJECT_DIR=$p
bin="$p/.specify/extensions/ov/scripts/bash"

# shellcheck disable=SC2329 # invoked through assert_exit / ov_t_run
in_proj() {
  cd "$p" && "$@"
}
run_all() {
  assert_exit 0 in_proj "$bin/ov-init.sh"
  assert_exit 0 in_proj "$bin/ov-srs.sh" template
  assert_exit 0 in_proj "$bin/ov-c4.sh" skeleton
  assert_exit 0 in_proj "$bin/ov-nogo.sh" --add src/core/
  assert_exit 0 in_proj "$bin/ov-pr.sh" --authorship coauthor --auto-merge off --ai-review on
}

ov_t_section "first run"
run_all
snap=$(ov_t_snapshot "$p")
for f in AGENTS.md docs/srs/SRS.md docs/workspace.dsl .aiignore .github/workflows/ov-aiignore.yml \
  CONTRIBUTING.md .github/ov-ruleset-main.json .github/workflows/ov-ai-review.yml; do
  assert_file "$p/$f" "first run wrote $f"
done

ov_t_section "second run"
run_all
assert_eq "$snap" "$(ov_t_snapshot "$p")" "tree byte-identical after the second run (SC-006)"

ov_t_done
