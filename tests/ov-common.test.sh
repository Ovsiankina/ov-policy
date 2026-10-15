#!/usr/bin/env bash
# Tests for extensions/ov/scripts/bash/ov-common.sh (T003).
set -euo pipefail
# shellcheck source-path=SCRIPTDIR
# shellcheck source=ov-test-lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/ov-test-lib.sh"

ov_t_scratch
proj=$OV_T_DIR
mkdir -p "$proj/.specify/extensions/ov/templates"
printf 'template body\n' >"$proj/.specify/extensions/ov/templates/ov-sample.txt"
printf 'authorship: coauthor\nconfigured: false\n' >"$proj/.specify/extensions/ov/ov-config.yml"

export CLAUDE_PROJECT_DIR=$proj
# shellcheck source=SCRIPTDIR/../extensions/ov/scripts/bash/ov-common.sh
source "$OV_REPO/extensions/ov/scripts/bash/ov-common.sh"

ov_t_section "paths"
assert_eq "$proj" "$OV_ROOT" "OV_ROOT follows CLAUDE_PROJECT_DIR"
# shellcheck disable=SC2153 # set by ov-common.sh
assert_eq "$proj/.specify/extensions/ov" "$OV_EXT_DIR" "OV_EXT_DIR"
assert_eq "$proj/.specify/extensions/ov/templates" "$OV_TEMPLATES" "OV_TEMPLATES"
assert_eq "$proj/.specify/extensions/ov/ov-config.yml" "$OV_CONFIG" "OV_CONFIG"

ov_t_section "ov_config_get / ov_config_set"
cfg="$proj/cfg.yml"
printf '# comment\nauthorship: coauthor\nauto_merge: off  # trailing\nquoted: "x y"\n' >"$cfg"
assert_eq "coauthor" "$(ov_config_get authorship "$cfg")" "get plain value"
assert_eq "off" "$(ov_config_get auto_merge "$cfg")" "get value with trailing comment"
assert_eq "x y" "$(ov_config_get quoted "$cfg")" "get quoted value"
assert_exit 1 ov_config_get missing "$cfg"
ov_config_set authorship trailer "$cfg"
assert_eq "trailer" "$(ov_config_get authorship "$cfg")" "set replaces the line"
assert_eq "1" "$OV_CHANGED" "set reports a change"
ov_config_set configured true "$cfg"
assert_eq "true" "$(ov_config_get configured "$cfg")" "set appends a missing key"
assert_eq "1" "$(grep -c '^authorship:' "$cfg")" "no duplicate key line"
assert_contains "$(cat "$cfg")" "# comment" "other lines kept"
before=$(ov_t_snapshot "$proj")
ov_config_set authorship trailer "$cfg"
assert_eq "0" "$OV_CHANGED" "unchanged value reports no change"
assert_eq "$before" "$(ov_t_snapshot "$proj")" "unchanged value leaves the file byte-identical"
assert_eq "coauthor" "$(ov_config_get authorship)" "default file is OV_CONFIG"

ov_t_section "ov_copy_template"
assert_exit 0 ov_copy_template ov-sample.txt deep/new/dir/copy.yml
assert_contains "$OV_T_OUT" "created: deep/new/dir/copy.yml"
assert_file "$proj/deep/new/dir/copy.yml" "creates missing parent dirs"
printf 'mine\n' >"$proj/deep/new/dir/copy.yml"
before=$(ov_t_snapshot "$proj")
assert_exit 0 ov_copy_template ov-sample.txt deep/new/dir/copy.yml
assert_contains "$OV_T_OUT" "exists, kept: deep/new/dir/copy.yml"
assert_eq "$before" "$(ov_t_snapshot "$proj")" "existing target unchanged"
assert_exit 1 ov_copy_template no-such-template x.txt

ov_t_section "ov_write_if_changed"
tmp=$(ov_tmpfile)
printf 'a\n' >"$tmp"
ov_write_if_changed "$proj/w.txt" "$tmp"
assert_eq "1" "$OV_CHANGED" "new file written"
assert_no_file "$tmp" "tmpfile consumed"
tmp=$(ov_tmpfile)
printf 'a\n' >"$tmp"
ov_write_if_changed "$proj/w.txt" "$tmp"
assert_eq "0" "$OV_CHANGED" "same content not rewritten"

ov_t_section "ov_sha256 / ov_die"
printf 'abc' >"$proj/h.txt"
assert_eq "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad" "$(ov_sha256 "$proj/h.txt")" "sha256 of abc"
assert_exit 1 ov_die "boom"
assert_eq "ov: boom" "$OV_T_ERR" "ov_die message on stderr"

ov_t_section "ov_hook_registered"
mkdir -p "$proj/.specify"
yml="$proj/.specify/extensions.yml"
cat >"$yml" <<'EOF'
installed:
- ov
settings:
  auto_execute_hooks: true
hooks:
  after_implement:
  - extension: git
    command: speckit.git.commit
    enabled: true
  - extension: ov
    command: speckit.ov.c4-code
    enabled: true
    optional: true
    priority: 10
    prompt: Update the C4 model (C3/C4) for the module just implemented?
    description: ''
    condition: null
EOF
assert_exit 0 ov_hook_registered
cat >"$yml" <<'EOF'
hooks:
    after_implement:
        -   extension: ov
            command: "speckit.ov.c4-code"
EOF
assert_exit 0 ov_hook_registered
cat >"$yml" <<'EOF'
hooks:
  after_implement:
  - extension: ov
    command: speckit.ov.c4-code
    enabled: false
EOF
assert_exit 2 ov_hook_registered
cat >"$yml" <<'EOF'
hooks:
  before_implement:
  - extension: ov
    command: speckit.ov.c4-code
  after_implement:
  - extension: git
    command: speckit.git.commit
EOF
assert_exit 1 ov_hook_registered
rm -f "$yml"
assert_exit 1 ov_hook_registered

ov_t_section "ov_event_registered"
mkdir -p "$proj/.claude"
cat >"$proj/.claude/settings.json" <<'EOF'
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
assert_exit 0 ov_event_registered
cat >"$proj/.claude/settings.json" <<'EOF'
{"hooks": {"PreToolUse": [{"matcher": "Bash", "hooks": [{"type": "command", "command": "echo hi"}]}]},
 "note": "speckit.ov.guard"}
EOF
assert_exit 1 ov_event_registered
printf 'not json' >"$proj/.claude/settings.json"
assert_exit 1 ov_event_registered
rm -f "$proj/.claude/settings.json"
assert_exit 1 ov_event_registered

ov_t_done
