#!/usr/bin/env bash
# Tests for extensions/ov/scripts/bash/ov-aiignore-match.sh (T004, R-4).
set -euo pipefail
# shellcheck source-path=SCRIPTDIR
# shellcheck source=ov-test-lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/ov-test-lib.sh"

match="$OV_REPO/extensions/ov/scripts/bash/ov-aiignore-match.sh"

ov_t_scratch
work=$OV_T_DIR
ov_t_scratch
TMPDIR=$OV_T_DIR
export TMPDIR

pat="$work/patterns"
printf 'src/core/\n*.lock\n!keep.lock\ndocs/**/x.md\n' >"$pat"

ov_t_section "gitignore semantics"
assert_exit 0 "$match" "$pat" src/core/a/b.rs
assert_eq "src/core/a/b.rs" "$OV_T_OUT" "prints the matching path"
assert_exit 1 "$match" "$pat" src/corex.rs
assert_exit 0 "$match" "$pat" a.lock
assert_exit 1 "$match" "$pat" keep.lock
assert_exit 0 "$match" "$pat" docs/x.md
assert_exit 0 "$match" "$pat" docs/a/b/x.md
assert_exit 1 "$match" "$pat" docs/a/y.md
assert_no_file "$work/src" "paths that do not exist on disk still match"

ov_t_section "--stdin"
ov_t_run bash -c "printf 'src/core/a.rs\nsrc/main.rs\nb.lock\nkeep.lock\n' | '$match' '$pat' --stdin"
assert_eq "0" "$OV_T_RC" "stdin with matches exits 0"
assert_eq $'src/core/a.rs\nb.lock' "$OV_T_OUT" "stdin prints only the matching paths"
ov_t_run bash -c "printf 'src/main.rs\n' | '$match' '$pat' --stdin"
assert_eq "1" "$OV_T_RC" "stdin without matches exits 1"
assert_eq "" "$OV_T_OUT" "stdin without matches prints nothing"

ov_t_section "no leaks from .gitignore or global excludes"
ov_t_scratch
cwdrepo=$OV_T_DIR
ov_t_git_init "$cwdrepo"
printf 'leak.txt\n' >"$cwdrepo/.gitignore"
mkdir -p "$cwdrepo/home"
printf 'globalleak.txt\n' >"$cwdrepo/home/excludes"
printf '[core]\n\texcludesFile = %s\n' "$cwdrepo/home/excludes" >"$cwdrepo/home/.gitconfig"
printf 'gitinfo.txt\n' >"$cwdrepo/.git/info/exclude"
ov_t_run bash -c "cd '$cwdrepo' && env -u GIT_CONFIG_GLOBAL -u GIT_CONFIG_NOSYSTEM HOME='$cwdrepo/home' XDG_CONFIG_HOME='$cwdrepo/home' git check-ignore -q globalleak.txt"
assert_eq "0" "$OV_T_RC" "sanity: the temp HOME global excludes file is active for plain git"
for p in leak.txt globalleak.txt gitinfo.txt; do
  ov_t_run bash -c "cd '$cwdrepo' && env -u GIT_CONFIG_GLOBAL -u GIT_CONFIG_NOSYSTEM HOME='$cwdrepo/home' XDG_CONFIG_HOME='$cwdrepo/home' '$match' '$pat' '$p'"
  assert_eq "1" "$OV_T_RC" "$p is not matched"
done

ov_t_section "cache"
rm -rf "${TMPDIR:?}"/ov-aiignore-*
"$match" "$pat" a.lock >/dev/null
"$match" "$pat" b.lock >/dev/null
cp "$pat" "$work/patterns-copy"
"$match" "$work/patterns-copy" c.lock >/dev/null
caches=$(find "$TMPDIR" -maxdepth 1 -name 'ov-aiignore-*' | wc -l | tr -d ' ')
assert_eq "1" "$caches" "same content reuses one cache dir"
hash=$(sha256sum "$pat" 2>/dev/null | cut -d' ' -f1 || shasum -a 256 "$pat" | cut -d' ' -f1)
assert_file "$TMPDIR/ov-aiignore-$hash/info/exclude" "cache dir is named by the content sha256"
assert_eq "$(cat "$pat")" "$(cat "$TMPDIR/ov-aiignore-$hash/info/exclude")" "info/exclude holds the patterns"
printf 'other/\n' >>"$work/patterns-copy"
"$match" "$work/patterns-copy" other/x >/dev/null
caches=$(find "$TMPDIR" -maxdepth 1 -name 'ov-aiignore-*' | wc -l | tr -d ' ')
assert_eq "2" "$caches" "changed content gets a new cache dir"
leftovers=$(find "$TMPDIR" -maxdepth 1 -name 'ov-aiignore-build.*' | wc -l | tr -d ' ')
assert_eq "0" "$leftovers" "no build dirs left behind"

ov_t_section "sourced function"
# shellcheck source=SCRIPTDIR/../extensions/ov/scripts/bash/ov-aiignore-match.sh
source "$match"
assert_exit 0 ov_aiignore_match "$pat" src/core/z.rs
assert_exit 1 ov_aiignore_match "$pat" src/z.rs

ov_t_section "exit codes"
assert_exit 2 "$match"
assert_exit 2 "$match" "$pat"
assert_exit 2 "$match" "$work/no-such-file" a.lock
assert_exit 2 "$match" "$pat" --stdin extra
empty="$work/empty"
: >"$empty"
assert_exit 1 "$match" "$empty" a.lock

ov_t_done
