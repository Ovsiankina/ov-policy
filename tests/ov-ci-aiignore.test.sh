#!/usr/bin/env bash
# ov-ci-aiignore.sh on a fixture repo (T019, contracts/ci-checks.md,
# Scenarios 2.2, 2.4, 2a, 2b, 2d, SC-004).
set -euo pipefail
# shellcheck source-path=SCRIPTDIR
# shellcheck source=ov-test-lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/ov-test-lib.sh"

ov_t_scratch
repo="$OV_T_DIR/repo"
ov_t_git_init "$repo"
ov_t_install_copy "$repo"
printf '.aiignore\nsrc/core/\n' >"$repo/.aiignore"
mkdir -p "$repo/src/core"
printf 'core\n' >"$repo/src/core/x.rs"
printf 'main\n' >"$repo/src/main.rs"
printf 'other\n' >"$repo/src/other.txt"

g() { git -C "$repo" "$@"; }
g add -A
g commit -qm "base"
base=$(g rev-parse HEAD)
ci="$repo/.specify/extensions/ov/scripts/bash/ov-ci-aiignore.sh"

claude="Co-Authored-By: Claude <noreply@anthropic.com>"

# branch <name> [<start>]: fresh branch, defaults to the base commit.
branch() { g checkout -q -B "$1" "${2:-$base}"; }
# change <file> <subject> [<trailer>]: append to a file and commit.
change() {
  mkdir -p "$(dirname "$repo/$1")"
  printf 'edit %s\n' "$RANDOM" >>"$repo/$1"
  g add -A
  if [[ -n ${3:-} ]]; then g commit -qm "$2" -m "$3"; else g commit -qm "$2"; fi
}
# shellcheck disable=SC2329 # invoked through assert_exit / ov_t_run
run_ci() {
  cd "$repo" && "$ci" "$@"
}

ov_t_section "(a) Co-Authored-By: Claude touching a listed path"
branch case-a
change src/core/x.rs "agent edit" "$claude"
sha=$(g rev-parse HEAD)
assert_exit 1 run_ci "$base" "$sha"
assert_contains "$OV_T_OUT" "$sha src/core/x.rs" "names the commit and the path"

ov_t_section "(b) lowercase trailer"
branch case-b
change src/core/x.rs "agent edit" "co-authored-by: claude <x>"
assert_exit 1 run_ci "$base" "$(g rev-parse HEAD)"

ov_t_section "(c) Assisted-by: claude-code"
branch case-c
change src/core/x.rs "agent edit" "Assisted-by: claude-code"
assert_exit 1 run_ci "$base" "$(g rev-parse HEAD)"

ov_t_section "(d) no trailer on a branch named ai/demo (Scenario 2a)"
branch ai/demo
change src/core/x.rs "human edit on ai/demo"
assert_exit 0 run_ci "$base" "$(g rev-parse HEAD)"

ov_t_section "(e) human touches the listed path, agent touches only unlisted (Scenario 2b)"
branch case-e
change src/core/x.rs "human edit"
change src/main.rs "agent edit" "$claude"
assert_exit 0 run_ci "$base" "$(g rev-parse HEAD)"

ov_t_section "(f) a non-Claude co-author"
branch case-f
change src/core/x.rs "pair edit" "Co-Authored-By: Jane <j@x>"
assert_exit 0 run_ci "$base" "$(g rev-parse HEAD)"

ov_t_section "(g) agent rename out of a listed path"
branch case-g
g mv src/core/x.rs src/y.rs
g commit -qm "agent rename" -m "$claude"
sha=$(g rev-parse HEAD)
assert_exit 1 run_ci "$base" "$sha"
assert_contains "$OV_T_OUT" "$sha src/core/x.rs" "the old side of the rename counts"

ov_t_section "(h) agent adds a pattern and edits what it matches (Scenario 2.4)"
branch case-h
printf 'lib/\n' >>"$repo/.aiignore"
mkdir -p "$repo/lib"
printf 'a\n' >"$repo/lib/a.rs"
g add -A
g commit -qm "agent widens .aiignore" -m "$claude"
sha=$(g rev-parse HEAD)
assert_exit 1 run_ci "$base" "$sha"
assert_contains "$OV_T_OUT" "$sha .aiignore" "lists .aiignore"
assert_not_contains "$OV_T_OUT" "lib/a.rs" "the base .aiignore is used, not the PR's"

ov_t_section "(i) fork-shaped head, reachable only as refs/pull/7/head (Scenario 2d)"
branch fork-tmp
change src/core/x.rs "fork agent edit" "$claude"
sha=$(g rev-parse HEAD)
g update-ref refs/pull/7/head "$sha"
g checkout -q main
g branch -q -D fork-tmp
assert_eq "" "$(g branch --contains "$sha")" "no branch contains the fork commit"
assert_exit 1 run_ci "$base" "$(g rev-parse refs/pull/7/head)"
assert_contains "$OV_T_OUT" "$sha src/core/x.rs" "fork commit reported"

ov_t_section "(j) base without .aiignore"
branch no-aiignore
g rm -q .aiignore
g commit -qm "drop .aiignore"
nobase=$(g rev-parse HEAD)
change src/core/x.rs "agent edit" "$claude"
assert_exit 0 run_ci "$nobase" "$(g rev-parse HEAD)"
assert_contains "$OV_T_OUT$OV_T_ERR" "ov-aiignore: no .aiignore on the base branch, nothing to check" "notice"

ov_t_section "(k) merge commits"
branch main2
change src/core/x.rs "human edit on main"
main2=$(g rev-parse HEAD)
branch evil
change src/main.rs "human edit"
g merge -q --no-ff --no-commit main2 >/dev/null 2>&1
printf 'evil\n' >>"$repo/src/core/x.rs"
g add -A
g commit -qm "Merge main2" -m "$claude"
evil=$(g rev-parse HEAD)
assert_exit 1 run_ci "$main2" "$evil"
assert_contains "$OV_T_OUT" "$evil src/core/x.rs" "evil merge reported"
branch clean
change src/main.rs "human edit"
g merge -q --no-ff main2 -m "Merge main2" -m "$claude" >/dev/null 2>&1
assert_exit 0 run_ci "$main2" "$(g rev-parse HEAD)"

ov_t_section "(l) GITHUB_STEP_SUMMARY"
branch case-l
change src/core/x.rs "agent edit" "$claude"
sha=$(g rev-parse HEAD)
summary="$OV_T_DIR/summary.md"
: >"$summary"
assert_exit 1 env GITHUB_STEP_SUMMARY="$summary" bash -c "cd '$repo' && '$ci' '$base' '$sha'"
assert_contains "$(<"$summary")" "$sha" "summary names the commit"
assert_contains "$(<"$summary")" "src/core/x.rs" "summary names the path"

ov_t_section "usage"
assert_exit 2 run_ci "$base"
assert_exit 2 run_ci "$base" deadbeefdeadbeef

ov_t_done
