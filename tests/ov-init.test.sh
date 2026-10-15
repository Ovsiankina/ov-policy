#!/usr/bin/env bash
# ov-init.sh (T033, FR-006, FR-008, FR-009, FR-014, FR-015, Scenarios 8.1, 8.3,
# SC-006).
set -euo pipefail
# shellcheck source-path=SCRIPTDIR
# shellcheck source=ov-test-lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/ov-test-lib.sh"

scope="ov enforces autonomous agent loops. Augmented coding (human asks, human approves each edit) is outside its scope and reviewed manually by the owner."

write_hook() { # write_hook <dir> <enabled>
  mkdir -p "$1/.specify"
  cat >"$1/.specify/extensions.yml" <<EOF
installed:
- ov
hooks:
  after_implement:
  - extension: ov
    command: speckit.ov.c4-code
    enabled: $2
    optional: true
EOF
}
write_event() { # write_event <dir>
  mkdir -p "$1/.claude"
  cat >"$1/.claude/settings.json" <<'EOF'
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
}
new_proj() { # new_proj <dir>: installed copy with the hook and the event
  mkdir -p "$1"
  ov_t_install_copy "$1"
  write_hook "$1" true
  write_event "$1"
}
# shellcheck disable=SC2329 # invoked through assert_exit / ov_t_run
init_in() {
  cd "$1" && CLAUDE_PROJECT_DIR=$1 .specify/extensions/ov/scripts/bash/ov-init.sh
}

ov_t_scratch
proj="$OV_T_DIR/proj"
new_proj "$proj"

ov_t_section "first run"
assert_exit 0 init_in "$proj"
assert_contains "$OV_T_OUT" "created: AGENTS.md"
assert_file "$proj/AGENTS.md"
for d in docs/srs docs/srs/modules docs/c4; do
  assert_file "$proj/$d/.gitkeep" "$d/.gitkeep exists"
  assert_eq "0" "$(wc -c <"$proj/$d/.gitkeep" | tr -d ' ')" "$d/.gitkeep is empty"
done

ov_t_section "AGENTS.md content"
agents=$(<"$proj/AGENTS.md")
if grep -qF "$scope" "$proj/AGENTS.md"; then
  _ov_t_ok "FR-015 scope sentence, verbatim (grep -F)"
else
  _ov_t_bad "FR-015 scope sentence, verbatim (grep -F)"
fi
assert_contains "$agents" "Bash" "states the Bash gap (FR-014)"
assert_contains "$agents" "ov-aiignore" "names the CI backstop (FR-014)"
assert_contains "$agents" "Read is never blocked" "Read is allowed"
assert_contains "$agents" "/speckit-ov-help" "points to /speckit-ov-help"
assert_not_contains "$agents" "README.md" "does not mention README.md"
assert_not_contains "$agents" "POLICY.md" "does not mention POLICY.md"

ov_t_section "second run is a no-op (Scenario 8.3, SC-006)"
snap=$(ov_t_snapshot "$proj")
assert_exit 0 init_in "$proj"
assert_contains "$OV_T_OUT" "exists, kept: AGENTS.md"
assert_eq "$snap" "$(ov_t_snapshot "$proj")" "tree byte-identical"

ov_t_section "existing AGENTS.md and populated docs/ dirs"
ov_t_scratch
own="$OV_T_DIR/proj"
new_proj "$own"
printf 'my agents file\n' >"$own/AGENTS.md"
mkdir -p "$own/docs/srs"
printf 'notes\n' >"$own/docs/srs/notes.md"
assert_exit 0 init_in "$own"
assert_eq "my agents file" "$(<"$own/AGENTS.md")" "pre-existing AGENTS.md untouched"
assert_file "$own/docs/srs/.gitkeep" "a dir with files still gets its .gitkeep"
assert_eq "notes" "$(<"$own/docs/srs/notes.md")" "other files in it untouched"

ov_t_section "missing hook or event (FR-009)"
ov_t_scratch
nohook="$OV_T_DIR/proj"
new_proj "$nohook"
rm -f "$nohook/.specify/extensions.yml"
assert_exit 1 init_in "$nohook"
assert_contains "$OV_T_ERR" "specify extension add <source> --dev --force" "restore command for the hook"
ov_t_scratch
noevent="$OV_T_DIR/proj"
new_proj "$noevent"
rm -f "$noevent/.claude/settings.json"
assert_exit 1 init_in "$noevent"
assert_contains "$OV_T_ERR" "specify extension add <source> --dev --force" "restore command for the event"

ov_t_section "disabled entry → specify extension enable ov"
ov_t_scratch
dis="$OV_T_DIR/proj"
new_proj "$dis"
write_hook "$dis" false
rm -f "$dis/.claude/settings.json" # spec-kit drops the event on disable
mkdir -p "$OV_T_DIR/bin"
log="$OV_T_DIR/specify.log"
# Stub: records its arguments and does what `extension enable` does.
cat >"$OV_T_DIR/bin/specify" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"$log"
if [[ "\$*" == "extension enable ov" ]]; then
  sed -i.bak 's/enabled: false/enabled: true/' .specify/extensions.yml && rm -f .specify/extensions.yml.bak
  mkdir -p .claude
  cp "$proj/.claude/settings.json" .claude/settings.json
fi
EOF
chmod +x "$OV_T_DIR/bin/specify"
assert_exit 0 env PATH="$OV_T_DIR/bin:$PATH" bash -c "cd '$dis' && CLAUDE_PROJECT_DIR='$dis' .specify/extensions/ov/scripts/bash/ov-init.sh"
assert_eq "extension enable ov" "$(cat "$log" 2>/dev/null || true)" "specify extension enable ov invoked"
assert_contains "$OV_T_OUT" "specify extension enable ov" "reports the enable"
: >"$log"
write_hook "$dis" false
# Stub that does not fix anything: still refused afterwards.
cat >"$OV_T_DIR/bin/specify" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"$log"
EOF
assert_exit 1 env PATH="$OV_T_DIR/bin:$PATH" bash -c "cd '$dis' && CLAUDE_PROJECT_DIR='$dis' .specify/extensions/ov/scripts/bash/ov-init.sh"
assert_eq "extension enable ov" "$(cat "$log")" "enable attempted"
assert_contains "$OV_T_ERR" "specify extension add <source> --dev --force" "restore command when enable did not help"

ov_t_done
