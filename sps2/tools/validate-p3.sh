#!/usr/bin/env bash
# SPS 2.0 P3 production capability validator.
# Tests ACTUAL structured behaviour: promotion gate, deterministic ranking,
# forced choice, staleness, provenance, approval attribution, project locality.
# SAFETY: no network, no installs, no machine-global writes, never modifies a
# real file. Negative fixtures live only in a self-managed temp dir.
# Usage: bash sps2/tools/validate-p3.sh [--negative]
# Exit:  0 valid | 1 failure | 2 tooling unavailable

set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPS2="$(cd "$HERE/.." && pwd)"
REPO="$(cd "$SPS2/.." && pwd)"
CHECK="$HERE/check_p3.py"
ENGINE="$SPS2/capability/engine.py"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[1;34m'
BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'
PASS=0; FAIL=0; NEG_PASS=0; NEG_FAIL=0
pass() { echo -e "  ${GREEN}PASS${NC}  $*"; PASS=$((PASS+1)); }
fail() { echo -e "  ${RED}FAIL${NC}  $*"; FAIL=$((FAIL+1)); }
info() { echo -e "  ${BLUE}CASE${NC} $*"; }
warn() { echo -e "  ${YELLOW}WARN${NC}  $*"; }
sect() { echo -e "\n${BOLD}$*${NC}"; }

command -v python3 >/dev/null 2>&1 || { echo "python3 unavailable"; exit 2; }
TMP="$(mktemp -d "${TMPDIR:-/tmp}/sps2p3-XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

NEG_ONLY=false
for a in "$@"; do [ "$a" = "--negative" ] && NEG_ONLY=true; done

echo -e "${BOLD}SPS 2.0 P3 Production Capability Validator${NC}"
echo -e "${DIM}behavioural validation of gate, ranking, staleness and provenance${NC}"

# shared fixture generator (written only to the temp dir)
cat > "$TMP/mk.py" <<'FIXT'
import json, sys
d = {
  "capability_id": "CAP-SPS-900", "name": "fixture", "type": "DEV_TOOL",
  "domain": "governance", "purpose": "A valid fixture purpose for tests",
  "version": "1.0.0", "source": "SPS2_CORE", "licence": "KNOWN_PERMISSIVE",
  "licence_evidence": "fixture", "origin": "SPS_CORE",
  "provenance": {"origin": "fixture", "commit": "abc1234",
                 "fact_class": "FACT", "captured_at": "2026-10-03"},
  "security": {"status": "VERIFIED_SAFE", "evidence": "fixture",
               "fact_class": "EVIDENCE"},
  "compatibility": {"status": "COMPATIBLE", "agent_neutral": True,
                    "basis": "fixture"},
  "staleness": {"state": "CURRENT", "maintenance": "ACTIVE",
                "last_checked": "2026-10-03", "review_due": "2027-01-01"},
  "install_scope": "PROJECT_LOCAL", "evidence": ["EV-P3-001"],
  "confidence": "HIGH", "lifecycle_state": "CANDIDATE",
  "approval": {"state": "PENDING_USER_APPROVAL"},
  "verification": {"state": "UNVERIFIED", "evidence": []},
  "selection_policy": {"popularity_role": "TIE_BREAKER_ONLY"},
}
exec(sys.argv[1])
print(json.dumps(d))
FIXT

mk() { python3 "$TMP/mk.py" "$1" > "$TMP/f.json"; }

gate() {  # mutation expect-regex label
  mk "$1"
  local out; out="$(python3 "$CHECK" gate "$TMP/f.json" 2>&1)"
  if printf '%s\n' "$out" | grep -q 'REJECTED' \
     && printf '%s\n' "$out" | grep -qiE -- "$2"; then
    info "REJECTED -> $3"; NEG_PASS=$((NEG_PASS+1)); pass "$3 -> rejected"
  else
    info "NOT REJECTED (validator defect!) -> $3"
    NEG_FAIL=$((NEG_FAIL+1)); fail "$3 -> NOT rejected (out: ${out:-none})"
  fi
}

if [ "$NEG_ONLY" != true ]; then

sect "1. P3 deliverables present"
for f in capability/engine.py capability/registry.json \
         project/SELECTION-P3-0001.json tools/check_p3.py \
         requirements/P3-REQUIREMENTS.json evidence/P3-EVIDENCE.json \
         decisions/P3-DECISIONS.json tasks/P3-TASKS.md \
         handoff/HANDOFF-P3.json; do
  [ -f "$SPS2/$f" ] && pass "present $f" || fail "missing $f"
done
[ -f "$REPO/AUDIT-PHASE-07-P3-PRODUCTION-CAPABILITY.md" ] \
  && pass "present AUDIT-PHASE-07 report" || fail "missing AUDIT-PHASE-07 report"

sect "2. Production registry and selection record validate"
OUT=$(python3 "$CHECK" registry "$SPS2/capability/registry.json" 2>&1)
[ -z "$OUT" ] && pass "registry passes promotion gate and integrity checks" \
  || while IFS= read -r l; do [ -n "$l" ] && fail "registry: $l"; done <<< "$OUT"
OUT=$(python3 "$CHECK" selection "$SPS2/capability/registry.json" \
      "$SPS2/project/SELECTION-P3-0001.json" 2>&1)
[ -z "$OUT" ] && pass "selection record is traceable and explained" \
  || while IFS= read -r l; do [ -n "$l" ] && fail "selection: $l"; done <<< "$OUT"
for k in requirements evidence decisions; do
  case $k in
    requirements) p="$SPS2/requirements/P3-REQUIREMENTS.json" ;;
    evidence) p="$SPS2/evidence/P3-EVIDENCE.json" ;;
    decisions) p="$SPS2/decisions/P3-DECISIONS.json" ;;
  esac
  OUT=$(python3 "$CHECK" records "$k" "$p" 2>&1)
  [ -z "$OUT" ] && pass "P3 $k validate" \
    || while IFS= read -r l; do [ -n "$l" ] && fail "$k: $l"; done <<< "$OUT"
done
OUT=$(python3 "$CHECK" records handoff "$SPS2/handoff/HANDOFF-P3.json" 2>&1)
[ -z "$OUT" ] && pass "P3 handoff validates" \
  || while IFS= read -r l; do [ -n "$l" ] && fail "handoff: $l"; done <<< "$OUT"

sect "3. P3 is NOT self-approved"
jq -e '[.requirements[].approval.state] | all(. == "PENDING_USER_APPROVAL")' \
  "$SPS2/requirements/P3-REQUIREMENTS.json" >/dev/null 2>&1 \
  && pass "all P3 requirements remain PENDING_USER_APPROVAL" \
  || fail "a P3 requirement claims approval"
jq -e '[.decisions[].approval.state] | all(. == "PENDING_USER_APPROVAL")' \
  "$SPS2/decisions/P3-DECISIONS.json" >/dev/null 2>&1 \
  && pass "all P3 decisions remain PENDING_USER_APPROVAL" \
  || fail "a P3 decision claims approval"
jq -e '.handoffs[0].user_approval == "PENDING_USER_APPROVAL"' \
  "$SPS2/handoff/HANDOFF-P3.json" >/dev/null 2>&1 \
  && pass "P3 handoff approval pending" || fail "P3 handoff approval changed"

sect "3. Promotion gate positive control"
mk "pass"
GATE_OUT="$(python3 "$CHECK" gate "$TMP/f.json" 2>&1)"
if printf '%s\n' "$GATE_OUT" | grep -q '^PROMOTED$'; then
  NEG_PASS=$((NEG_PASS+1)); pass "POSCTRL-1  a valid capability IS promoted"
else
  info "WRONGLY REJECTED (over-blocking) -> POSCTRL-1: $GATE_OUT"
  NEG_FAIL=$((NEG_FAIL+1)); fail "POSCTRL-1  valid capability was wrongly rejected"
fi

sect "4. Registry composition and project-locality"
NCAP=$(jq -r '.capabilities|length' "$SPS2/capability/registry.json")
NDEF=$(jq -r '.deferred|length' "$SPS2/capability/registry.json")
pass "registry holds $NCAP promoted capabilities and $NDEF deferred/rejected records"
jq -e '[.capabilities[].install_scope] | all(. == "PROJECT_LOCAL")' \
  "$SPS2/capability/registry.json" >/dev/null 2>&1 \
  && pass "every registered capability is PROJECT_LOCAL" \
  || fail "a registered capability is not project-local"
jq -e '[.capabilities[].approval.state] | all(. != "APPROVED")' \
  "$SPS2/capability/registry.json" >/dev/null 2>&1 \
  && pass "no capability is marked APPROVED by the agent" \
  || fail "a capability claims approval without user authority"
jq -e '[.deferred[].reason] | all(. != null and length > 10)' \
  "$SPS2/capability/registry.json" >/dev/null 2>&1 \
  && pass "every deferred candidate carries a stated reason" \
  || fail "a deferred candidate has no reason"

sect "5. Research stays research"
jq -e '[.capabilities[].origin] | all(. != "RESEARCH_ONLY")' \
  "$SPS2/capability/registry.json" >/dev/null 2>&1 \
  && pass "no research-only record appears in production" \
  || fail "research-only record leaked into production"
jq -e '.conflicts[0].resolution | test("UNRESOLVED")' \
  "$SPS2/research/P2-SOURCES.json" >/dev/null 2>&1 \
  && pass "CONF-001 (LCP/INP) still UNRESOLVED" || fail "CONF-001 was silently closed"
jq -e '.capabilities[] | select(.capability_id=="CAP-028") | .status == "UNVERIFIED"' \
  "$SPS2/research/P2-CAPABILITY-EXTRACTION.json" >/dev/null 2>&1 \
  && pass "CAP-028 still UNVERIFIED" || fail "CAP-028 was upgraded"

sect "6. Determinism and popularity discipline"
DET=$(python3 - "$ENGINE" <<'PY'
import importlib.util, itertools, json, sys
spec = importlib.util.spec_from_file_location("eng", sys.argv[1])
eng = importlib.util.module_from_spec(spec); spec.loader.exec_module(eng)
reg = json.load(open(sys.argv[1].replace("/capability/engine.py",
                                        "/capability/registry.json")))
caps = reg["capabilities"]
req = {"domains": ["seo"], "required_capabilities": []}
print(len({eng.select(list(p), req)["fingerprint"]
           for p in itertools.islice(itertools.permutations(caps), 24)}))
PY
)
[ "$DET" = "1" ] && pass "ranking identical across 24 input permutations" \
  || fail "ranking is NOT deterministic ($DET distinct results)"
jq -e '.popularity_role == "TIE_BREAKER_ONLY" and .recency_role == "TIE_BREAKER_ONLY"' \
  "$SPS2/project/SELECTION-P3-0001.json" >/dev/null 2>&1 \
  && pass "popularity and recency declared as tie-breakers only" \
  || fail "popularity/recency role misdeclared"
jq -e '.provenance.runtime_tracing == false' \
  "$SPS2/project/SELECTION-P3-0001.json" >/dev/null 2>&1 \
  && pass "provenance does not overclaim runtime tracing" \
  || fail "provenance overclaims runtime tracing"

sect "7. Forced user choice is respected"
FC=$(python3 - "$ENGINE" <<'PY'
import importlib.util, json, sys
spec = importlib.util.spec_from_file_location("eng", sys.argv[1])
eng = importlib.util.module_from_spec(spec); spec.loader.exec_module(eng)
reg = json.load(open(sys.argv[1].replace("/capability/engine.py",
                                        "/capability/registry.json")))
caps = reg["capabilities"]; req = {"domains": ["seo"], "required_capabilities": []}
res = eng.select(caps, req)
last = res["ranking"][-1]["capability_id"]
forced, info = eng.apply_forced_choice(res["ranking"], last, caps)
ok1 = forced[0]["capability_id"] == last and info["forced"]
bad = json.loads(json.dumps(caps[-1]))
bad["capability_id"] = "CAP-SPS-901"
bad["security"] = {"status": "VULNERABLE", "evidence": "x", "fact_class": "EVIDENCE"}
res2 = eng.rank(caps + [bad], req)
f2, i2 = eng.apply_forced_choice(res2, "CAP-SPS-901", caps + [bad])
ok2 = (not i2["forced"]) and "MANDATORY_SAFECY" in i2["reason"]
print("yes" if (ok1 and ok2) else "no")
PY
)
[ "$FC" = "yes" ] && pass "forced choice honoured, and blocked by safety constraints" \
  || fail "forced-choice behaviour is incorrect"

sect "8. Legacy and machine-global protection"
DIFF=$(cd "$REPO" && git diff --name-only c11da27 -- skills scripts plugins .github \
       templates README.md CHANGELOG.md CATALOG.md '*.sh' '*.ps1' 2>/dev/null \
       | grep -v '^sps2/')
[ -z "$DIFF" ] && pass "legacy repository untouched by P3" || fail "legacy modified: $DIFF"
if grep -rqE --exclude-dir=tools 'git config --global|\$HOME/\.(sps|claude|codex|config)' "$SPS2" 2>/dev/null; then
  fail "sps2 references machine-global state"
else
  pass "no machine-global path referenced in sps2"
fi
if find "$SPS2" \( -name 'node_modules' -o -name 'package-lock.json' -o -name '*.whl' \) \
   2>/dev/null | grep -q .; then
  fail "external dependency artefact present"
else
  pass "no dependency installed or vendored"
fi
if git -C "$REPO" --no-pager diff HEAD -- .sps/ | grep -q .; then
  fail "legacy .sps/ governance was modified"
else
  pass "legacy .sps/ governance untouched"
fi

sect "9. No emoji"
EMJ=$(python3 - "$SPS2" <<'PY'
import os, sys, re
pat = re.compile('[\U0001F300-\U0001FAFF\u2600-\u27BF\u2B00-\u2BFF\uFE0F]')
hits = []
for root, dirs, files in os.walk(sys.argv[1]):
    dirs[:] = [d for d in dirs if d not in {'.git', 'node_modules'}]
    for f in files:
        p = os.path.join(root, f)
        try:
            t = open(p, encoding='utf-8', errors='replace').read()
        except Exception:
            continue
        if pat.search(t):
            hits.append(p.replace(sys.argv[1] + '/', ''))
print(';'.join(hits))
PY
)
[ -z "$EMJ" ] && pass "no emoji in any sps2 file" || fail "emoji found: $EMJ"

fi  # end structural

# Cases A-O are mandated by the P3 brief. Each asserts that a real gate rule
# rejects the invalid state, not merely that a string is absent.
sect "NEGATIVE TESTS — invalid P3 states must be rejected"

# A. duplicate capability ID (enforced at registry level)
mk "pass"
python3 - "$TMP/f.json" "$TMP/dup.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
json.dump({"capabilities": [d, dict(d)]}, open(sys.argv[2], "w"))
PY
if python3 "$CHECK" registry "$TMP/dup.json" 2>&1 | grep -q 'DUPLICATE_CAPABILITY_ID'; then
  info "REJECTED -> A  duplicate capability ID"; NEG_PASS=$((NEG_PASS+1))
  pass "A  duplicate capability ID -> rejected"
else
  info "NOT REJECTED -> A"; NEG_FAIL=$((NEG_FAIL+1)); fail "A  duplicate capability ID NOT rejected"
fi

# B. missing evidence
gate "d['evidence']=[]" "MISSING_FIELD.*evidence|MISSING_EVIDENCE" "B  missing evidence"
# C. fabricated provenance
gate "d['provenance']['origin']=''" "FABRICATED_PROVENANCE" "C  fabricated provenance"
# D. unknown security presented as safe
gate "d['security']={'status':'VERIFIED_SAFE','fact_class':'FACT'}" \
     "UNSUPPORTED_SECURITY" "D  unknown security marked safe"
# E. agent-attributed approval
gate "d['approval']={'state':'APPROVED','decided_by':'agent'}" \
     "AGENT_ATTRIBUTED_APPROVAL" "E  agent-attributed approval"
# F. approval without user attribution
gate "d['approval']={'state':'APPROVED','decided_by':''}" \
     "MISSING_USER_ATTRIBUTION" "F  approval without user attribution"
# G. stale capability without review
gate "d['staleness']={'state':'STALE','maintenance':'ACTIVE','last_checked':'2026-10-03'}" \
     "STALE_WITHOUT_REVIEW" "G  stale without review"
# G2. stale treated as active
gate "d['staleness']={'state':'STALE','maintenance':'ACTIVE','last_checked':'2026-10-03','review_due':'2027-01-01'};d['lifecycle_state']='ACTIVE';d['verification']={'state':'VERIFIED','evidence':['EV-P3-001']}" \
     "STALE_AS_ACTIVE" "G2 stale treated as ACTIVE"
# H. unsupported compatibility claim
gate "d['compatibility']={'status':'COMPATIBLE','agent_neutral':False,'basis':'x'}" \
     "UNSUPPORTED_COMPATIBILITY" "H  unsupported compatibility claim"
# I. global capability without authorization
gate "d['install_scope']='GLOBAL'" "GLOBAL_WITHOUT_AUTHORIZATION" "I  global without authorization"
# J. malformed capability record
gate "d['capability_id']='not-an-id'" "INVALID_ID" "J  malformed capability record"
# M. invalid lifecycle transition
gate "d['lifecycle_state']='ACTIVE';d['verification']={'state':'VERIFIED','evidence':[]}" \
     "UNVERIFIED_IMPLEMENTATION" "M  invalid lifecycle transition"
# O. unapproved research-only capability in production
gate "d['origin']='RESEARCH_ONLY'" "RESEARCH_ONLY_LEAK" "O  research-only capability promoted"
# K. deterministic ranking violation (selection record with reordered scores)
python3 - "$SPS2" "$TMP/badrank.json" <<'PY'
import json, sys
sel = json.load(open(sys.argv[1] + "/project/SELECTION-P3-0001.json"))
r = sel["ranking"]; r[0]["score"], r[-1]["score"] = r[-1]["score"], r[0]["score"]
json.dump(sel, open(sys.argv[2], "w"))
PY
if python3 "$CHECK" selection "$SPS2/capability/registry.json" "$TMP/badrank.json" 2>&1 \
     | grep -q 'DETERMINISM_VIOLATION'; then
  info "REJECTED -> K  deterministic ranking violation"; NEG_PASS=$((NEG_PASS+1))
  pass "K  deterministic ranking violation -> rejected"
else
  info "NOT REJECTED -> K"; NEG_FAIL=$((NEG_FAIL+1)); fail "K  ranking violation NOT rejected"
fi

# L. forced user selection being overridden
python3 - "$ENGINE" > "$TMP/forced.txt" 2>&1 <<'PY'
import importlib.util, json, sys
spec = importlib.util.spec_from_file_location("eng", sys.argv[1])
eng = importlib.util.module_from_spec(spec); spec.loader.exec_module(eng)
reg = json.load(open(sys.argv[1].replace("/capability/engine.py",
                                        "/capability/registry.json")))
caps = reg["capabilities"]; req = {"domains": ["seo"], "required_capabilities": []}
res = eng.select(caps, req)
chosen = res["ranking"][-1]["capability_id"]
forced, info = eng.apply_forced_choice(res["ranking"], chosen, caps)
print("OVERRIDDEN" if forced[0]["capability_id"] != chosen else "HONOURED")
PY
if grep -q 'HONOURED' "$TMP/forced.txt"; then
  info "REJECTED -> L  forced user choice silently overridden"; NEG_PASS=$((NEG_PASS+1))
  pass "L  forced user choice NOT overridden -> enforced"
else
  info "FORCED CHOICE WAS OVERRIDDEN (defect) -> L"; NEG_FAIL=$((NEG_FAIL+1))
  fail "L  forced user choice was overridden"
fi

# N. missing rollback information
python3 - "$SPS2" "$TMP/noroll.json" <<'PY'
import json, sys
sel = json.load(open(sys.argv[1] + "/project/SELECTION-P3-0001.json"))
sel.pop("rollback", None)
json.dump(sel, open(sys.argv[2], "w"))
PY
if python3 "$CHECK" selection "$SPS2/capability/registry.json" "$TMP/noroll.json" 2>&1 \
     | grep -q 'MISSING_ROLLBACK'; then
  info "REJECTED -> N  missing rollback information"; NEG_PASS=$((NEG_PASS+1))
  pass "N  missing rollback information -> rejected"
else
  info "NOT REJECTED -> N"; NEG_FAIL=$((NEG_FAIL+1)); fail "N  missing rollback NOT rejected"
fi

# POSCTRL-2: a valid selection record is accepted
if [ -z "$(python3 "$CHECK" selection "$SPS2/capability/registry.json" \
             "$SPS2/project/SELECTION-P3-0001.json" 2>&1)" ]; then
  info "ACCEPTED -> POSCTRL-2 valid selection record"
  NEG_PASS=$((NEG_PASS+1)); pass "POSCTRL-2  valid selection record accepted"
else
  info "WRONGLY REJECTED -> POSCTRL-2"
  NEG_FAIL=$((NEG_FAIL+1)); fail "POSCTRL-2  valid selection record rejected"
fi

echo ""
if [ "$NEG_FAIL" -eq 0 ]; then
  echo -e "${GREEN}${BOLD}== P3 NEGATIVE SUITE: $NEG_PASS cases correctly rejected, 0 missed ==${NC}"
else
  echo -e "${RED}${BOLD}== P3 NEGATIVE SUITE: $NEG_PASS rejected, $NEG_FAIL MISSED ==${NC}"
fi

echo ""
if [ "$FAIL" -eq 0 ] && [ "$NEG_FAIL" -eq 0 ]; then
  echo -e "${GREEN}${BOLD}== P3 PRODUCTION VALID: $PASS checks passed, 0 failed, $NEG_PASS negative/positive controls enforced ==${NC}"
  exit 0
fi
echo -e "${RED}${BOLD}== P3 PRODUCTION INVALID: $PASS passed, $FAIL failed, $NEG_FAIL missed ==${NC}"
exit 1
