#!/usr/bin/env bash
# Tests for scripts/ov-lint-prefix.sh (T005, Principle I mechanism).
set -euo pipefail
# shellcheck source-path=SCRIPTDIR
# shellcheck source=ov-test-lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/ov-test-lib.sh"

lint="$OV_REPO/scripts/ov-lint-prefix.sh"

# fake_tree <dir>: a minimal tree that passes the lint.
fake_tree() {
  local d=$1
  mkdir -p "$d/extensions/ov/commands" "$d/extensions/ov/scripts/bash" "$d/presets/ov-policy/templates" \
    "$d/bundles/ov" "$d/scripts" "$d/tests/fixtures" "$d/.github/workflows" "$d/docs"
  cat >"$d/extensions/ov/extension.yml" <<'EOF'
schema_version: "1.0"
extension:
  id: ov
  name: "ov"
provides:
  commands:
    - name: speckit.ov.init
      file: commands/speckit.ov.init.md
    - name: "speckit.ov.c4-code"
      file: commands/speckit.ov.c4-code.md
  config:
    - name: ov-config.yml
      template: ov-config-template.yml
hooks:
  after_implement:
    command: speckit.ov.c4-code
EOF
  : >"$d/extensions/ov/commands/speckit.ov.init.md"
  : >"$d/extensions/ov/commands/speckit.ov.c4-code.md"
  : >"$d/extensions/ov/.extensionignore"
  : >"$d/extensions/ov/scripts/bash/ov-x.sh"
  : >"$d/presets/ov-policy/preset.yml"
  : >"$d/presets/ov-policy/templates/ov-policy.md"
  : >"$d/bundles/ov/bundle.yml"
  : >"$d/scripts/ov-tool.sh"
  : >"$d/tests/ov-a.test.sh"
  : >"$d/tests/fixtures/ov-f.json"
  : >"$d/.github/workflows/ov-ci.yml"
  : >"$d/docs/unscanned.md"
}

ov_t_scratch
good=$OV_T_DIR
fake_tree "$good"

ov_t_section "clean tree"
assert_exit 0 "$lint" "$good"

ov_t_section "unprefixed file"
ov_t_scratch
bad=$OV_T_DIR
fake_tree "$bad"
: >"$bad/extensions/ov/scripts/bash/helper.sh"
assert_exit 1 "$lint" "$bad"
assert_contains "$OV_T_ERR" "extensions/ov/scripts/bash/helper.sh" "names helper.sh"

ov_t_section "speckit.ov.*.md outside commands/"
ov_t_scratch
bad2=$OV_T_DIR
fake_tree "$bad2"
mkdir -p "$bad2/extensions/ov/templates"
: >"$bad2/extensions/ov/templates/speckit.ov.init.md"
: >"$bad2/tests/speckit.ov.init.md"
assert_exit 1 "$lint" "$bad2"
assert_contains "$OV_T_ERR" "extensions/ov/templates/speckit.ov.init.md" "names the misplaced command file"
assert_contains "$OV_T_ERR" "tests/speckit.ov.init.md" "names the misplaced command file in tests/"

ov_t_section "bad command name in extension.yml"
ov_t_scratch
bad3=$OV_T_DIR
fake_tree "$bad3"
sed -i.bak 's/speckit\.ov\.init$/speckit.ov.Init_X/' "$bad3/extensions/ov/extension.yml"
rm -f "$bad3/extensions/ov/extension.yml.bak"
assert_exit 1 "$lint" "$bad3"
assert_contains "$OV_T_ERR" "speckit.ov.Init_X" "names the bad command"
sed -i.bak 's/speckit\.ov\.Init_X$/speckit.git.init/' "$bad3/extensions/ov/extension.yml"
rm -f "$bad3/extensions/ov/extension.yml.bak"
assert_exit 1 "$lint" "$bad3"
assert_contains "$OV_T_ERR" "speckit.git.init" "names a command from another namespace"

ov_t_section "this repo"
assert_exit 0 "$lint" "$OV_REPO"

ov_t_done
