#!/usr/bin/env bash
# ov-srs.sh context: map changed paths to module specs for the AI review
# (T046, FR-057).
set -euo pipefail
# shellcheck source-path=SCRIPTDIR
# shellcheck source=ov-test-lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/ov-test-lib.sh"

ov_t_scratch
p="$OV_T_DIR/proj"
mkdir -p "$p/docs/srs/modules"
ov_t_install_copy "$p"
cat >"$p/docs/srs/SRS.md" <<'EOF'
# Shop: SRS

## Purpose

SHARED-PURPOSE text.

## Module: a

Paths: src/a/**

A-BODY

## Module: b

Paths: src/b/**

B-BODY
EOF
(cd "$p" && CLAUDE_PROJECT_DIR=$p .specify/extensions/ov/scripts/bash/ov-srs.sh split >/dev/null)

ctx() { # ctx <stdin-lines>
  printf '%s' "$1" | (cd "$p" && CLAUDE_PROJECT_DIR=$p .specify/extensions/ov/scripts/bash/ov-srs.sh context)
}

ov_t_section "one module"
out=$(ctx $'src/a/x.rs\n')
assert_contains "$out" "=== module: a ===" "a header"
assert_contains "$out" "A-BODY" "a content"
assert_not_contains "$out" "B-BODY" "b not included"
assert_not_contains "$out" "=== module: b ===" "no b header"

ov_t_section "two modules, sorted"
out=$(ctx $'src/b/y.rs\nsrc/a/x.rs\n')
assert_contains "$out" "A-BODY" "a content"
assert_contains "$out" "B-BODY" "b content"
assert_eq "=== module: a ===|=== module: b ===" "$(grep '^=== module:' <<<"$out" | paste -sd'|' -)" "sorted module order"

ov_t_section "no module matches: shared sections only"
out=$(ctx $'README\n')
assert_contains "$out" "SHARED-PURPOSE" "shared sections printed"
assert_not_contains "$out" "A-BODY" "no module a"
assert_not_contains "$out" "B-BODY" "no module b"
assert_not_contains "$out" "Paths:" "no module section at all"
out=$(ctx "")
assert_contains "$out" "SHARED-PURPOSE" "empty input: shared sections"

ov_t_section "deterministic"
assert_eq "$(ctx $'src/b/y.rs\nsrc/a/x.rs\n')" "$(ctx $'src/a/x.rs\nsrc/b/y.rs\n')" "same output whatever the input order"
assert_exit 0 bash -c "printf 'src/a/x.rs\n' | (cd '$p' && CLAUDE_PROJECT_DIR='$p' .specify/extensions/ov/scripts/bash/ov-srs.sh context)"

ov_t_done
