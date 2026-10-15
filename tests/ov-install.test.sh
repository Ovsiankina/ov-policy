#!/usr/bin/env bash
# US1: `specify extension add <repo>/extensions/ov --dev` on a fresh Claude
# project (T010, quickstart §1, Scenarios 1.1–1.3).
set -euo pipefail
# shellcheck source-path=SCRIPTDIR
# shellcheck source=ov-test-lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/ov-test-lib.sh"

ov_t_have_specify || ov_t_skip "specify is not on PATH"

manifest="$OV_REPO/extensions/ov/extension.yml"
mapfile -t cmds < <(sed -nE 's/^[[:space:]]*-[[:space:]]+name:[[:space:]]*"?(speckit\.ov\.[a-z0-9-]+)"?[[:space:]]*$/\1/p' "$manifest")

ov_t_scratch
proj="$OV_T_DIR/proj"
(cd "$OV_T_DIR" && specify init proj --integration claude >/dev/null 2>&1)
ov_t_git_init "$proj"
git -C "$proj" add -A
git -C "$proj" commit -qm "spec-kit init"

# shellcheck disable=SC2329 # invoked through assert_exit / ov_t_run
in_proj() {
  cd "$proj" && "$@"
}

ov_t_section "(1) extension add --dev"
assert_exit 0 in_proj specify extension add "$OV_REPO/extensions/ov" --dev
out="$OV_T_OUT$OV_T_ERR"
if grep -qiE 'warn|⚠' <<<"$out"; then
  _ov_t_bad "install output has no warning" "$(grep -iE 'warn|⚠' <<<"$out")"
else
  _ov_t_ok "install output has no warning"
fi

ov_t_section "(2) one skill per manifest command"
assert_eq "true" "$([[ ${#cmds[@]} -gt 0 ]] && echo true || echo false)" "manifest lists commands"
for c in "${cmds[@]}"; do
  skill=${c//./-}
  assert_file "$proj/.claude/skills/$skill/SKILL.md" "skill $skill"
done
count=$(find "$proj/.claude/skills" -mindepth 1 -maxdepth 1 -type d -name 'speckit-ov-*' | wc -l | tr -d ' ')
assert_eq "${#cmds[@]}" "$count" "speckit-ov-* skill count equals the manifest command count"

ov_t_section "(3) after_implement hook"
# shellcheck source=SCRIPTDIR/../extensions/ov/scripts/bash/ov-common.sh
source "$OV_REPO/extensions/ov/scripts/bash/ov-common.sh"
ov_init_paths "$proj"
assert_exit 0 ov_hook_registered

ov_t_section "(4) config scaffolded"
assert_file "$proj/.specify/extensions/ov/ov-config.yml"

ov_t_section "(5) only spec-kit's extension locations changed (Scenario 1.3)"
# spec-kit's own file-tracking registry for the claude integration: it may only
# gain the entries for the event dispatcher and settings.json it just wrote.
imanifest=.specify/integrations/claude.manifest.json
strip='del(.files[".specify/events.py"], .files[".claude/settings.json"], .ownership_modes)'
bad=()
while IFS= read -r line; do
  p=${line:3}
  p=${p#\"}
  p=${p%\"}
  case $p in
    .specify/extensions/ov/* | .specify/extensions.yml | .claude/settings.json | .specify/events.py) ;;
    "$imanifest")
      [[ $(git -C "$proj" show "HEAD:$imanifest" | jq -S "$strip") == $(jq -S "$strip" "$proj/$imanifest") ]] ||
        bad+=("$p (changed beyond the events.py/settings.json entries)")
      ;;
    .claude/skills/speckit-ov-*/*) ;;
    .specify/extensions/*) [[ $p == .specify/extensions/.* ]] || bad+=("$p") ;;
    *) bad+=("$p") ;;
  esac
done < <(git -C "$proj" status --porcelain --untracked-files=all)
assert_eq "" "${bad[*]-}" "every changed path is an install-time location"
core=$(git -C "$proj" status --porcelain --untracked-files=all -- .specify/scripts .specify/templates .specify/memory)
assert_eq "" "$core" "nothing under .specify/scripts, templates or memory changed"

ov_t_section "(6) re-add --force keeps one hook entry"
assert_exit 0 in_proj specify extension add "$OV_REPO/extensions/ov" --dev --force
n=$(grep -cE '^[[:space:]]*command:[[:space:]]*"?speckit\.ov\.c4-code"?[[:space:]]*$' "$proj/.specify/extensions.yml" || true)
assert_eq "1" "$n" "a single ov after_implement entry"
assert_exit 0 ov_hook_registered

ov_t_section "(7) extension remove"
assert_exit 0 in_proj specify extension remove ov --force
left=$(find "$proj/.claude/skills" -mindepth 1 -maxdepth 1 -name 'speckit-ov-*' | wc -l | tr -d ' ')
assert_eq "0" "$left" "skills removed"
assert_exit 1 ov_hook_registered

ov_t_done
