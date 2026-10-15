#!/usr/bin/env bash
# Keep presets/ov-policy/templates/ov-policy.md a byte-for-byte copy of the
# author's POLICY.md (research R-10). Never writes POLICY.md.
#
# usage: scripts/ov-sync-policy.sh [--check]
#   (no flag)  copy POLICY.md to the preset; refuses when POLICY.md is missing
#              or its first line is not <!-- ov-policy -->
#   --check    exit 1 when the marker is missing or the copy differs. Before the
#              author writes POLICY.md, passes only while the copy is exactly
#              the marker line.
# The repo root is ${OV_REPO_ROOT:-<this repo>}.
set -euo pipefail

root=${OV_REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}
policy="$root/POLICY.md"
copy="$root/presets/ov-policy/templates/ov-policy.md"
marker='<!-- ov-policy -->'

die() {
  printf 'ov-sync-policy: %s\n' "$*" >&2
  exit 1
}

has_marker() {
  local first
  IFS= read -r first <"$1" || [[ -n $first ]] || return 1
  [[ ${first%$'\r'} == "$marker" ]]
}

case ${1:-} in
  --check)
    if [[ ! -e $policy ]]; then
      printf 'ov-sync-policy: POLICY.md not written yet\n'
      [[ -f $copy && $(cat "$copy") == "$marker" && $(wc -l <"$copy" | tr -d ' ') == 1 ]] ||
        die "POLICY.md is absent, so $copy must hold exactly the line $marker"
      exit 0
    fi
    has_marker "$policy" || die "POLICY.md must start with the line $marker"
    if [[ ! -f $copy ]] || ! cmp -s "$policy" "$copy"; then
      die "$copy differs from POLICY.md; run scripts/ov-sync-policy.sh"
    fi
    printf 'ov-sync-policy: preset copy matches POLICY.md\n'
    ;;
  '')
    [[ -f $policy ]] || die "POLICY.md not found; the author writes it first"
    has_marker "$policy" || die "POLICY.md must start with the line $marker; refusing to sync"
    mkdir -p "$(dirname "$copy")"
    if [[ -f $copy ]] && cmp -s "$policy" "$copy"; then
      printf 'ov-sync-policy: unchanged: %s\n' "${copy#"$root"/}"
    else
      cp "$policy" "$copy"
      printf 'ov-sync-policy: updated: %s\n' "${copy#"$root"/}"
    fi
    ;;
  *) die "usage: scripts/ov-sync-policy.sh [--check]" ;;
esac
