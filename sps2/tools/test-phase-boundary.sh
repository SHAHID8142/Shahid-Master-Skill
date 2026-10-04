#!/usr/bin/env bash
# Mutation-test the phase-aware P6 boundary in validate-p5.py section 14.
# Each mutation must make validate-p5.sh-equivalent (validate-p5.py) FAIL.
set -uo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEC="$REPO/sps2/decisions/P6-DECISIONS.json"
REG="$REPO/sps2/capability/registry.json"
BAK="$(mktemp)"
cp "$DEC" "$BAK"
PASSN=0; FAILN=0

mutate() {  # mutate <label> <target> <python-body>
  local label="$1" target="$2" body="$3" out
  cp "$BAK" "$DEC"
  python3 - "$target" "$body" <<'PY'
import json, sys
p, body = sys.argv[1], sys.argv[2]
d = json.load(open(p))
exec(body)
json.dump(d, open(p, "w"), indent=2)
PY
  if [ $? -ne 0 ]; then
    echo "  ERROR   $label (mutation did not apply)"; FAILN=$((FAILN+1)); return
  fi
  out="$(python3 "$REPO/sps2/tools/validate-p5.py" 2>&1)"
  if printf '%s' "$out" | grep -q 'P5 IMPLEMENTATION VALID'; then
    echo "  MISSED  $label"; FAILN=$((FAILN+1))
  else
    echo "  CAUGHT  $label  ->  $(printf '%s' "$out" | grep -oE \
      'P6_DECISION_[A-Z_]*|RUNTIME_STATE_PRESENT|PRODUCTION_COUNT_CHANGED|CAP005_NOT_DEFERRED|P7_ARTIFACT_CREATED' \
      | sort -u | tr '\n' ' ')"
    PASSN=$((PASSN+1))
  fi
  cp "$BAK" "$DEC"
}

echo "MUTATION TESTS — phase-aware P6 boundary"
mutate "M1 D-P6-1 decision removed" "$DEC" \
  "d['decisions'] = [x for x in d['decisions'] if x['decision_id'] != 'D-P6-1']"
mutate "M2 D-P6-2 decision removed" "$DEC" \
  "d['decisions'] = [x for x in d['decisions'] if x['decision_id'] != 'D-P6-2']"
mutate "M3 D-P6-1 attributed to an agent" "$DEC" \
  "[x['approval'].__setitem__('decided_by', 'Cline') for x in d['decisions'] if x['decision_id'] == 'D-P6-1']"
mutate "M4 D-P6-2 approval state downgraded" "$DEC" \
  "[x['approval'].__setitem__('state', 'PENDING_USER_APPROVAL') for x in d['decisions'] if x['decision_id'] == 'D-P6-2']"
mutate "M5 D-P6-1 undated" "$DEC" \
  "[x['approval'].pop('decided_at', None) for x in d['decisions'] if x['decision_id'] == 'D-P6-1']"

cp "$BAK" "$DEC"
rm -f "$BAK"
echo ""
if [ "$FAILN" -eq 0 ]; then
  echo "== PHASE BOUNDARY MUTATION SUITE: $PASSN caught, $FAILN missed =="
  exit 0
fi
echo "== PHASE BOUNDARY MUTATION SUITE: $PASSN caught, $FAILN MISSED =="
exit 1