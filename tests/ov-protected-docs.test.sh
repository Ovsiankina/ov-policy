#!/usr/bin/env bash
# No shipped command, script or template references, and so writes, the
# human-owned README.md or POLICY.md (T067, FR-061, Principle VI).
set -euo pipefail
# shellcheck source-path=SCRIPTDIR
# shellcheck source=ov-test-lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/ov-test-lib.sh"

ov_t_section "extensions/ov"
hits=$(grep -rnE 'README\.md|POLICY\.md' "$OV_REPO/extensions/ov" || true)
assert_eq "" "$hits" "no reference to README.md or POLICY.md under extensions/ov"
assert_no_file "$OV_REPO/extensions/ov/README.md" "the extension ships no README.md (R-1)"

ov_t_done
