#!/usr/bin/env bash
# Guard latency (T018, SC-007): median of 50 warm runs on a listed-path Edit
# payload must be at most 200 ms.
set -euo pipefail
# shellcheck source-path=SCRIPTDIR
# shellcheck source=ov-test-lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/ov-test-lib.sh"

runs=50
budget_ms=200

# now_us: wall clock in microseconds, or empty without sub-second time.
now_us() {
  local t
  if [[ -n ${EPOCHREALTIME:-} ]]; then
    t=${EPOCHREALTIME//[.,]/}
    printf '%s\n' "$t"
    return
  fi
  t=$(date +%s%N 2>/dev/null || true)
  if [[ $t =~ ^[0-9]{19,}$ ]]; then
    printf '%s\n' "$((t / 1000))"
  fi
}
[[ -n $(now_us) ]] || ov_t_skip "no sub-second clock (\$EPOCHREALTIME or date +%N)"

ov_t_scratch
proj="$OV_T_DIR/proj"
mkdir -p "$proj"
ov_t_install_copy "$proj"
tmpl="$proj/.specify/extensions/ov/templates/ov-aiignore"
[[ -f $tmpl ]] || { _ov_t_bad "templates/ov-aiignore exists"; ov_t_done; }
cp "$tmpl" "$proj/.aiignore"
# 20 extra patterns; the last one lists the payload's path.
for i in $(seq 1 19); do
  printf 'src/mod%02d/**\n' "$i" >>"$proj/.aiignore"
done
printf 'src/core/\n' >>"$proj/.aiignore"

guard="$proj/.specify/extensions/ov/scripts/bash/ov-guard.sh"
body=$(<"$OV_REPO/tests/fixtures/ov-guard-edit.json")
body=${body//__ROOT__/$proj}
body=${body//__PATH__/$proj/src/core/x.rs}
payload="$OV_T_DIR/payload.json"
printf '%s\n' "$body" >"$payload"
export CLAUDE_PROJECT_DIR=$proj

ov_t_section "warm-up (discarded)"
assert_exit 2 "$guard" <"$payload"

ov_t_section "$runs timed runs"
samples=()
for _ in $(seq 1 "$runs"); do
  t0=$(now_us)
  "$guard" <"$payload" 2>/dev/null || true
  t1=$(now_us)
  samples+=("$((t1 - t0))")
done
mapfile -t sorted < <(printf '%s\n' "${samples[@]}" | sort -n)
median_us=$(((sorted[runs / 2 - 1] + sorted[runs / 2]) / 2))
p90_us=${sorted[$((runs * 9 / 10 - 1))]}
max_us=${sorted[$((runs - 1))]}
ms() { printf '%d.%03d' "$(($1 / 1000))" "$(($1 % 1000))"; }
printf '  guard latency over %d runs: median %s ms, p90 %s ms, max %s ms\n' \
  "$runs" "$(ms "$median_us")" "$(ms "$p90_us")" "$(ms "$max_us")"
if ((median_us <= budget_ms * 1000)); then
  _ov_t_ok "median $(ms "$median_us") ms <= $budget_ms ms (SC-007)"
else
  _ov_t_bad "median $(ms "$median_us") ms <= $budget_ms ms (SC-007)"
fi

ov_t_done
