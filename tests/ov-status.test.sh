#!/usr/bin/env bash
# ov-status.sh, the read-only state report behind /speckit-ov-help (T037,
# FR-011–FR-013, data-model "Project setup state").
set -euo pipefail
# shellcheck source-path=SCRIPTDIR
# shellcheck source=ov-test-lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/ov-test-lib.sh"

status_sh="$OV_REPO/extensions/ov/scripts/bash/ov-status.sh"

# shellcheck disable=SC2329 # invoked through assert_exit / ov_t_run
status_in() {
  cd "$1" && CLAUDE_PROJECT_DIR=$1 "$status_sh"
}
done_of() { # done_of <json> <order>
  jq -r --argjson n "$2" '.steps[] | select(.order == $n) | .done' <<<"$1"
}

# complete <dir>: every artifact of the data-model table.
complete() {
  local d=$1
  ov_t_install_copy "$d"
  mkdir -p "$d/.specify/memory" "$d/.claude" "$d/docs/srs/modules" "$d/docs/c4" "$d/.github/workflows"
  printf 'agents\n' >"$d/AGENTS.md"
  : >"$d/docs/srs/.gitkeep"
  : >"$d/docs/srs/modules/.gitkeep"
  : >"$d/docs/c4/.gitkeep"
  printf 'hooks:\n  after_implement:\n  - extension: ov\n    command: speckit.ov.c4-code\n    enabled: true\n' >"$d/.specify/extensions.yml"
  printf '{"hooks":{"PreToolUse":[{"matcher":"Edit|Write|MultiEdit|NotebookEdit","hooks":[{"type":"command","command":"python3 x/.specify/events.py speckit.ov.guard pre_tool_use 10"}]}]}}\n' >"$d/.claude/settings.json"
  printf '# SRS\n' >"$d/docs/srs/SRS.md"
  printf 'workspace {}\n' >"$d/docs/workspace.dsl"
  printf '# comment\nsrc/core/\n' >"$d/.aiignore"
  printf 'on: pull_request_target\n' >"$d/.github/workflows/ov-aiignore.yml"
  printf '<!-- ov-policy -->\n# Constitution\n- [X] done\n' >"$d/.specify/memory/constitution.md"
  sed -i.bak 's/^configured:.*/configured: true/' "$d/.specify/extensions/ov/ov-config.yml"
  rm -f "$d/.specify/extensions/ov/ov-config.yml.bak"
  printf 'contributing\n' >"$d/CONTRIBUTING.md"
  printf '{"name":"ov-main"}\n' >"$d/.github/ov-ruleset-main.json"
}

ov_t_section "empty project: all 6 steps missing"
ov_t_scratch
empty=$OV_T_DIR
assert_exit 0 status_in "$empty"
json=$OV_T_OUT
assert_eq "6" "$(jq '.steps | length' <<<"$json")" "6 steps"
assert_eq "0" "$(jq '[.steps[] | select(.done)] | length' <<<"$json")" "none done"
assert_eq "false" "$(jq '.all_done' <<<"$json")" "all_done false"
assert_eq "/speckit-ov-init,/speckit-ov-srs,/speckit-ov-c4-context,/speckit-ov-nogo,/speckit-constitution,/speckit-ov-pr" \
  "$(jq -r '[.steps | sort_by(.order)[] | .step] | join(",")' <<<"$json")" "steps in data-model order"
assert_contains "$(jq -r '.steps[0].missing | join("|")' <<<"$json")" "AGENTS.md" "missing lists the artifact"

ov_t_section "complete project: all done"
ov_t_scratch
full=$OV_T_DIR
complete "$full"
assert_exit 0 status_in "$full"
json=$OV_T_OUT
assert_eq "6" "$(jq '[.steps[] | select(.done)] | length' <<<"$json")" "all 6 done"
assert_eq "true" "$(jq '.all_done' <<<"$json")" "all_done true"
assert_eq "[]" "$(jq -c '.config_errors' <<<"$json")" "no config errors"
assert_eq "0" "$(jq '[.steps[].missing[]] | length' <<<"$json")" "nothing missing"

ov_t_section "each step goes missing alone"
# step order : artifact to remove
for case in "1:AGENTS.md" "1:docs/c4" "1:.specify/extensions.yml" "2:docs/srs/SRS.md" "3:docs/workspace.dsl" \
  "4:.github/workflows/ov-aiignore.yml" "4:.aiignore" "5:.specify/memory/constitution.md" \
  "6:CONTRIBUTING.md" "6:.github/ov-ruleset-main.json"; do
  n=${case%%:*}
  rel=${case#*:}
  ov_t_scratch
  d=$OV_T_DIR
  complete "$d"
  rm -rf "${d:?}/$rel"
  json=$(status_in "$d")
  assert_eq "false" "$(done_of "$json" "$n")" "removing $rel → step $n missing"
  assert_eq "5" "$(jq '[.steps[] | select(.done)] | length' <<<"$json")" "removing $rel → the other 5 still done"
done
ov_t_scratch
d=$OV_T_DIR
complete "$d"
printf '{}\n' >"$d/.claude/settings.json"
json=$(status_in "$d")
assert_eq "false" "$(done_of "$json" 1)" "no PreToolUse event → step 1 missing"
assert_eq "false" "$(done_of "$json" 4)" "no PreToolUse event → step 4 missing"
ov_t_scratch
d=$OV_T_DIR
complete "$d"
sed -i.bak 's/^configured:.*/configured: false/' "$d/.specify/extensions/ov/ov-config.yml"
json=$(status_in "$d")
assert_eq "false" "$(done_of "$json" 6)" "configured: false → step 6 missing"

ov_t_section ".aiignore content (spec edge case 1)"
ov_t_scratch
d=$OV_T_DIR
complete "$d"
: >"$d/.aiignore"
assert_eq "false" "$(done_of "$(status_in "$d")" 4)" "empty .aiignore → /speckit-ov-nogo not done"
printf '# only comments\n\n   \n' >"$d/.aiignore"
assert_eq "false" "$(done_of "$(status_in "$d")" 4)" "comment-only .aiignore → not done"

ov_t_section "constitution marker and placeholders (FR-012)"
ov_t_scratch
d=$OV_T_DIR
complete "$d"
c="$d/.specify/memory/constitution.md"
printf '<!-- ov-policy -->\n# [PROJECT_NAME] Constitution\n' >"$c"
assert_eq "false" "$(done_of "$(status_in "$d")" 5)" "marker + [PROJECT_NAME] placeholder → not done"
printf '# Constitution\n- [X] ok\n' >"$c"
assert_eq "false" "$(done_of "$(status_in "$d")" 5)" "no marker → not done"
printf '<!-- ov-policy -->\n# Constitution\n- [X] ok\n- [x] ok\n' >"$c"
assert_eq "true" "$(done_of "$(status_in "$d")" 5)" "marker + [X] checkbox → done"
# /speckit-constitution writes a Sync Impact Report comment naming the replaced placeholders.
printf '<!--\nSync Impact Report\n  - [PRINCIPLE_1_NAME] → I. Tests First\n-->\n\n# QS Constitution\n<!-- ov-policy -->\nText. <!-- was [PROJECT_NAME] --> More.\n' >"$c"
assert_eq "true" "$(done_of "$(status_in "$d")" 5)" "placeholders only inside HTML comments → done"
printf '<!-- ov-policy -->\n<!-- note --> # [PROJECT_NAME] Constitution\n' >"$c"
assert_eq "false" "$(done_of "$(status_in "$d")" 5)" "placeholder after a closed comment → not done"
printf '<!--\nreport\n-->\n<!-- ov-policy -->\n## [PRINCIPLE_1_NAME]\n' >"$c"
assert_eq "false" "$(done_of "$(status_in "$d")" 5)" "placeholder after a multi-line comment → not done"

ov_t_section "config errors"
ov_t_scratch
d=$OV_T_DIR
complete "$d"
sed -i.bak 's/^authorship:.*/authorship: branch/' "$d/.specify/extensions/ov/ov-config.yml"
json=$(status_in "$d")
assert_contains "$(jq -r '.config_errors | join("|")' <<<"$json")" "authorship: branch" "authorship: branch reported"
sed -i.bak 's/^ai_review:.*/ai_review: yes/' "$d/.specify/extensions/ov/ov-config.yml"
assert_eq "2" "$(jq '.config_errors | length' <<<"$(status_in "$d")")" "every bad value reported"

ov_t_section "read-only (FR-013)"
for d in "$empty" "$full"; do
  snap=$(ov_t_snapshot "$d")
  status_in "$d" >/dev/null
  status_in "$d" >/dev/null
  status_in "$d" >/dev/null
  assert_eq "$snap" "$(ov_t_snapshot "$d")" "three runs leave the tree byte-identical"
done

ov_t_done
