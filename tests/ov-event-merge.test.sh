#!/usr/bin/env bash
# spec-kit merges the ov PreToolUse event into an existing settings.json
# without clobbering it, and does not duplicate it (T021, FR-033).
set -euo pipefail
# shellcheck source-path=SCRIPTDIR
# shellcheck source=ov-test-lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/ov-test-lib.sh"

ov_t_have_specify || ov_t_skip "specify is not on PATH"

ov_t_scratch
proj="$OV_T_DIR/proj"
(cd "$OV_T_DIR" && specify init proj --integration claude >/dev/null 2>&1)
mkdir -p "$proj/.claude"
cat >"$proj/.claude/settings.json" <<'EOF'
{
  "permissions": {"allow": ["Bash(npm test:*)"]},
  "hooks": {
    "PreToolUse": [
      {"matcher": "Bash", "hooks": [{"type": "command", "command": "echo seeded-bash-hook"}]}
    ]
  }
}
EOF
settings="$proj/.claude/settings.json"
matcher="Edit|Write|MultiEdit|NotebookEdit"

# shellcheck disable=SC2329 # invoked through assert_exit / ov_t_run
in_proj() {
  cd "$proj" && "$@"
}

seeded_intact() {
  assert_eq "Bash(npm test:*)" "$(jq -r '.permissions.allow[0] // ""' "$settings")" "$1: permissions.allow kept"
  assert_eq "1" "$(jq '[.hooks.PreToolUse[]? | select(.matcher == "Bash") | .hooks[]? | select(.command == "echo seeded-bash-hook")] | length' "$settings")" \
    "$1: seeded Bash group kept"
}
ov_groups() {
  jq --arg m "$matcher" '[.hooks.PreToolUse[]? | select(.matcher == $m)] | length' "$settings"
}
ov_commands() {
  jq '[.hooks.PreToolUse[]? | .hooks[]? | select(.command | contains("speckit.ov.guard"))] | length' "$settings"
}

ov_t_section "extension add --dev"
assert_exit 0 in_proj specify extension add "$OV_REPO/extensions/ov" --dev
seeded_intact "after add"
assert_eq "1" "$(ov_groups)" "exactly one $matcher group"
assert_eq "1" "$(ov_commands)" "exactly one ov guard command"

ov_t_section "extension add --dev --force"
assert_exit 0 in_proj specify extension add "$OV_REPO/extensions/ov" --dev --force
seeded_intact "after re-add"
assert_eq "1" "$(ov_groups)" "still one $matcher group"
assert_eq "1" "$(ov_commands)" "still one ov guard command"

ov_t_section "extension remove"
assert_exit 0 in_proj specify extension remove ov --force
assert_file "$settings" "settings.json kept (it holds other entries)"
seeded_intact "after remove"
assert_eq "0" "$(ov_groups)" "ov group gone"
assert_eq "0" "$(ov_commands)" "ov guard command gone"

ov_t_done
