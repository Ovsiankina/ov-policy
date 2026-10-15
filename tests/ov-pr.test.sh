#!/usr/bin/env bash
# ov-pr.sh (T045, FR-050–FR-055, Scenarios 6.1, 6.2, 6.4, 6.6, 6.8, SC-006).
set -euo pipefail
# shellcheck source-path=SCRIPTDIR
# shellcheck source=ov-test-lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/ov-test-lib.sh"

agent_sentence="A commit is an agent commit only when it carries an agent trailer"

new_proj() {
  local d=$1
  ov_t_git_init "$d"
  ov_t_install_copy "$d"
  mkdir -p "$d/.claude"
  cat >"$d/.claude/settings.json" <<'EOF'
{
  "permissions": {"allow": ["Bash(npm test:*)"]},
  "hooks": {"PreToolUse": [{"matcher": "Edit|Write|MultiEdit|NotebookEdit", "hooks": [{"type": "command", "command": "python3 x/.specify/events.py speckit.ov.guard pre_tool_use 10"}]}]}
}
EOF
}
# shellcheck disable=SC2329 # invoked through assert_exit / ov_t_run
pr() { # pr <dir> <args...>
  local d=$1
  shift
  cd "$d" && CLAUDE_PROJECT_DIR=$d .specify/extensions/ov/scripts/bash/ov-pr.sh "$@"
}
cfg() { # cfg <dir> <key>
  sed -nE "s/^$2:[[:space:]]*//p" "$1/.specify/extensions/ov/ov-config.yml"
}
contexts() { # contexts <dir>
  jq -c '[.rules[] | select(.type == "required_status_checks") | .parameters.required_status_checks[].context]' \
    "$1/.github/ov-ruleset-main.json"
}
others_intact() { # others_intact <dir> <label>
  local s="$1/.claude/settings.json"
  assert_eq "Bash(npm test:*)" "$(jq -r '.permissions.allow[0]' "$s")" "$2: permissions kept"
  assert_eq "1" "$(jq '.hooks.PreToolUse | length' "$s")" "$2: hooks kept"
}

ov_t_scratch
p="$OV_T_DIR/proj"
new_proj "$p"

ov_t_section "defaults (Scenario 6.1)"
assert_exit 0 pr "$p" --authorship coauthor --auto-merge off --ai-review on
assert_eq "coauthor" "$(cfg "$p" authorship)" "config authorship: coauthor"
assert_eq "off" "$(cfg "$p" auto_merge)" "config auto_merge: off"
assert_eq "on" "$(cfg "$p" ai_review)" "config ai_review: on"
assert_eq "true" "$(cfg "$p" configured)" "config configured: true"
assert_no_file "$p/.specify/extensions/ov/ov-config.yml.bak" "no backup files"
assert_eq "0" "$(grep -c '^branch_prefix' "$p/.specify/extensions/ov/ov-config.yml" || true)" "no branch_prefix key"
contrib=$(<"$p/CONTRIBUTING.md")
assert_contains "$contrib" "<!-- ov:pr:begin -->" "CONTRIBUTING.md has the begin marker"
assert_contains "$contrib" "<!-- ov:pr:end -->" "CONTRIBUTING.md has the end marker"
assert_contains "$contrib" "coauthor" "block records the authorship"
assert_contains "$contrib" "Co-Authored-By: Claude <noreply@anthropic.com>" "block records the coauthor trailer"
assert_contains "$contrib" "off" "block records auto-merge"
assert_not_contains "$contrib" "{{" "every token filled"
assert_contains "$contrib" "$agent_sentence" "agent-commit sentence (FR-051, Scenario 6.8)"
assert_contains "$contrib" "whatever its branch" "whatever its branch"
assert_not_contains "$(tr '[:upper:]' '[:lower:]' <<<"$contrib")" "prefix" "no branch prefix mentioned"
assert_eq '["ov-aiignore","ov-ai-review"]' "$(contexts "$p")" "ai_review on → ov-ai-review required (Scenario 6.4)"
assert_eq "ov-main" "$(jq -r .name "$p/.github/ov-ruleset-main.json")" "ruleset name ov-main"
assert_file "$p/.github/workflows/ov-ai-review.yml" "ai_review on installs ov-ai-review.yml"
assert_no_file "$p/.github/workflows/ov-automerge.yml" "auto-merge off: no ov-automerge.yml"
assert_eq "null" "$(jq -c '.attribution' "$p/.claude/settings.json")" "coauthor sets no attribution"
others_intact "$p" "defaults"

ov_t_section "same answers twice: byte-identical (SC-006)"
snap=$(ov_t_snapshot "$p")
assert_exit 0 pr "$p" --authorship coauthor --auto-merge off --ai-review on
assert_eq "$snap" "$(ov_t_snapshot "$p")" "tree unchanged"

ov_t_section "trailer, auto-merge on, ai_review off (Scenarios 6.2, 6.6)"
assert_exit 0 pr "$p" --authorship trailer --auto-merge on --ai-review off
assert_eq "Assisted-by: claude-code" "$(jq -r '.attribution.commit' "$p/.claude/settings.json")" "attribution.commit set"
others_intact "$p" "trailer"
assert_eq '["ov-aiignore"]' "$(contexts "$p")" "ai_review off → only ov-aiignore required"
assert_file "$p/.github/workflows/ov-automerge.yml" "auto-merge on installs ov-automerge.yml"
assert_eq "$(<"$p/.specify/extensions/ov/templates/ov-automerge.yml")" "$(<"$p/.github/workflows/ov-automerge.yml")" "automerge workflow is the template"
assert_no_file "$p/.github/workflows/ov-ai-review.yml" "ai_review off removes the unmodified ov-ai-review.yml"
contrib=$(<"$p/CONTRIBUTING.md")
assert_contains "$contrib" "Assisted-by: claude-code" "block records the trailer"
assert_contains "$contrib" "Same-repo PRs merge automatically once the required checks pass; fork PRs are never auto-merged." "auto-merge sentence (FR-054)"
assert_eq "1" "$(grep -c '<!-- ov:pr:begin -->' "$p/CONTRIBUTING.md")" "one block only"

ov_t_section "flags left out keep the current answers"
assert_exit 0 pr "$p" --ai-review on
assert_eq "trailer" "$(cfg "$p" authorship)" "authorship kept"
assert_eq "on" "$(cfg "$p" auto_merge)" "auto_merge kept"
assert_eq "on" "$(cfg "$p" ai_review)" "ai_review changed"

ov_t_section "back to coauthor"
assert_exit 0 pr "$p" --authorship coauthor --auto-merge off --ai-review on
assert_eq "null" "$(jq -c '.attribution' "$p/.claude/settings.json")" "attribution key and empty object removed"
others_intact "$p" "coauthor"
assert_no_file "$p/.github/workflows/ov-automerge.yml" "auto-merge off removes the unmodified ov-automerge.yml"
jq '.attribution = {"commit": "Assisted-by: claude-code", "pr": "custom pr text"}' "$p/.claude/settings.json" >"$OV_T_DIR/s.json"
cp "$OV_T_DIR/s.json" "$p/.claude/settings.json"
assert_exit 0 pr "$p" --authorship coauthor --auto-merge off --ai-review on
assert_eq '{"pr":"custom pr text"}' "$(jq -c '.attribution' "$p/.claude/settings.json")" "other attribution keys kept"
jq '.attribution = {"commit": "my own trailer"}' "$p/.claude/settings.json" >"$OV_T_DIR/s.json"
cp "$OV_T_DIR/s.json" "$p/.claude/settings.json"
assert_exit 0 pr "$p" --authorship coauthor --auto-merge off --ai-review on
assert_eq "my own trailer" "$(jq -r '.attribution.commit' "$p/.claude/settings.json")" "a commit attribution ov did not set is kept"

ov_t_section "modified workflows are kept"
assert_exit 0 pr "$p" --authorship coauthor --auto-merge on --ai-review on
printf '# my change\n' >>"$p/.github/workflows/ov-automerge.yml"
assert_exit 0 pr "$p" --authorship coauthor --auto-merge off --ai-review on
assert_file "$p/.github/workflows/ov-automerge.yml" "modified ov-automerge.yml kept"
assert_contains "$OV_T_OUT" "ov-automerge.yml" "and reported"

ov_t_section "foreign ruleset file is kept"
ov_t_scratch
q="$OV_T_DIR/proj"
new_proj "$q"
mkdir -p "$q/.github"
printf '{"name": "my-rules"}\n' >"$q/.github/ov-ruleset-main.json"
assert_exit 0 pr "$q" --authorship coauthor --auto-merge off --ai-review on
assert_eq "my-rules" "$(jq -r .name "$q/.github/ov-ruleset-main.json")" "ruleset not named ov-main kept"
assert_contains "$OV_T_OUT" "ov-ruleset-main.json" "and reported"

ov_t_section "existing CONTRIBUTING.md"
ov_t_scratch
c="$OV_T_DIR/proj"
new_proj "$c"
printf '# Contributing\n\nOur own rules.\n' >"$c/CONTRIBUTING.md"
assert_exit 0 pr "$c" --authorship coauthor --auto-merge off --ai-review on
assert_contains "$(<"$c/CONTRIBUTING.md")" "Our own rules." "existing content kept"
assert_eq "1" "$(grep -c '<!-- ov:pr:begin -->' "$c/CONTRIBUTING.md")" "block appended once"
assert_exit 0 pr "$c" --authorship trailer --auto-merge off --ai-review on
assert_eq "1" "$(grep -c '<!-- ov:pr:begin -->' "$c/CONTRIBUTING.md")" "still one block after a change"
assert_contains "$(<"$c/CONTRIBUTING.md")" "Our own rules." "existing content still kept"
assert_contains "$(<"$c/CONTRIBUTING.md")" "Assisted-by: claude-code" "block rewritten between the markers"
printf 'After the block.\n' >>"$c/CONTRIBUTING.md"
assert_exit 0 pr "$c" --authorship coauthor --auto-merge off --ai-review on
assert_eq "After the block." "$(tail -n 1 "$c/CONTRIBUTING.md")" "text after the block kept"
ov_t_scratch
h="$OV_T_DIR/proj"
new_proj "$h"
printf '# Contributing\n<!-- ov:pr:begin -->\nhalf a block\n' >"$h/CONTRIBUTING.md"
snap=$(ov_t_snapshot "$h")
assert_exit 1 pr "$h" --authorship coauthor --auto-merge off --ai-review on
assert_eq "$snap" "$(ov_t_snapshot "$h")" "a broken marker pair changes nothing"

ov_t_section "invalid values change nothing"
snap=$(ov_t_snapshot "$p")
assert_exit 1 pr "$p" --authorship branch
assert_exit 1 pr "$p" --prefix ai/
assert_exit 1 pr "$p" --auto-merge yes
assert_exit 1 pr "$p" --ai-review
assert_eq "$snap" "$(ov_t_snapshot "$p")" "tree unchanged"

ov_t_section "no git hooks (FR-053 removed)"
assert_no_file "$p/.githooks" "no .githooks/"
assert_eq "" "$(git -C "$p" config core.hooksPath || true)" "core.hooksPath unset"

ov_t_done
