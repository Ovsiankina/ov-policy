#!/usr/bin/env bash
# ov-nogo.sh (T020, FR-030, FR-032, FR-035, SC-006).
set -euo pipefail
# shellcheck source-path=SCRIPTDIR
# shellcheck source=ov-test-lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/ov-test-lib.sh"

# new_proj <dir> [with-event|no-event]: an installed copy plus settings.json.
new_proj() {
  local d=$1
  mkdir -p "$d/.claude"
  ov_t_install_copy "$d"
  if [[ ${2:-with-event} == with-event ]]; then
    cat >"$d/.claude/settings.json" <<'EOF'
{
  "permissions": {"allow": ["Bash(ls:*)"]},
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Edit|Write|MultiEdit|NotebookEdit",
        "hooks": [
          {
            "type": "command",
            "command": "python3 \"${CLAUDE_PROJECT_DIR}/.specify/events.py\" speckit.ov.guard pre_tool_use 10",
            "timeout": 15,
            "__speckit_event__": true
          }
        ]
      }
    ]
  }
}
EOF
  else
    printf '{"permissions": {"allow": ["Bash(ls:*)"]}}\n' >"$d/.claude/settings.json"
  fi
}

# shellcheck disable=SC2329 # invoked through assert_exit / ov_t_run
nogo() {
  cd "$CLAUDE_PROJECT_DIR" && .specify/extensions/ov/scripts/bash/ov-nogo.sh "$@"
}

ov_t_scratch
proj="$OV_T_DIR/proj"
new_proj "$proj"
export CLAUDE_PROJECT_DIR=$proj
settings_sha=$(_ov_t_sha256 "$proj/.claude/settings.json")

ov_t_section "first run"
assert_exit 0 nogo
assert_contains "$OV_T_OUT" "created: .aiignore"
assert_contains "$OV_T_OUT" "created: .github/workflows/ov-aiignore.yml"
assert_contains "$OV_T_OUT" "human commit" "reminds to commit as a human"
assert_file "$proj/.aiignore"
assert_file "$proj/.github/workflows/ov-aiignore.yml"
lines=$(grep -vE '^[[:space:]]*(#|$)' "$proj/.aiignore" || true)
assert_contains "$lines" ".aiignore" ".aiignore lists itself (FR-030)"
assert_contains "$lines" "docs/srs/SRS.md" "lists docs/srs/SRS.md (FR-035)"
assert_not_contains "$lines" "docs/workspace.dsl" "does not list docs/workspace.dsl (FR-035)"
assert_eq "$(<"$proj/.specify/extensions/ov/templates/ov-aiignore.yml")" \
  "$(<"$proj/.github/workflows/ov-aiignore.yml")" "workflow is the template"

ov_t_section "--add"
assert_exit 0 nogo --add src/core/
assert_eq "1" "$(grep -cxF 'src/core/' "$proj/.aiignore")" "pattern appended once"
assert_eq "src/core/" "$(tail -n 1 "$proj/.aiignore")" "appended at the end"
snap=$(ov_t_snapshot "$proj")
assert_exit 0 nogo --add src/core/
assert_eq "$snap" "$(ov_t_snapshot "$proj")" "repeating --add leaves the tree byte-identical (SC-006)"
assert_exit 0 nogo
assert_eq "$snap" "$(ov_t_snapshot "$proj")" "a plain re-run leaves the tree byte-identical"
assert_contains "$OV_T_OUT" "exists, kept: .aiignore"
assert_exit 0 nogo --add 'lib/**' --add '*.lock'
assert_eq "1" "$(grep -cxF 'lib/**' "$proj/.aiignore")" "first of two --add"
assert_eq "1" "$(grep -cxF '*.lock' "$proj/.aiignore")" "second of two --add"

ov_t_section "invalid patterns change nothing"
snap=$(ov_t_snapshot "$proj")
assert_exit 1 nogo --add ''
assert_exit 1 nogo --add $'a\nb'
assert_exit 1 nogo --add
assert_exit 1 nogo --bogus
assert_exit 1 nogo --add ok/ --add ''
assert_eq "$snap" "$(ov_t_snapshot "$proj")" "rejected arguments leave the tree unchanged"

ov_t_section "pre-existing .aiignore"
ov_t_scratch
own="$OV_T_DIR/proj"
new_proj "$own"
printf 'mine/\n' >"$own/.aiignore"
assert_exit 0 env CLAUDE_PROJECT_DIR="$own" bash -c "cd '$own' && .specify/extensions/ov/scripts/bash/ov-nogo.sh"
assert_contains "$OV_T_OUT" "exists, kept: .aiignore"
assert_eq "mine/" "$(<"$own/.aiignore")" "existing .aiignore untouched"

ov_t_section "guard event missing"
ov_t_scratch
noev="$OV_T_DIR/proj"
new_proj "$noev" no-event
assert_exit 1 env CLAUDE_PROJECT_DIR="$noev" bash -c "cd '$noev' && .specify/extensions/ov/scripts/bash/ov-nogo.sh"
assert_contains "$OV_T_ERR" "specify extension add" "restore instruction"
assert_contains "$OV_T_ERR" "--dev --force" "restore instruction uses --dev --force"
assert_eq '{"permissions": {"allow": ["Bash(ls:*)"]}}' "$(<"$noev/.claude/settings.json")" "settings.json untouched"

ov_t_section "settings.json is never modified"
assert_eq "$settings_sha" "$(_ov_t_sha256 "$proj/.claude/settings.json")" "settings.json byte-identical after every run"

ov_t_done
