#!/usr/bin/env bash
# Shared helper for tests/ov-*.test.sh. Source it, never run it.
#
#   source "$(dirname "${BASH_SOURCE[0]}")/ov-test-lib.sh"
#   ov_t_scratch; proj=$OV_T_DIR
#   assert_exit 0 some command
#   ov_t_done
#
# Scratch dirs live under ${TMPDIR:-/tmp} and are removed on exit.

OV_REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
export OV_REPO

# Keep the user's git config out of every test (identity, signing, hooks).
export GIT_CONFIG_NOSYSTEM=1
export GIT_CONFIG_GLOBAL=/dev/null

_OV_T_PASS=0
_OV_T_FAIL=0
_OV_T_DIRS=()

# Output of the last assert_exit / ov_t_run.
OV_T_OUT=""
OV_T_ERR=""
OV_T_RC=0

_ov_t_cleanup() {
  local d
  for d in "${_OV_T_DIRS[@]+"${_OV_T_DIRS[@]}"}"; do
    [[ -n $d && -d $d ]] && rm -rf "$d"
  done
  return 0
}
trap _ov_t_cleanup EXIT

_ov_t_tmp() {
  local t=${TMPDIR:-/tmp}
  printf '%s' "${t%/}"
}

# ov_t_scratch: new empty dir in OV_T_DIR, removed on exit.
# Call it directly (not in $(...)), so the cleanup list survives.
ov_t_scratch() {
  OV_T_DIR=$(mktemp -d "$(_ov_t_tmp)/ov-test.XXXXXX")
  OV_T_DIR=$(cd "$OV_T_DIR" && pwd -P)
  _OV_T_DIRS+=("$OV_T_DIR")
}

# ov_t_git_init <dir>: git repo on branch main with a local test identity.
ov_t_git_init() {
  local dir=$1
  mkdir -p "$dir"
  git -C "$dir" init -q
  git -C "$dir" symbolic-ref HEAD refs/heads/main
  git -C "$dir" config user.name "ov test"
  git -C "$dir" config user.email "ov-test@example.invalid"
  git -C "$dir" config commit.gpgsign false
}

# ov_t_install_copy <dir>: simulate `specify extension add` without specify.
ov_t_install_copy() {
  local dir=$1 ext
  ext="$dir/.specify/extensions/ov"
  mkdir -p "$dir/.specify/extensions"
  rm -rf "$ext"
  cp -R "$OV_REPO/extensions/ov" "$ext"
  if [[ ! -e $ext/ov-config.yml ]]; then
    cp "$ext/ov-config-template.yml" "$ext/ov-config.yml"
  fi
}

ov_t_have_specify() {
  command -v specify >/dev/null 2>&1
}

# ov_t_skip <reason>: skip the whole test file.
ov_t_skip() {
  printf 'SKIP: %s\n' "$*"
  exit 0
}

ov_t_section() {
  printf '\n== %s\n' "$*"
}

_ov_t_ok() {
  _OV_T_PASS=$((_OV_T_PASS + 1))
  printf '  ok    %s\n' "$1"
}

_ov_t_bad() {
  _OV_T_FAIL=$((_OV_T_FAIL + 1))
  printf '  FAIL  %s\n' "$1"
  shift
  local line
  for line in "$@"; do
    printf '        %s\n' "$line"
  done
}

# ov_t_run <cmd…>: run a command (in a subshell, so a function that exits
# cannot end the test), keep its stdout/stderr/exit code.
ov_t_run() {
  local out err
  out=$(mktemp "$(_ov_t_tmp)/ov-test-out.XXXXXX")
  err=$(mktemp "$(_ov_t_tmp)/ov-test-err.XXXXXX")
  set +e
  ("$@") >"$out" 2>"$err"
  OV_T_RC=$?
  set -e
  OV_T_OUT=$(cat "$out")
  OV_T_ERR=$(cat "$err")
  rm -f "$out" "$err"
}

# assert_eq <expected> <actual> [label]
assert_eq() {
  local label=${3:-"expected '$1'"}
  if [[ $1 == "$2" ]]; then
    _ov_t_ok "$label"
  else
    _ov_t_bad "$label" "expected: $1" "actual:   $2"
  fi
}

# assert_exit <code> <cmd…>: run the command, compare its exit code.
assert_exit() {
  local want=$1
  shift
  ov_t_run "$@"
  if [[ $OV_T_RC == "$want" ]]; then
    _ov_t_ok "exit $want: $*"
  else
    _ov_t_bad "exit $want: $*" "got exit $OV_T_RC" "stdout: ${OV_T_OUT:0:600}" "stderr: ${OV_T_ERR:0:600}"
  fi
}

# assert_contains <haystack> <needle> [label]
assert_contains() {
  local label=${3:-"contains '$2'"}
  if [[ $1 == *"$2"* ]]; then
    _ov_t_ok "$label"
  else
    _ov_t_bad "$label" "missing: $2" "in: ${1:0:600}"
  fi
}

# assert_not_contains <haystack> <needle> [label]
assert_not_contains() {
  local label=${3:-"does not contain '$2'"}
  if [[ $1 != *"$2"* ]]; then
    _ov_t_ok "$label"
  else
    _ov_t_bad "$label" "unexpected: $2" "in: ${1:0:600}"
  fi
}

assert_file() {
  if [[ -f $1 ]]; then
    _ov_t_ok "${2:-file exists: $1}"
  else
    _ov_t_bad "${2:-file exists: $1}"
  fi
}

assert_no_file() {
  if [[ ! -e $1 ]]; then
    _ov_t_ok "${2:-no file: $1}"
  else
    _ov_t_bad "${2:-no file: $1}"
  fi
}

_ov_t_sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -d' ' -f1
  else
    shasum -a 256 "$1" | cut -d' ' -f1
  fi
}

# ov_t_snapshot <dir>: sorted "<path> <sha256>" per file and "<path>/ dir" per
# directory, .git excluded. Compare two snapshots to prove a tree is unchanged.
ov_t_snapshot() {
  local root=$1 p
  (
    cd "$root" || exit 1
    find . -path ./.git -prune -o \( -type d -o -type f -o -type l \) -print | LC_ALL=C sort |
      while IFS= read -r p; do
        if [[ -L $p ]]; then
          printf '%s -> %s\n' "$p" "$(readlink "$p")"
        elif [[ -d $p ]]; then
          printf '%s/ dir\n' "$p"
        else
          printf '%s %s\n' "$p" "$(_ov_t_sha256 "$p")"
        fi
      done
  )
}

# ov_t_done: print the summary, exit non-zero on any failure.
ov_t_done() {
  printf '\n%s: %d passed, %d failed\n' "$(basename "$0")" "$_OV_T_PASS" "$_OV_T_FAIL"
  if ((_OV_T_FAIL > 0)); then
    exit 1
  fi
  exit 0
}
