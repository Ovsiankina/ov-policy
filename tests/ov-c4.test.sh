#!/usr/bin/env bash
# ov-c4.sh skeleton | includes [<module>] (T055, FR-040–FR-042, Scenario 5.3,
# SC-006).
set -euo pipefail
# shellcheck source-path=SCRIPTDIR
# shellcheck source=ov-test-lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/ov-test-lib.sh"

# shellcheck disable=SC2329 # invoked through assert_exit / ov_t_run
c4() { # c4 <dir> <args...>
  local d=$1
  shift
  cd "$d" && CLAUDE_PROJECT_DIR=$d .specify/extensions/ov/scripts/bash/ov-c4.sh "$@"
}
new_proj() { # new_proj <dir> [with-srs]
  mkdir -p "$1"
  ov_t_install_copy "$1"
  if [[ ${2:-} == with-srs ]]; then
    mkdir -p "$1/docs/srs"
    printf '# S\n\n## Purpose\n\nx\n\n## Module: a\n\nPaths: src/a/**\n\n## Module: b\n\nPaths: src/b/**\n' >"$1/docs/srs/SRS.md"
  fi
}
region() { # region <file>: the lines between the include markers
  awk '/ov:includes:end/ { on = 0 } on { sub(/^[ \t]+/, ""); print } /ov:includes:begin/ { on = 1 }' "$1"
}
outside() { # outside <file>: every line outside the markers
  awk '/ov:includes:begin/ { on = 1; print; next } /ov:includes:end/ { on = 0 } !on { print }' "$1"
}

ov_t_section "skeleton"
ov_t_scratch
p="$OV_T_DIR/proj"
new_proj "$p" with-srs
assert_exit 0 c4 "$p" skeleton
assert_contains "$OV_T_OUT" "created: docs/workspace.dsl"
ws="$p/docs/workspace.dsl"
assert_eq "$(<"$p/.specify/extensions/ov/templates/ov-workspace.dsl")" "$(<"$ws")" "workspace.dsl is the template"
assert_contains "$(<"$ws")" "!identifiers hierarchical" "hierarchical identifiers"
assert_contains "$(<"$ws")" "// ov:includes:begin" "begin marker"
assert_contains "$(<"$ws")" "// ov:includes:end" "end marker"
assert_eq "" "$(region "$ws")" "empty include region"
printf '// mine\n' >>"$ws"
assert_exit 0 c4 "$p" skeleton
assert_contains "$OV_T_OUT" "exists, kept: docs/workspace.dsl"
assert_contains "$(tail -n 1 "$ws")" "// mine" "existing workspace.dsl kept"

ov_t_section "includes, all modules"
before_outside=$(outside "$ws")
assert_exit 0 c4 "$p" includes
assert_eq $'!include c4/a.dsl\n!include c4/b.dsl' "$(region "$ws")" "one include per module, sorted"
assert_file "$p/docs/c4/a.dsl" "stub a.dsl"
assert_file "$p/docs/c4/b.dsl" "stub b.dsl"
assert_eq "// C3/C4 for a: written by /speckit-ov-c4-code" "$(<"$p/docs/c4/a.dsl")" "stub content"
assert_eq "$before_outside" "$(outside "$ws")" "lines outside the markers untouched"
ind=$(grep -E '!include c4/a.dsl' "$ws" | sed -E 's/!include.*//')
mark=$(grep -E 'ov:includes:begin' "$ws" | sed -E 's|//.*||')
assert_eq "$mark" "$ind" "include lines take the marker's indentation"

ov_t_section "second run is byte-identical (SC-006)"
snap=$(ov_t_snapshot "$p")
assert_exit 0 c4 "$p" includes
assert_eq "$snap" "$(ov_t_snapshot "$p")" "tree unchanged"

ov_t_section "one module leaves the others alone (Scenario 5.3)"
ov_t_scratch
q="$OV_T_DIR/proj"
new_proj "$q" with-srs
c4 "$q" skeleton >/dev/null
mkdir -p "$q/docs/c4"
printf 'custom b\n' >"$q/docs/c4/b.dsl"
b_sha=$(_ov_t_sha256 "$q/docs/c4/b.dsl")
assert_exit 0 c4 "$q" includes a
assert_eq "$b_sha" "$(_ov_t_sha256 "$q/docs/c4/b.dsl")" "b.dsl byte-identical"
assert_eq "!include c4/a.dsl" "$(region "$q/docs/workspace.dsl")" "only a's include added"
assert_file "$q/docs/c4/a.dsl" "a stub created"
assert_exit 0 c4 "$q" includes
assert_eq "custom b" "$(<"$q/docs/c4/b.dsl")" "an existing module file is never overwritten"
assert_exit 1 c4 "$q" includes nope
assert_contains "$OV_T_ERR" "nope" "unknown module refused"

ov_t_section "missing pieces"
ov_t_scratch
r="$OV_T_DIR/proj"
new_proj "$r"
c4 "$r" skeleton >/dev/null
assert_exit 1 c4 "$r" includes
assert_contains "$OV_T_ERR" "/speckit-ov-srs" "missing SRS names /speckit-ov-srs"
ov_t_scratch
s="$OV_T_DIR/proj"
new_proj "$s" with-srs
assert_exit 1 c4 "$s" includes
assert_contains "$OV_T_ERR" "/speckit-ov-c4-context" "missing workspace.dsl names /speckit-ov-c4-context"
c4 "$s" skeleton >/dev/null
sed -i.bak '/ov:includes:end/d' "$s/docs/workspace.dsl"
rm -f "$s/docs/workspace.dsl.bak"
snap=$(ov_t_snapshot "$s")
assert_exit 1 c4 "$s" includes
assert_contains "$OV_T_ERR" "marker" "missing marker reported"
assert_eq "$snap" "$(ov_t_snapshot "$s")" "nothing written"

ov_t_section "usage"
assert_exit 1 c4 "$s" bogus

ov_t_done
