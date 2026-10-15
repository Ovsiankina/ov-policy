#!/usr/bin/env bash
# Static checks on the shipped workflow templates (T022; T047 extends it).
# shellcheck disable=SC2016 # literal ${{ }} and $VAR strings are matched, not expanded
set -euo pipefail
# shellcheck source-path=SCRIPTDIR
# shellcheck source=ov-test-lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/ov-test-lib.sh"

tdir="$OV_REPO/extensions/ov/templates"

# run_blocks <file>: the content of every `run:` value, block scalars included.
run_blocks() {
  awk '
    function lead(s) { match(s, /^ */); return RLENGTH }
    in_block {
      if ($0 ~ /^[ \t]*$/ || lead($0) > key_ind) { print; next }
      in_block = 0
    }
    match($0, /^ *(- +)?run:/) {
      key_ind = RLENGTH - 4
      rest = substr($0, RLENGTH + 1); sub(/^[ \t]+/, "", rest)
      if (rest ~ /^[|>][-+0-9]*[ \t]*$/) { in_block = 1; next }
      print rest
    }
  ' "$1"
}

# block <file> <top-level-key>: the indented lines under a top-level key.
block() {
  awk -v k="$2" '
    $0 ~ "^" k ":" { on = 1; next }
    on && /^[^ \t#]/ { on = 0 }
    on && !/^[ \t]*(#.*)?$/ { sub(/^[ \t]+/, ""); print }
  ' "$1"
}

ov_t_section "ov-aiignore.yml"
wf="$tdir/ov-aiignore.yml"
assert_file "$wf"
if [[ -f $wf ]]; then
  body=$(<"$wf")
  runs=$(run_blocks "$wf")
  on=$(block "$wf" on)
  assert_contains "$on" "pull_request_target:" "trigger is pull_request_target"
  assert_not_contains "$on" "pull_request:" "no plain pull_request trigger"
  types=$(sed -nE 's/^[[:space:]]*types:[[:space:]]*\[(.*)\][[:space:]]*$/\1/p' "$wf" | tr -d ' ')
  assert_eq "opened,synchronize,reopened,edited" "$types" "types opened, synchronize, reopened, edited"
  assert_eq "contents: read" "$(block "$wf" permissions)" "permissions are exactly contents: read"
  jobs=$(block "$wf" jobs)
  assert_contains "$jobs" "ov-aiignore:" "job id ov-aiignore"
  assert_eq "1" "$(grep -cE '^[[:space:]]+name:[[:space:]]*ov-aiignore[[:space:]]*$' "$wf")" "job/status name ov-aiignore"
  assert_eq "1" "$(grep -cE 'uses:[[:space:]]*actions/checkout@' "$wf")" "one checkout step"
  assert_contains "$body" 'ref: ${{ github.event.pull_request.base.sha }}' "checkout at the base SHA"
  assert_contains "$body" "persist-credentials: false" "checkout without persisted credentials"
  assert_contains "$body" "fetch-depth: 0" "full history for base..head"
  assert_contains "$runs" 'refs/pull/${PR_NUMBER}/head' "head fetched as refs/pull/<n>/head"
  assert_contains "$runs" "git" "fetch runs git"
  for bad in "git checkout" "git switch" "git worktree" "git reset" "git merge"; do
    assert_not_contains "$runs" "$bad" "head never checked out ($bad)"
  done
  for bad in 'github.head_ref' 'github.event.pull_request.head.' 'github.event.pull_request.title' \
    'github.event.pull_request.body'; do
    assert_not_contains "$runs" "$bad" "run: does not interpolate $bad"
  done
  assert_not_contains "$runs" '${{' "run: blocks interpolate nothing (values come through env:)"
  assert_contains "$runs" ".specify/extensions/ov/scripts/bash/ov-ci-aiignore.sh" "calls ov-ci-aiignore.sh"
  assert_contains "$runs" '"$BASE_SHA" "$HEAD_SHA"' "passes base and head SHAs from env"
  for v in BASE_SHA HEAD_SHA PR_NUMBER; do
    assert_eq "true" "$(grep -qE "^[[:space:]]+$v:[[:space:]]*\\$\\{\\{" "$wf" && echo true || echo false)" "$v set through env:"
  done
fi

# steps_of <file>: one line per step: "<index>\t<id>\t<name>\t<if>".
steps_of() {
  awk '
    function lead(s) { match(s, /^ */); return RLENGTH }
    function flush() { if (n) print n "\t" id "\t" nm "\t" cond }
    /^[ \t]*steps:[ \t]*$/ { insteps = 1; sind = lead($0); iind = -1; next }
    insteps {
      if ($0 ~ /^[ \t]*(#.*)?$/) next
      ind = lead($0); line = substr($0, ind + 1)
      if (ind <= sind && line !~ /^- /) { insteps = 0; next }
      if (line ~ /^- / && (iind < 0 || ind == iind)) {
        iind = ind; flush(); n++; id = ""; nm = ""; cond = ""
        line = substr(line, 3); sub(/^ +/, "", line); kind = ind + 2
      } else if (ind != kind) next
      if (line ~ /^id:/) { id = line; sub(/^id:[ \t]*/, "", id) }
      else if (line ~ /^name:/) { nm = line; sub(/^name:[ \t]*/, "", nm) }
      else if (line ~ /^if:/) { cond = line; sub(/^if:[ \t]*/, "", cond) }
    }
    END { flush() }
  ' "$1"
}

ov_t_section "ov-ai-review.yml"
wf="$tdir/ov-ai-review.yml"
assert_file "$wf"
if [[ -f $wf ]]; then
  body=$(<"$wf")
  runs=$(run_blocks "$wf")
  on=$(block "$wf" on)
  assert_contains "$on" "pull_request_target:" "trigger is pull_request_target"
  types=$(sed -nE 's/^[[:space:]]*types:[[:space:]]*\[(.*)\][[:space:]]*$/\1/p' "$wf" | tr -d ' ')
  assert_eq "opened,synchronize,reopened" "$types" "types opened, synchronize, reopened"
  perms=$(block "$wf" permissions)
  assert_eq $'contents: read\npull-requests: read' "$perms" "permissions contents: read, pull-requests: read"
  assert_contains "$(block "$wf" jobs)" "ov-ai-review:" "job id ov-ai-review"
  assert_eq "1" "$(grep -cE '^[[:space:]]+name:[[:space:]]*ov-ai-review[[:space:]]*$' "$wf")" "job/status name ov-ai-review"
  steps=$(steps_of "$wf")
  first=$(head -n 1 <<<"$steps")
  assert_eq "fork" "$(cut -f2 <<<"$first")" "first step is the fork check (id: fork)"
  assert_contains "$runs" "ov-ai-review: fork PR, AI review skipped" "fork summary message (FR-058)"
  assert_contains "$runs" 'GITHUB_STEP_SUMMARY' "fork notice goes to the job summary"
  assert_contains "$runs" "skip=true" "fork check sets skip=true"
  later=$(tail -n +2 <<<"$steps")
  bad_if=$(awk -F'\t' '$4 !~ /steps\.fork\.outputs\.skip != .true./' <<<"$later")
  assert_eq "" "$bad_if" "every later step is skipped for forks"
  secret_line=$(grep -n 'secrets.ANTHROPIC_API_KEY' "$wf" | head -n 1 | cut -d: -f1)
  fork_line=$(grep -n 'id: fork' "$wf" | head -n 1 | cut -d: -f1)
  assert_eq "true" "$([[ -n $secret_line && -n $fork_line && $secret_line -gt $fork_line ]] && echo true || echo false)" "secret read after the fork check"
  assert_contains "$runs" "ov-ai-review: repository secret ANTHROPIC_API_KEY is not set (set it or run /speckit-ov-pr and choose ai_review: off)" "exact missing-secret message (FR-056)"
  allowed=$(grep -oE -- '--allowedTools[ =]+"[^"]*"' "$wf" | sed -E 's/.*"([^"]*)"/\1/')
  assert_eq "Read,Grep,Glob" "$allowed" "--allowedTools is exactly Read,Grep,Glob"
  assert_not_contains "$allowed" "Bash" "Bash not allowed"
  assert_contains "$runs" "claude -p" "runs claude -p"
  assert_contains "$runs" "--output-format json" "JSON output"
  assert_contains "$runs" "OV-REVIEW: PASS" "PASS verdict line"
  assert_contains "$runs" "OV-REVIEW: FAIL" "FAIL verdict line"
  assert_contains "$runs" ".specify/extensions/ov/scripts/bash/ov-srs.sh context" "maps files to modules (FR-057)"
  assert_contains "$body" 'ref: ${{ github.event.pull_request.base.sha }}' "checkout at the base SHA"
  assert_contains "$body" "persist-credentials: false" "checkout without persisted credentials"
  assert_contains "$runs" 'refs/pull/${PR_NUMBER}/head' "head fetched as refs/pull/<n>/head"
  for bad in "git checkout" "git switch" "git worktree" "github.head_ref" "github.event.pull_request.head." '${{'; do
    assert_not_contains "$runs" "$bad" "run: blocks do not contain $bad"
  done
fi

ov_t_section "ov-automerge.yml"
wf="$tdir/ov-automerge.yml"
assert_file "$wf"
if [[ -f $wf ]]; then
  body=$(<"$wf")
  runs=$(run_blocks "$wf")
  assert_contains "$(block "$wf" on)" "pull_request_target:" "trigger is pull_request_target"
  types=$(sed -nE 's/^[[:space:]]*types:[[:space:]]*\[(.*)\][[:space:]]*$/\1/p' "$wf" | tr -d ' ')
  assert_eq "opened,reopened,ready_for_review" "$types" "types opened, reopened, ready_for_review"
  assert_eq $'contents: write\npull-requests: write' "$(block "$wf" permissions)" "permissions contents: write, pull-requests: write"
  jobif=$(sed -nE 's/^    if:[[:space:]]*(.*)$/\1/p' "$wf")
  assert_contains "$jobif" "github.event.pull_request.head.repo.full_name == github.repository" "job runs for same-repo PRs only (Scenario 6.3a)"
  assert_contains "$runs" 'gh pr merge --auto --squash "$PR_NUMBER"' "gh pr merge --auto --squash"
  assert_not_contains "$body" "actions/checkout" "no checkout"
  for bad in "head_ref" "head.ref" "branch" "prefix" "ai/"; do
    assert_not_contains "$body" "$bad" "no branch-name logic ($bad)"
  done
  for bad in "github.event.pull_request.head." '${{'; do
    assert_not_contains "$runs" "$bad" "run: does not interpolate $bad"
  done
fi

ov_t_section "actionlint"
if command -v actionlint >/dev/null 2>&1; then
  for f in "$tdir"/ov-*.yml; do
    assert_exit 0 actionlint "$f"
  done
else
  printf '  skip  actionlint not on PATH\n'
fi

ov_t_done
