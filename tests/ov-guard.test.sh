#!/usr/bin/env bash
# PreToolUse guard against contracts/guard-hook.md (T017, Scenarios 2.1, 2.3,
# 2.5, 2c, SC-003, SC-005).
set -euo pipefail
# shellcheck source-path=SCRIPTDIR
# shellcheck source=ov-test-lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/ov-test-lib.sh"

fixtures="$OV_REPO/tests/fixtures"
deny_msg="is read-only for agents (listed in .aiignore)"

ov_t_scratch
proj="$OV_T_DIR/proj"
mkdir -p "$proj"
ov_t_install_copy "$proj"
printf '.aiignore\nsrc/core/\n' >"$proj/.aiignore"
guard="$proj/.specify/extensions/ov/scripts/bash/ov-guard.sh"
ov_t_scratch
payloads=$OV_T_DIR

export CLAUDE_PROJECT_DIR=$proj

# payload <fixture> <cwd> <path>: print the path of a filled-in payload file.
n=0
payload() {
  local body
  body=$(<"$fixtures/ov-guard-$1.json")
  body=${body//__ROOT__/$2}
  body=${body//__PATH__/$3}
  n=$((n + 1))
  printf '%s\n' "$body" >"$payloads/p$n.json"
  printf '%s\n' "$payloads/p$n.json"
}

# shellcheck disable=SC2329 # invoked through assert_exit / ov_t_run
run_guard() {
  "$guard" <"$1"
}

snap=""
# check <exit> <fixture> <cwd> <path> [label]: run the guard, check the exit
# code and that the project tree did not change.
check() {
  local want=$1 fx=$2 cwd=$3 path=$4 label=${5:-"$2 $4"} p
  p=$(payload "$fx" "$cwd" "$path")
  ov_t_run run_guard "$p"
  if [[ $OV_T_RC == "$want" ]]; then
    _ov_t_ok "exit $want: $label"
  else
    _ov_t_bad "exit $want: $label" "got exit $OV_T_RC" "stderr: $OV_T_ERR"
  fi
  if [[ $want == 2 ]]; then
    assert_contains "$OV_T_ERR" "$deny_msg" "deny reason: $label"
  fi
  [[ -n $snap ]] || snap=$(ov_t_snapshot "$proj")
  assert_eq "$snap" "$(ov_t_snapshot "$proj")" "tree unchanged: $label"
}

ov_t_section "decision table, per tool"
snap=$(ov_t_snapshot "$proj")
for tool in edit write multiedit notebookedit; do
  check 2 "$tool" "$proj" "$proj/src/core/x.rs" "$tool listed src/core/x.rs"
  check 0 "$tool" "$proj" "$proj/src/main.rs" "$tool unlisted src/main.rs"
  check 0 "$tool" "$proj" "/etc/hosts" "$tool outside /etc/hosts"
  check 0 "$tool" "$proj" "$proj/../x" "$tool outside __ROOT__/../x"
done
p=$(payload edit "$proj" "$proj/src/core/x.rs")
ov_t_run run_guard "$p"
assert_contains "$OV_T_ERR" "ov: src/core/x.rs is read-only for agents (listed in .aiignore). Ask the human to change it." "exact deny message with the relative path"

ov_t_section "no .aiignore"
ov_t_scratch
bare="$OV_T_DIR/proj"
mkdir -p "$bare"
ov_t_install_copy "$bare"
for tool in edit write multiedit notebookedit; do
  p=$(payload "$tool" "$bare" "$bare/src/core/x.rs")
  ov_t_run env CLAUDE_PROJECT_DIR="$bare" "$bare/.specify/extensions/ov/scripts/bash/ov-guard.sh" <"$p"
  assert_eq "0" "$OV_T_RC" "$tool allowed without .aiignore"
done
p=$(payload edit "$bare" "$bare/src/core/x.rs")
ov_t_run env CLAUDE_PROJECT_DIR="$bare" TMPDIR=/nonexistent/ov "$bare/.specify/extensions/ov/scripts/bash/ov-guard.sh" <"$p"
assert_eq "0" "$OV_T_RC" "no .aiignore stays fail-open even when the matcher cannot run"

ov_t_section "matcher errors fail closed (author decision 2026-10-15)"
p=$(payload edit "$proj" "$proj/src/main.rs")
ov_t_run env TMPDIR=/nonexistent/ov "$guard" <"$p"
assert_eq "2" "$OV_T_RC" "matcher cannot build its cache: denied"
assert_contains "$OV_T_ERR" "ov: cannot check src/main.rs against .aiignore, denying the call (fail closed)" "deny message"
assert_contains "$OV_T_ERR" "cannot build the .aiignore matcher under /nonexistent/ov" "message names the error"
ov_t_run env TMPDIR=/nonexistent/ov "$guard" <"$(payload edit "$proj" "/etc/hosts")"
assert_eq "0" "$OV_T_RC" "paths outside the project stay allowed"
ov_t_scratch
broken="$OV_T_DIR/proj"
mkdir -p "$broken/.aiignore"
p=$(payload write "$broken" "$broken/src/main.rs")
ov_t_run env CLAUDE_PROJECT_DIR="$broken" "$guard" <"$p"
assert_eq "2" "$OV_T_RC" ".aiignore that is a directory: denied"
assert_contains "$OV_T_ERR" "patterns file not readable" "message names the unreadable .aiignore"
rm -rf "$broken/.aiignore"
ln -s "$broken/missing-target" "$broken/.aiignore"
ov_t_run env CLAUDE_PROJECT_DIR="$broken" "$guard" <"$p"
assert_eq "2" "$OV_T_RC" "dangling .aiignore symlink: denied"
if [[ $(id -u) != 0 ]]; then
  rm -f "$broken/.aiignore"
  printf 'src/\n' >"$broken/.aiignore"
  chmod 000 "$broken/.aiignore"
  ov_t_run env CLAUDE_PROJECT_DIR="$broken" "$guard" <"$p"
  assert_eq "2" "$OV_T_RC" "unreadable .aiignore: denied"
  chmod 644 "$broken/.aiignore"
fi

ov_t_section "malformed and no-path payloads fail open"
ov_t_run run_guard "$(payload malformed "$proj" "$proj/src/core/x.rs")"
assert_eq "0" "$OV_T_RC" "malformed payload allowed"
assert_contains "$OV_T_ERR" "ov:" "malformed payload warns"
ov_t_run run_guard "$(payload nopath "$proj" "")"
assert_eq "0" "$OV_T_RC" "no-path payload allowed"
assert_contains "$OV_T_ERR" "ov:" "no-path payload warns"
ov_t_run run_guard /dev/null
assert_eq "0" "$OV_T_RC" "empty stdin allowed"

ov_t_section ".aiignore protects itself (Scenario 2.3)"
for tool in edit write multiedit; do
  check 2 "$tool" "$proj" "$proj/.aiignore" "$tool .aiignore"
done

ov_t_section "relative paths and the root fallback"
check 2 edit "$proj/src" "core/x.rs" "relative path resolved against the payload cwd"
check 0 edit "$proj/src" "main.rs" "relative unlisted path"
check 2 edit "$proj" "$proj/src/./lib/../core/x.rs" "dot segments normalised"
check 0 edit "$proj" "$proj/src/core/../x.rs" "dotdot leaving the listed dir"
p=$(payload edit "$proj" "src/core/x.rs")
ov_t_run env -u CLAUDE_PROJECT_DIR "$guard" <"$p"
assert_eq "2" "$OV_T_RC" "without CLAUDE_PROJECT_DIR the root is the payload cwd"
p=$(payload edit "$proj" "$proj/src/main.rs")
ov_t_run env -u CLAUDE_PROJECT_DIR "$guard" <"$p"
assert_eq "0" "$OV_T_RC" "without CLAUDE_PROJECT_DIR an unlisted path is allowed"

ov_t_section "default template (FR-035)"
ov_t_scratch
dflt="$OV_T_DIR/proj"
mkdir -p "$dflt"
ov_t_install_copy "$dflt"
if [[ -f $dflt/.specify/extensions/ov/templates/ov-aiignore ]]; then
  cp "$dflt/.specify/extensions/ov/templates/ov-aiignore" "$dflt/.aiignore"
  for rel in docs/srs/SRS.md .aiignore .claude/settings.json .github/workflows/ov-aiignore.yml \
    .github/ov-ruleset-main.json .specify/extensions/ov/ov-config.yml; do
    p=$(payload edit "$dflt" "$dflt/$rel")
    ov_t_run env CLAUDE_PROJECT_DIR="$dflt" "$dflt/.specify/extensions/ov/scripts/bash/ov-guard.sh" <"$p"
    assert_eq "2" "$OV_T_RC" "default template denies $rel"
  done
  p=$(payload edit "$dflt" "$dflt/docs/workspace.dsl")
  ov_t_run env CLAUDE_PROJECT_DIR="$dflt" "$dflt/.specify/extensions/ov/scripts/bash/ov-guard.sh" <"$p"
  assert_eq "0" "$OV_T_RC" "default template allows docs/workspace.dsl (shared)"
else
  _ov_t_bad "templates/ov-aiignore exists"
fi

ov_t_section "mode-independent"
cfg="$proj/.specify/extensions/ov/ov-config.yml"
sed -i.bak 's/^authorship:.*/authorship: trailer/' "$cfg"
rm -f "$cfg.bak"
snap=$(ov_t_snapshot "$proj")
check 2 edit "$proj" "$proj/src/core/x.rs" "listed path with authorship: trailer"
check 0 edit "$proj" "$proj/src/main.rs" "unlisted path with authorship: trailer"

ov_t_section "through the real spec-kit dispatcher"
if ov_t_have_specify; then
  ov_t_scratch
  (cd "$OV_T_DIR" && specify init sk --integration claude >/dev/null 2>&1)
  sk="$OV_T_DIR/sk"
  (cd "$sk" && specify extension add "$OV_REPO/extensions/ov" --dev >/dev/null 2>&1) || true
  printf '.aiignore\nsrc/core/\n' >"$sk/.aiignore"
  cmd=$(jq -r '[.hooks.PreToolUse[]? | .hooks[]? | select(.command | contains("speckit.ov.guard")) | .command][0] // ""' \
    "$sk/.claude/settings.json" 2>/dev/null || true)
  if [[ -n $cmd ]]; then
    # The hook command is a shell string that expands ${CLAUDE_PROJECT_DIR}
    # itself, so it must reach bash unexpanded.
    p=$(payload edit "$sk" "$sk/src/core/x.rs")
    # shellcheck disable=SC2016 # expanded by the inner bash
    ov_t_run env CLAUDE_PROJECT_DIR="$sk" OV_CMD="$cmd" OV_P="$p" bash -c 'cd "$CLAUDE_PROJECT_DIR" && eval "$OV_CMD" <"$OV_P"'
    assert_eq "2" "$OV_T_RC" "dispatcher propagates exit 2"
    assert_contains "$OV_T_ERR" "$deny_msg" "dispatcher propagates the deny reason"
    p=$(payload edit "$sk" "$sk/src/main.rs")
    # shellcheck disable=SC2016 # expanded by the inner bash
    ov_t_run env CLAUDE_PROJECT_DIR="$sk" OV_CMD="$cmd" OV_P="$p" bash -c 'cd "$CLAUDE_PROJECT_DIR" && eval "$OV_CMD" <"$OV_P"'
    assert_eq "0" "$OV_T_RC" "dispatcher allows an unlisted path"
  else
    _ov_t_bad "ov PreToolUse command found in .claude/settings.json"
  fi
else
  printf '  skip  specify not on PATH: dispatcher run skipped\n'
fi

ov_t_done
