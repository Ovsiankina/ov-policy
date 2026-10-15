#!/usr/bin/env bash
# The ov-policy preset and scripts/ov-sync-policy.sh (T060, FR-002, R-10,
# Scenarios 7.1, 7.2). Runs on temp copies only, never on the real repo.
set -euo pipefail
# shellcheck source-path=SCRIPTDIR
# shellcheck source=ov-test-lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/ov-test-lib.sh"

sync="$OV_REPO/scripts/ov-sync-policy.sh"
marker='<!-- ov-policy -->'

# fake_repo <dir>: the parts of the repo the sync script reads.
fake_repo() {
  mkdir -p "$1/presets"
  cp -R "$OV_REPO/presets/ov-policy" "$1/presets/ov-policy"
}
# shellcheck disable=SC2329 # invoked through assert_exit / ov_t_run
sync_in() { # sync_in <dir> [--check]
  local d=$1
  shift
  OV_REPO_ROOT=$d "$sync" "$@"
}

ov_t_section "shipped placeholder"
assert_eq "$marker" "$(<"$OV_REPO/presets/ov-policy/templates/ov-policy.md")" "repo copy is the marker line"

ov_t_section "POLICY.md not written yet"
ov_t_scratch
r=$OV_T_DIR
fake_repo "$r"
copy="$r/presets/ov-policy/templates/ov-policy.md"
assert_exit 0 sync_in "$r" --check
assert_contains "$OV_T_OUT" "POLICY.md not written yet"
printf '%s\nextra\n' "$marker" >"$copy"
assert_exit 1 sync_in "$r" --check
assert_exit 1 sync_in "$r"
assert_no_file "$r/POLICY.md" "the sync never creates POLICY.md"

ov_t_section "POLICY.md without the marker"
printf '# Policy\n' >"$r/POLICY.md"
printf '%s\n' "$marker" >"$copy"
snap=$(ov_t_snapshot "$r")
assert_exit 1 sync_in "$r" --check
assert_exit 1 sync_in "$r"
assert_eq "$snap" "$(ov_t_snapshot "$r")" "nothing written"

ov_t_section "matching and differing"
printf '%s\n# Policy\n\nov enforces autonomous agent loops.\n' "$marker" >"$r/POLICY.md"
cp "$r/POLICY.md" "$copy"
assert_exit 0 sync_in "$r" --check
printf '%s\n# Policy v2\n' "$marker" >"$r/POLICY.md"
policy_sha=$(_ov_t_sha256 "$r/POLICY.md")
assert_exit 1 sync_in "$r" --check
assert_exit 0 sync_in "$r"
assert_eq "true" "$(cmp -s "$r/POLICY.md" "$copy" && echo true || echo false)" "sync makes the copy byte-identical"
assert_eq "$policy_sha" "$(_ov_t_sha256 "$r/POLICY.md")" "POLICY.md untouched"
assert_exit 0 sync_in "$r" --check
snap=$(ov_t_snapshot "$r")
assert_exit 0 sync_in "$r"
assert_eq "$snap" "$(ov_t_snapshot "$r")" "second sync changes nothing"

ov_t_section "usage"
assert_exit 1 sync_in "$r" --bogus

ov_t_section "spec-kit resolves the prepended template (Scenarios 7.1, 7.2)"
if ov_t_have_specify; then
  ov_t_scratch
  w=$OV_T_DIR
  (cd "$w" && specify init proj --integration claude >/dev/null 2>&1)
  cp -R "$OV_REPO/presets/ov-policy" "$w/pre"
  printf '%s\nPOLICY TEXT ONE\n' "$marker" >"$w/pre/templates/ov-policy.md"
  # shellcheck disable=SC2329 # invoked through assert_exit / ov_t_run
  in_proj() { cd "$w/proj" && "$@"; }
  assert_exit 0 in_proj specify preset add --dev "$w/pre"
  resolved=$(cd "$w/proj" && .specify/scripts/bash/resolve-template.sh constitution-template --json | jq -r .TEMPLATE_CONTENT)
  copy_text=$(<"$w/pre/templates/ov-policy.md")
  assert_eq "$copy_text" "$(head -n 2 <<<"$resolved")" "resolved template starts with the preset copy"
  core_first=$(head -n 1 "$w/proj/.specify/templates/constitution-template.md")
  assert_contains "$(tail -n +3 <<<"$resolved")" "$core_first" "followed by the core template"
  printf '%s\nPOLICY TEXT TWO\n' "$marker" >"$w/pre/templates/ov-policy.md"
  # spec-kit 1.2.0 has no `preset add --force`: re-adding is remove + add.
  assert_exit 0 in_proj specify preset remove ov-policy
  assert_exit 0 in_proj specify preset add --dev "$w/pre"
  resolved=$(cd "$w/proj" && .specify/scripts/bash/resolve-template.sh constitution-template --json | jq -r .TEMPLATE_CONTENT)
  assert_contains "$resolved" "POLICY TEXT TWO" "re-added preset carries the new text"
  assert_not_contains "$resolved" "POLICY TEXT ONE" "old text gone"
else
  printf '  skip  specify not on PATH\n'
fi

ov_t_done
