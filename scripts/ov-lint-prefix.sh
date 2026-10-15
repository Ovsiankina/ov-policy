#!/usr/bin/env bash
# Principle I mechanism (R-12): every shipped or repo-tooling file is named
# ov-*, except the names spec-kit imposes. Also checks that every command in
# extensions/ov/extension.yml is named speckit.ov.<cmd>.
#
# usage: scripts/ov-lint-prefix.sh [root]   (root defaults to the repo root)
# Exit 0 when clean, 1 listing every offender.
set -euo pipefail

root=${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}
cd "$root"

offenders=()

allowed() {
  local rel=$1 base=${1##*/}
  case $base in
    ov-*) return 0 ;;
    extension.yml | preset.yml | bundle.yml | .extensionignore) return 0 ;;
  esac
  [[ $rel =~ ^extensions/ov/commands/speckit\.ov\.[^/]+\.md$ ]]
}

for dir in extensions/ov presets/ov-policy bundles/ov scripts tests .github/workflows; do
  [[ -d $dir ]] || continue
  while IFS= read -r -d '' f; do
    f=${f#./}
    allowed "$f" || offenders+=("unprefixed file: $f")
  done < <(find "$dir" -type f -print0)
done

manifest=extensions/ov/extension.yml
if [[ -f $manifest ]]; then
  while IFS= read -r name; do
    [[ $name =~ ^speckit\.ov\.[a-z0-9-]+$ ]] ||
      offenders+=("command name not speckit.ov.<cmd>: $name ($manifest)")
  done < <(awk '
    function lead(s) { match(s, /^ */); return RLENGTH }
    /^[ \t]*(#.*)?$/ { next }
    {
      ind = lead($0); line = substr($0, ind + 1)
      if (ind == 0) { in_provides = (line ~ /^provides:[ \t]*$/); in_cmds = 0; next }
      if (!in_provides) next
      if (in_cmds && ind <= cmd_ind && line !~ /^-/) in_cmds = 0
      if (!in_cmds) {
        if (line ~ /^commands:[ \t]*$/) { in_cmds = 1; cmd_ind = ind }
        next
      }
      sub(/^-[ \t]*/, "", line)
      if (line ~ /^name:/) {
        sub(/^name:[ \t]*/, "", line); sub(/[ \t]+#.*$/, "", line); sub(/[ \t]+$/, "", line)
        gsub(/^["\047]|["\047]$/, "", line)
        print line
      }
    }
  ' "$manifest")
fi

if ((${#offenders[@]})); then
  printf 'ov-lint-prefix: %d offender(s)\n' "${#offenders[@]}" >&2
  printf '  %s\n' "${offenders[@]}" >&2
  exit 1
fi
printf 'ov-lint-prefix: ok\n'
