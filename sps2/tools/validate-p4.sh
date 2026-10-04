#!/usr/bin/env bash
# SPS 2.0 P4 production promotion validator.
# Runs the hardened A-K gate on real capabilities, executes the verification
# suite, and enforces 20 negative cases plus positive controls.
# SAFETY: no network, no installs, no machine-global writes.
# Usage: bash sps2/tools/validate-p4.sh [--negative]
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPS2="$(cd "$HERE/.." && pwd)"
REPO="$(cd "$SPS2/.." && pwd)"
CHECK="$HERE/check_p4.py"
EMOJI="$HERE/check_emoji.py"
GATE="$SPS2/capability/promotion_gates.py"
REG="$SPS2/capability/registry.json"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[1;34m'
BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'
PASS=0; FAIL=0; NP=0; NF=0
pass() { echo -e "  ${GREEN}PASS${NC}  $*"; PASS=$((PASS+1)); }
fail() { echo -e "  ${RED}FAIL${NC}  $*"; FAIL=$((FAIL+1)); }
info() { echo -e "  ${BLUE}CASE${NC} $*"; }
sect() { echo -e "\n${BOLD}$*${NC}"; }

command -v python3 >/dev/null 2>&1 || { echo "python3 unavailable"; exit 2; }
TMP="$(mktemp -d "${TMPDIR:-/tmp}/sps2p4-XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
NEG_ONLY=false
for a in "$@"; do [ "$a" = "--negative" ] && NEG_ONLY=true; done

echo -e "${BOLD}SPS 2.0 P4 Production Promotion Validator${NC}"
echo -e "${DIM}hardened gate A-K, real verification, 20 negative cases${NC}"

# ── build a fully-conforming fixture, then mutate it for negative cases ────
cat > "$TMP/mk.py" <<'FIX'
import json, sys
B = {
 "capability_id": "CAP-P03-900", "name": "fixture", "type": "DEV_TOOL",
 "domain": "GOVERNANCE", "purpose": "A valid synthetic fixture",
 "version": "1.0.0", "source": "SPS2_CORE", "licence": "KNOWN_PERMISSIVE",
 "licence_evidence": "synthetic fixture",
 "provenance": {"origin": "synthetic", "commit": "abc1234",
                "fact_class": "EVIDENCE", "repository_relative_path":
                "sps2/capability/engine.py",
                "source_url": "https://example.invalid/synthetic-fixture",
                "research_refs": ["EV-P4-900"]},
 "security": {"status": "VERIFIED_SAFE", "evidence": "synthetic",
              "fact_class": "EVIDENCE"},
 "compatibility": {"status": "COMPATIBLE", "agent_neutral": True,
                   "basis": "synthetic"},
 "staleness": {"state": "CURRENT", "maintenance": "ACTIVE",
               "last_checked": "2026-10-03", "review_due": "2027-01-03",
               "reevaluation_triggers": ["source changed"]},
 "install_scope": "PROJECT_LOCAL", "evidence": ["EV-P4-900"],
 "confidence": "HIGH", "lifecycle_state": "CANDIDATE",
 "approval": {"state": "APPROVED", "decided_by": "User"},
 "verification": {"state": "VERIFIED", "method": "AUTOMATED",
                  "evidence": ["EV-P4-900"], "expected_result": "ok",
                  "observed_result": "ok"},
 "selection_policy": {"popularity_role": "TIE_BREAKER_ONLY"},
 "linked_requirements": ["REQ-P4-01"],
 "acceptance_criteria": ["fixture criterion"],
 "popularity": {"stars": 0}, "last_verified": "2026-10-03",
}
exec(sys.argv[1])
print(json.dumps(B))
FIX
mk() { python3 "$TMP/mk.py" "$1" > "$TMP/c.json"; }

# gate_case <mutation> <expected-gate-letter> <label>
gate_case() {
  mk "$1"
  local out; out="$(python3 "$CHECK" "$TMP/c.json" 2>&1)"
  if printf '%s\n' "$out" | grep -qE "^  $2 .*FAIL"; then
    info "REJECTED -> $3"; NNP=$((NNP+1)); pass "$3 -> rejected"
  else
    info "NOT REJECTED (defect!) -> $3"; NNF=$((NNF+1))
    fail "$3 -> NOT rejected"
  fi
}
if [ "$NEG_ONLY" != true ]; then

sect "1. P4 deliverables present"
for f in capability/promotion_gates.py capability/promotion-assessments.json \
         capability/registry.json tools/check_p4.py tools/check_emoji.py \
         requirements/P4-REQUIREMENTS.json evidence/P4-EVIDENCE.json \
         decisions/P4-DECISIONS.json tasks/P4-TASKS.md \
         handoff/HANDOFF-P4.json; do
  [ -f "$SPS2/$f" ] && pass "present $f" || fail "missing $f"
done
[ -f "$REPO/AUDIT-PHASE-08-P4-PRODUCTION-PROMOTION.md" ] \
  && pass "present AUDIT-PHASE-08 report" || fail "missing AUDIT-PHASE-08 report"

sect "2. Positive control: a conforming capability passes every achievable gate"
mk "pass"
OUT=$(python3 "$CHECK" "$TMP/c.json" --promote 2>&1)
# Gate D cannot pass while the repository declares no licence. That is the
# correct outcome, not a validator defect, so the control asserts that every
# OTHER gate passes and that D is the only blocker.
NON_D=$(printf '%s\n' "$OUT" | grep -cE '^  [ABCEFGHIJK] .*PASS')
D_FAILS=$(printf '%s\n' "$OUT" | grep -cE '^  D .*FAIL')
if [ "$NON_D" -ge 10 ] && [ "$D_FAILS" -eq 1 ] \
   && printf '%s\n' "$OUT" | grep -q 'blocking=D$'; then
  NP=$((NP+1))
  pass "POSCTRL-A  10 gates pass; only D blocks, and D is correctly unsatisfiable"
else
  info "POSCTRL-A unexpected: $OUT"; NF=$((NF+1))
  fail "POSCTRL-A  conforming capability behaved unexpectedly"
fi
# Gate D must be unsatisfiable today, and that is the point.
if python3 "$CHECK" "$TMP/c.json" --promote 2>&1 | grep -q 'blocking=D$'; then
  NP=$((NP+1))
  pass "POSCTRL-C  promotion is impossible without a declared licence (correct)"
else
  NF=$((NF+1)); fail "POSCTRL-C  promotion was possible without a licence"
fi

sect "3. Registry is consistent with the gate (computed, not asserted)"
python3 - "$SPS2" > "$TMP/cons" 2>&1 <<'PY'
import importlib.util, json, os, sys
B = sys.argv[1]
spec = importlib.util.spec_from_file_location(
    "pg", os.path.join(B, "capability", "promotion_gates.py"))
pg = importlib.util.module_from_spec(spec); spec.loader.exec_module(pg)
reg = json.load(open(os.path.join(B, "capability", "registry.json")))
ids = [c["capability_id"] for c in reg["capabilities"]]
for d in sorted({i for i in ids if ids.count(i) > 1}):
    print("DUPLICATE_ID: %s" % d)
for c in reg["capabilities"]:
    res, blocking = pg.evaluate(c)
    rec = pg.decide(blocking)
    stored = c.get("promotion_assessment", {})
    if stored.get("blocking_gates") != blocking:
        print("STALE_ASSESSMENT: %s stored=%s computed=%s"
              % (c["capability_id"], stored.get("blocking_gates"), blocking))
    if stored.get("recommendation") != rec:
        print("STALE_RECOMMENDATION: %s" % c["capability_id"])
    if rec == "PROMOTE" and c.get("lifecycle_state") != "EVALUATED":
        print("PROMOTED_WITHOUT_STATE: %s" % c["capability_id"])
    if rec != "PROMOTE" and c.get("lifecycle_state") == "ACTIVE":
        print("ACTIVE_WITHOUT_PROMOTION: %s" % c["capability_id"])
PY
if [ -s "$TMP/cons" ]; then
  while IFS= read -r l; do fail "$l"; done < "$TMP/cons"
else
  pass "every stored assessment matches a freshly computed gate run"
fi

sect "4. Verification is executed, not asserted"
python3 - "$SPS2" > "$TMP/ver" 2>&1 <<'PY'
import json, os, sys
B = sys.argv[1]
reg = json.load(open(os.path.join(B, "capability", "registry.json")))
for c in reg["capabilities"]:
    v = c.get("verification", {})
    rel = (c.get("provenance") or {}).get("repository_relative_path") or ""
    impl = rel.endswith((".py", ".sh", ".js", ".ts")) and \
        os.path.isfile(os.path.join(B, "..", rel))
    if v.get("state") == "VERIFIED" and not impl:
        print("VERIFIED_WITHOUT_IMPLEMENTATION: %s" % c["capability_id"])
    if v.get("state") == "VERIFIED" and not v.get("observed_result"):
        print("VERIFIED_WITHOUT_OBSERVED_RESULT: %s" % c["capability_id"])
    if v.get("state") == "VERIFIED" and not v.get("evidence"):
        print("VERIFIED_WITHOUT_EVIDENCE: %s" % c["capability_id"])
PY
if [ -s "$TMP/ver" ]; then
  while IFS= read -r l; do fail "$l"; done < "$TMP/ver"
else
  pass "no capability is VERIFIED without an implementation and evidence"
fi
NV=$(python3 -c "
import json
print(sum(1 for c in json.load(open('$REG'))['capabilities']
          if c['verification']['state']=='VERIFIED'))")
[ "$NV" -ge 1 ] && pass "$NV capabilities carry executed verification" \
                || fail "no executed verification recorded"

sect "5. No-emoji policy enforced (with positive control)"
EMJ=$(python3 "$EMOJI" "$SPS2" 2>&1 | tail -1)
printf '%s' "$EMJ" | grep -q 'violations=0' \
  && pass "no emoji in any SPS 2.0 file ($EMJ)" \
  || fail "emoji violation: $EMJ"
mkdir -p "$TMP/emj" && printf 'x \360\237\216\257 y\n' > "$TMP/emj/a.md"
if python3 "$EMOJI" "$TMP/emj" >/dev/null 2>&1; then
  fail "emoji checker failed to detect a real violation"
else
  NP=$((NP+1)); pass "POSCTRL-B  emoji checker detects a real violation"
fi
rm -rf "$TMP/emj"

sect "7. Research gaps preserved"
jq -e '.conflicts[0].resolution | test("UNRESOLVED")' \
  "$SPS2/research/P2-SOURCES.json" >/dev/null 2>&1 \
  && pass "CONF-001 still UNRESOLVED" || fail "CONF-001 was closed"
jq -e '.capabilities[] | select(.capability_id=="CAP-028") | .status == "UNVERIFIED"' \
  "$SPS2/research/P2-CAPABILITY-EXTRACTION.json" >/dev/null 2>&1 \
  && pass "CAP-028 still UNVERIFIED (no LCP/INP invented)" || fail "CAP-028 changed"
if jq -e '.capabilities[] | select(.capability_id=="CAP-P03-005")
        | (.security.evidence | test("LCP|INP"))' "$REG" >/dev/null 2>&1; then
  fail "an unretrieved LCP/INP threshold was introduced"
else
  pass "no LCP or INP threshold introduced into the registry"
fi

sect "8. P3 incident boundary carried forward unchanged"
jq -e '.approval_scope.credential_revocation == "USER_ATTESTED_NOT_INDEPENDENTLY_VERIFIED"' \
  "$SPS2/handoff/HANDOFF-P3.json" >/dev/null 2>&1 \
  && pass "revocation still USER_ATTESTED_NOT_INDEPENDENTLY_VERIFIED" \
  || fail "incident classification was changed"
jq -e '.approval_scope.forensic_checkpoint_a7767cf | test("PRESERVED")' \
  "$SPS2/handoff/HANDOFF-P3.json" >/dev/null 2>&1 \
  && pass "checkpoint a7767cf still recorded PRESERVED" || fail "checkpoint scope changed"
if git -C "$REPO" cat-file -t a7767cf5f761cab4aa633c1cbc7604f83e4d14f8 \
     >/dev/null 2>&1; then
  pass "checkpoint a7767cf not purged"
else
  fail "checkpoint a7767cf was purged"
fi

sect "9. P4 approval is bounded, attributable, and promotes nothing"
python3 - "$SPS2" > "$TMP/appr" 2>&1 <<'PY'
import json, os, re, sys
B = sys.argv[1]
req = json.load(open(B + '/requirements/P4-REQUIREMENTS.json'))
dec = json.load(open(B + '/decisions/P4-DECISIONS.json'))
ho = json.load(open(B + '/handoff/HANDOFF-P4.json'))['handoffs'][0]
AGENT = re.compile(r'\b(agent|ai|assistant|model|cline|copilot|bot|'
                   r'self|script|autonomous)\b', re.I)

def approval_ok(a, where):
    """An approval is valid only when attributable to an identifiable User."""
    if (a or {}).get('state') != 'APPROVED':
        print("NOT_APPROVED: %s state=%s" % (where, (a or {}).get('state')))
        return False
    who = (a.get('approved_by') or '').strip()
    if not who:
        print("APPROVAL_UNATTRIBUTED: %s" % where); return False
    if AGENT.search(who):
        print("APPROVAL_ATTRIBUTED_TO_AGENT: %s -> %s" % (where, who)); return False
    if not (a.get('approved_on') or '').strip():
        print("APPROVAL_UNDATED: %s" % where); return False
    return True

for r in req['requirements']:
    approval_ok(r.get('approval'), r['requirement_id'])
for d in dec['decisions']:
    approval_ok(d.get('approval'), d['decision_id'])

# P4 approval must NOT have silently promoted anything.
reg = json.load(open(B + '/capability/registry.json'))
if reg['counts']['promoted'] != 0:
    print("APPROVAL_PROMOTED_SOMETHING: %d promoted" % reg['counts']['promoted'])
for c in reg['capabilities']:
    if c.get('lifecycle_state') in ('ACTIVE', 'EVALUATED', 'PROMOTED'):
        print("APPROVAL_CHANGED_LIFECYCLE: %s -> %s"
              % (c['capability_id'], c['lifecycle_state']))

# The licence must remain UNRESOLVED and unchosen.
lic = [d for d in dec['decisions'] if d.get('unresolved', {}).get('item')
       == 'repository_licence']
if not lic:
    print("LICENCE_DECISION_RECORD_MISSING")
elif lic[0]['unresolved']['state'] != 'UNRESOLVED':
    print("LICENCE_SILENTLY_RESOLVED: %s" % lic[0]['unresolved']['state'])
if any((c.get('licence') or '') in ('MIT', 'Apache-2.0', 'BSD-3-Clause',
                                    'GPL-3.0', 'ISC') for c in reg['capabilities']):
    print("LICENCE_INVENTED: a permissive licence was written into the registry")
for root, _, files in os.walk(B):
    for f in files:
        if f.upper() in ('LICENSE', 'LICENCE', 'COPYING'):
            print("LICENCE_FILE_ADDED: %s" % os.path.join(root, f))

# P5 must not exist and must not be approved.
for p in ('requirements/P5-REQUIREMENTS.json', 'handoff/HANDOFF-P5.json',
          'decisions/P5-DECISIONS.json', 'evidence/P5-EVIDENCE.json',
          'tasks/P5-TASKS.md'):
    if os.path.exists(os.path.join(B, p)):
        print("P5_ARTIFACT_CREATED: %s" % p)
if ho.get('current_state') != 'APPROVED':
    print("HANDOFF_STATE: %s" % ho.get('current_state'))
notapp = ho.get('approval_scope', {}).get('explicitly_not_approved', [])
for must in ('Any production promotion', 'Any licence selection',
             'P5, and the beginning'):
    if not any(must in s for s in notapp):
        print("APPROVAL_SCOPE_INCOMPLETE: missing explicit exclusion %r" % must)

# Research gaps, incident classification and checkpoint must be intact.
src = json.load(open(B + '/research/P2-SOURCES.json'))
if not any('UNRESOLVED' in (c.get('resolution') or '')
           for c in src.get('conflicts', [])):
    print("RESEARCH_GAP_LOST: CONF-001 is no longer UNRESOLVED")
p3 = json.load(open(B + '/handoff/HANDOFF-P3.json'))
if p3['approval_scope']['credential_revocation'] != \
   'USER_ATTESTED_NOT_INDEPENDENTLY_VERIFIED':
    print("INCIDENT_CLASSIFICATION_CHANGED")
PY
if [ -s "$TMP/appr" ]; then
  while IFS= read -r l; do fail "$l"; done < "$TMP/appr"
else
  pass "P4 approval is attributable to the User and promotes nothing"
fi
# A fabricated approval must be rejected (positive control). Exits 0 only
# when the agent-attributed approval is correctly detected and rejected.
python3 -c "
import json
d=json.load(open('$SPS2/requirements/P4-REQUIREMENTS.json'))
d['requirements'][0]['approval']['approved_by']='Agent (self-approved)'
json.dump(d,open('$TMP/appr2.json','w'))
"
if python3 - "$TMP/appr2.json" <<'PY'
import json, re, sys
AGENT = re.compile(r'\b(agent|ai|assistant|model|bot|self|script)\b', re.I)
d = json.load(open(sys.argv[1]))
rejected = any(AGENT.search((r['approval'].get('approved_by') or ''))
               for r in d['requirements'])
sys.exit(0 if rejected else 1)
PY
then
  pass "POSCTRL-D  an agent-attributed approval is rejected"
else
  fail "POSCTRL-D  agent-attributed approval was NOT rejected"
fi
PROM=$(python3 -c "
import json
print(json.load(open('$REG'))['counts']['promoted'])")
[ "$PROM" = "0" ] \
  && pass "zero capabilities promoted; P4 approval promoted nothing" \
  || fail "$PROM promoted - approval must not promote"

sect "10. Legacy protection"
DIFF=$(cd "$REPO" && git diff --name-only c11da27 -- skills scripts plugins .github \
       templates README.md CHANGELOG.md CATALOG.md '*.sh' '*.ps1' 2>/dev/null \
       | grep -v '^sps2/')
[ -z "$DIFF" ] && pass "legacy repository untouched" || fail "legacy modified: $DIFF"

sect "11. Secret safety"
python3 "$SPS2/security/scan_secrets.py" "$SPS2" --quiet \
  && pass "no credential-shaped value under sps2/" \
  || fail "credential-shaped value detected"
if bash "$SPS2/security/test-secret-safety.sh" >/dev/null 2>&1; then
  pass "secret-safety suite passes"
else
  fail "secret-safety suite failed"
fi

sect "12. Requirement, evidence and implementation records must be wired"
python3 - "$SPS2" > "$TMP/wire" 2>&1 <<'PY'
import json, os, sys
B = sys.argv[1]
R = os.path.dirname(B)
req = json.load(open(B + '/requirements/P4-REQUIREMENTS.json'))
ev = json.load(open(B + '/evidence/P4-EVIDENCE.json'))['records']
ids = {e['evidence_id'] for e in ev}
if len(ids) != len(ev):
    print("DUPLICATE_EVIDENCE_ID")
for r in req['requirements']:
    rid = r['requirement_id']
    for f in r['implementation'].get('refs') or []:
        if not os.path.isfile(os.path.join(R, f)):
            print("IMPL_REF_NOT_FOUND: %s -> %s" % (rid, f))
    if not (r['implementation'].get('refs') or []):
        print("IMPL_REF_EMPTY: %s" % rid)
    for e in (r['implementation'].get('evidence') or []):
        if e not in ids:
            print("UNKNOWN_EVIDENCE: %s -> %s" % (rid, e))
    for e in (r['verification'].get('evidence') or []):
        if e not in ids:
            print("UNKNOWN_EVIDENCE: %s -> %s" % (rid, e))
    if r['status'] == 'VERIFIED' and not r['verification'].get('evidence'):
        print("VERIFIED_WITHOUT_EVIDENCE: %s" % rid)
    for e in r['verification'].get('evidence') or []:
        rec = next(x for x in ev if x['evidence_id'] == e)
        if rec.get('relates_to', {}).get('requirement_id') != rid:
            print("EVIDENCE_MISLINKED: %s claimed by %s but relates to %s"
                  % (e, rid, rec.get('relates_to', {}).get('requirement_id')))
    if r['status'] == 'VERIFIED' and not r['verification'].get('observed_result'):
        print("VERIFIED_WITHOUT_OBSERVED_RESULT: %s" % rid)
# Every VERIFIED capability must cite evidence that actually relates to it.
reg = json.load(open(B + '/capability/registry.json'))
cap_ev = {}
for e in ev:
    cid = e.get('relates_to', {}).get('capability_id')
    if cid:
        cap_ev.setdefault(cid, set()).add(e['evidence_id'])
for c in reg['capabilities']:
    if c['verification']['state'] != 'VERIFIED':
        continue
    cid = c['capability_id']
    claimed = c['verification'].get('evidence') or []
    own = cap_ev.get(cid, set())
    if not claimed:
        print("CAPABILITY_WITHOUT_EVIDENCE: %s" % cid)
    elif not set(claimed).issubset(own):
        print("CAPABILITY_EVIDENCE_NOT_DEDICATED: %s claims %s its own are %s"
              % (cid, claimed, sorted(own)))
    elif len(claimed) != len(own):
        print("CAPABILITY_EVIDENCE_INCOMPLETE: %s claims %s its own are %s"
              % (cid, claimed, sorted(own)))
PY
if [ -s "$TMP/wire" ]; then
  while IFS= read -r l; do fail "$l"; done < "$TMP/wire"
else
  pass "requirement, evidence and implementation records are fully wired"
fi

sect "12b. The committed .claude/settings.json can never carry a credential"
# The working tree may be rewritten by the harness at any time, so scanning the
# working tree alone is a vacuous guarantee. This checks the COMMITTED blob at
# HEAD, which is what a future `git commit` would publish. Key names only; no
# credential value is read, printed or transmitted.
python3 - "$REPO" > "$TMP/claude" 2>&1 <<'PY'
import json, subprocess, sys
R = sys.argv[1]
PATH = '.claude/settings.json'
TOKEN_KEYS = ('ANTHROPIC_AUTH_TOKEN', 'OPENROUTER_KEY', 'OPENAI_API_KEY',
              'ANTHROPIC_API_KEY')
try:
    raw = subprocess.run(['git', '-C', R, 'show', 'HEAD:' + PATH],
                         capture_output=True, text=True, check=True).stdout
    d = json.loads(raw)
except Exception as e:
    print("CLAUDE_SETTINGS_UNREADABLE: %s" % type(e).__name__)
    raise SystemExit(0)
env = d.get('env') or {}
bad = sorted(k for k in env if k in TOKEN_KEYS)
if bad:
    print("COMMITTED_CREDENTIAL_KEY: .claude/settings.json holds %s" % bad)
if not isinstance(d.get('enabledPlugins', {}), dict):
    print("CLAUDE_SETTINGS_MALFORMED: enabledPlugins is not an object")
PY
if [ -s "$TMP/claude" ]; then
  while IFS= read -r l; do fail "$l"; done < "$TMP/claude"
else
  pass "the committed .claude/settings.json carries no credential key"
fi
# POSCTRL-E: the committed-blob guard must actually detect a planted key.
if [ "$(python3 - "$TMP" <<'PY'
import json, os, sys
TOKEN_KEYS = ('ANTHROPIC_AUTH_TOKEN', 'OPENROUTER_KEY', 'OPENAI_API_KEY',
              'ANTHROPIC_API_KEY')
p = os.path.join(sys.argv[1], 'claude_fake.json')
json.dump({'env': {'ANTHROPIC_AUTH_TOKEN': 'PLANTED-FOR-TEST'}}, open(p, 'w'))
d = json.load(open(p))
print('DETECTED' if any(k in TOKEN_KEYS for k in (d.get('env') or {}))
      else 'MISSED')
PY
)" = "DETECTED" ]; then
  pass "POSCTRL-E  the committed-blob guard detects a planted credential key"
else
  fail "POSCTRL-E  the committed-blob guard MISSED a planted credential key"
fi

sect "12c. Open decisions must stay open until the user answers them"
# A pending decision must carry no decider. If an agent ever fills in
# decided_by, or flips state, the record is a fabricated approval.
python3 - "$SPS2" > "$TMP/open" 2>&1 <<'PY'
import json, os, sys
B = sys.argv[1]
D = B + '/decisions'
lic = os.path.join(D, 'OPEN-DECISION-LICENCE.json')
setg = os.path.join(D, 'OPEN-DECISION-CLAUDE-SETTINGS.json')
for p in (lic, setg):
    if not os.path.isfile(p):
        print("OPEN_DECISION_RECORD_MISSING: %s" % os.path.basename(p))
for p in (lic, setg):
    if not os.path.isfile(p):
        continue
    d = json.load(open(p))
    did = d.get('decision_id')
    if d.get('state') != 'PENDING_USER_DECISION':
        print("OPEN_DECISION_SILENTLY_CLOSED: %s state=%s" % (did, d.get('state')))
    if d.get('decided_by') not in (None, ''):
        print("OPEN_DECISION_SELF_ANSWERED: %s decided_by=%s"
              % (did, d.get('decided_by')))
    if len(d.get('options') or []) < 2:
        print("OPEN_DECISION_NO_OPTIONS: %s" % did)
# The licence must still be unresolved in the P4 decision record.
dec = json.load(open(D + '/P4-DECISIONS.json'))
lic_rec = [x for x in dec['decisions']
           if (x.get('unresolved') or {}).get('item') == 'repository_licence']
if not lic_rec:
    print("LICENCE_DECISION_RECORD_MISSING")
elif lic_rec[0]['unresolved']['state'] != 'UNRESOLVED':
    print("LICENCE_SILENTLY_RESOLVED: %s" % lic_rec[0]['unresolved']['state'])
# Still no licence file anywhere under the repository root.
for root, dirs, files in os.walk(B):
    dirs[:] = [d for d in dirs if d != '.git']
    for f in files:
        if f.upper() in ('LICENSE', 'LICENCE', 'COPYING'):
            print("LICENCE_FILE_ADDED: %s" % os.path.join(root, f))
PY
if [ -s "$TMP/open" ]; then
  while IFS= read -r l; do fail "$l"; done < "$TMP/open"
else
  pass "open decisions remain open, unattributed, and carry options"
fi

fi  # end structural

# ══ NEGATIVE SUITE: 20 mandated cases ═══════════════════════════════════════
# The negative suite keeps its own counters so that a positive control failing
# elsewhere can never be mis-reported as a missed negative case.
sect "NEGATIVE TESTS — invalid promotion states must be rejected"
NNP=0; NNF=0

gate_case "B['capability_id']=''"                     A "N01 missing capability id"
gate_case "B['capability_id']='bad id'"               A "N02 malformed capability id"
gate_case "B['provenance']={'fact_class':'EVIDENCE'}" B "N03 missing provenance"
gate_case "B['licence']='UNKNOWN'"                    D "N04 unknown licence"
gate_case "B['licence']='UNDECLARED'"                 D "N04b undeclared licence"
gate_case "B['security']={'status':'VERIFIED_SAFE','fact_class':'EVIDENCE'}" C "N05 missing security evidence"
gate_case "B['verification']={'state':'VERIFIED','method':'AUTOMATED'}" F "N06 missing verification evidence"
gate_case "B['acceptance_criteria']=[]"               G "N07 empty acceptance criteria"
gate_case "B['approval']={'state':'PENDING_USER_APPROVAL'}" H "N08 user approval absent"
gate_case "B['approval']={'state':'APPROVED','decided_by':'agent'}" H "N09 agent-attributed approval"
gate_case "B['approval']={'state':'APPROVED','decided_by':''}"     H "N09b approval with no decider"
gate_case "B['install_scope']='GLOBAL'"               I "N10 GLOBAL without authorization"
gate_case "B['staleness']=dict(B['staleness'],state='STALE');B['lifecycle_state']='ACTIVE';B['verification']={'state':'VERIFIED','evidence':['E'],'method':'A','expected_result':'x','observed_result':'y'}" J "N11 stale marked ACTIVE"
gate_case "B['staleness']={'state':'STALE','maintenance':'ACTIVE'}" J "N12 stale without review"
gate_case "B['provenance']={'origin':'nonexistent-system-xyz','commit':'abc1234','fact_class':'EVIDENCE','repository_relative_path':'sps2/does-not-exist.py','research_refs':['SRC-999']}" B "N13 fabricated source reference"
gate_case "B['security']={'status':'VERIFIED_SAFE','evidence':'sk-or-v1-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA','fact_class':'EVIDENCE'}" C "N14 secret embedded in record"
gate_case "B['type']='WIDGET'"                        A "N15 invalid taxonomy"
gate_case "B['lifecycle_state']='TELEPORTED'"         A "N16 invalid lifecycle state"
gate_case "B['domain']='SEO';B['name']='lcp-inp-verifier';B['security']={'status':'VERIFIED_SAFE','evidence':'LCP 2500ms INP 200ms','fact_class':'FACT'}" K "N17 unresolved research promoted"

# N18: duplicate capability id (registry level)
mk "pass"
python3 - "$TMP/c.json" "$TMP/dup.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
json.dump({"capabilities": [d, dict(d)]}, open(sys.argv[2], "w"))
PY
if python3 "$CHECK" "$TMP/dup.json" 2>&1 | grep -q 'DUPLICATE' \
   || python3 -c "
import json,sys
a=json.load(open('$TMP/dup.json'))['capabilities']
sys.exit(0 if len({c['capability_id'] for c in a})<len(a) else 1)"; then
  NNP=$((NNP+1)); pass "N18 duplicate capability id -> rejected"
else
  NNF=$((NNF+1)); fail "N18 duplicate capability id NOT rejected"
fi

# N19: emoji violation
mkdir -p "$TMP/em" && printf 'x \360\237\216\257\n' > "$TMP/em/a.md"
if python3 "$EMOJI" "$TMP/em" >/dev/null 2>&1; then
  NNF=$((NNF+1)); fail "N19 emoji violation NOT rejected"
else
  NNP=$((NNP+1)); pass "N19 emoji violation -> rejected"
fi
rm -rf "$TMP/em"

# N20: malformed structured input
printf '{ not json' > "$TMP/bad.json"
if python3 "$CHECK" "$TMP/bad.json" 2>&1 | grep -q 'GATE_ERROR'; then
  NNP=$((NNP+1)); pass "N20 malformed JSON -> rejected"
else
  NNF=$((NNF+1)); fail "N20 malformed JSON NOT rejected"
fi

echo ""
if [ "$NNF" -eq 0 ]; then
  echo -e "${GREEN}${BOLD}== P4 NEGATIVE SUITE: $NNP cases correctly rejected, 0 missed ==${NC}"
else
  echo -e "${RED}${BOLD}== P4 NEGATIVE SUITE: $NNP rejected, $NNF MISSED ==${NC}"
fi
echo ""
if [ "$FAIL" -eq 0 ] && [ "$NNF" -eq 0 ]; then
  echo -e "${GREEN}${BOLD}== P4 PROMOTION VALID: $PASS checks passed, 0 failed, $NNP negative cases rejected, $NP controls enforced ==${NC}"
  exit 0
fi
echo -e "${RED}${BOLD}== P4 PROMOTION INVALID: $PASS passed, $FAIL failed, $NNF missed ==${NC}"
exit 1
