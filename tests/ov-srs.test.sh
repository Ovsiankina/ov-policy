#!/usr/bin/env bash
# ov-srs.sh template | split | list (T041, contracts/srs-format.md, FR-020–
# FR-023, Scenarios 4.2, 4.3, SC-006).
set -euo pipefail
# shellcheck source-path=SCRIPTDIR
# shellcheck source=ov-test-lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/ov-test-lib.sh"

fx="$OV_REPO/tests/fixtures"
header="<!-- GENERATED from SRS.md, do not edit -->"

# shellcheck disable=SC2329 # invoked through assert_exit / ov_t_run
srs() { # srs <dir> <args...>
  local d=$1
  shift
  cd "$d" && CLAUDE_PROJECT_DIR=$d .specify/extensions/ov/scripts/bash/ov-srs.sh "$@"
}
new_proj() {
  mkdir -p "$1"
  ov_t_install_copy "$1"
}
use_srs() { # use_srs <dir> <fixture>
  mkdir -p "$1/docs/srs"
  cp "$fx/ov-srs-$2.md" "$1/docs/srs/SRS.md"
}

ov_t_section "template"
ov_t_scratch
p="$OV_T_DIR/proj"
new_proj "$p"
assert_exit 0 srs "$p" template
assert_contains "$OV_T_OUT" "created: docs/srs/SRS.md"
assert_eq "$(<"$p/.specify/extensions/ov/templates/ov-srs.md")" "$(<"$p/docs/srs/SRS.md")" "SRS.md is the template"
printf 'mine\n' >"$p/docs/srs/SRS.md"
assert_exit 0 srs "$p" template
assert_contains "$OV_T_OUT" "exists, kept: docs/srs/SRS.md"
assert_eq "mine" "$(<"$p/docs/srs/SRS.md")" "existing SRS.md kept"

ov_t_section "the untouched template refuses to split"
ov_t_scratch
p="$OV_T_DIR/proj"
new_proj "$p"
srs "$p" template >/dev/null
assert_exit 3 srs "$p" split

ov_t_section "split a valid SRS"
ov_t_scratch
p="$OV_T_DIR/proj"
new_proj "$p"
use_srs "$p" valid
assert_exit 0 srs "$p" split
assert_eq "a.md b.md" "$(cd "$p/docs/srs/modules" && echo *.md)" "exactly a.md and b.md"
src="$p/docs/srs/SRS.md"
expect_a=$(printf '%s\n' "$header"; sed -n '1,10p' "$src"; sed -n '11,39p' "$src")
expect_b=$(printf '%s\n' "$header"; sed -n '1,10p' "$src"; sed -n '40,$p' "$src")
assert_eq "$expect_a" "$(<"$p/docs/srs/modules/a.md")" "a.md = header + shared + module a verbatim"
assert_eq "$expect_b" "$(<"$p/docs/srs/modules/b.md")" "b.md = header + shared + module b verbatim"
assert_eq "$header" "$(head -n 1 "$p/docs/srs/modules/a.md")" "line 1 is the GENERATED header"
assert_contains "$(<"$p/docs/srs/modules/a.md")" "Paths: src/a/** lib/a.rs" "Paths: line included"
assert_no_file "$p/docs/srs/modules/fake.md" "the fenced fake module is ignored"
assert_not_contains "$(<"$p/docs/srs/modules/b.md")" "Module a owns" "b.md holds only its module"

ov_t_section "second split is byte-identical (SC-006)"
snap=$(ov_t_snapshot "$p")
assert_exit 0 srs "$p" split
assert_eq "$snap" "$(ov_t_snapshot "$p")" "tree unchanged"

ov_t_section "list"
assert_exit 0 srs "$p" list
assert_eq $'a\nb' "$OV_T_OUT" "module names in SRS order"

ov_t_section "orphans are reported and kept (Scenario 4.3)"
printf 'old\n' >"$p/docs/srs/modules/old.md"
: >"$p/docs/srs/modules/.gitkeep"
assert_exit 0 srs "$p" split
assert_contains "$OV_T_OUT$OV_T_ERR" "docs/srs/modules/old.md" "orphan reported"
assert_not_contains "$OV_T_OUT$OV_T_ERR" ".gitkeep" ".gitkeep is never an orphan"
assert_eq "old" "$(<"$p/docs/srs/modules/old.md")" "orphan left in place"

ov_t_section "invalid SRS: exit 1 naming the line, nothing written"
for case in "duplicate:40" "no-paths:40" "bad-name:40" "stray-heading:40"; do
  name=${case%%:*}
  line=${case#*:}
  ov_t_scratch
  q="$OV_T_DIR/proj"
  new_proj "$q"
  use_srs "$q" "$name"
  mkdir -p "$q/docs/srs/modules"
  printf 'keep me\n' >"$q/docs/srs/modules/a.md"
  snap=$(ov_t_snapshot "$q")
  assert_exit 1 srs "$q" split
  assert_contains "$OV_T_ERR" "line $line" "$name: names line $line"
  assert_eq "$snap" "$(ov_t_snapshot "$q")" "$name: nothing written, existing module files untouched"
done

ov_t_section "TODO( left: exit 3 listing the lines"
ov_t_scratch
q="$OV_T_DIR/proj"
new_proj "$q"
use_srs "$q" todo
assert_exit 3 srs "$q" split
assert_contains "$OV_T_OUT$OV_T_ERR" "line 50" "lists the TODO( line"
assert_no_file "$q/docs/srs/modules/a.md" "nothing written"

ov_t_section "missing SRS"
ov_t_scratch
q="$OV_T_DIR/proj"
new_proj "$q"
assert_exit 1 srs "$q" split
assert_contains "$OV_T_ERR" "run /speckit-ov-srs to start from the template"
assert_exit 1 srs "$q" list
assert_contains "$OV_T_ERR" "run /speckit-ov-srs to start from the template"

ov_t_section "usage"
assert_exit 1 srs "$q" bogus

ov_t_done
