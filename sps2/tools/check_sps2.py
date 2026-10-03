#!/usr/bin/env python3
"""SPS 2.0 P1 structured-state check engine.

Validates JSON records against the P1 contracts. Emits one 'ERR\t<message>'
line per violation on stdout; emits nothing when the input is clean.

Usage: check_sps2.py <kind> <json-file>
  kind: requirement | capability | evidence | decision | handoff | action

Pure module: reads one file, writes nothing.
"""
import json
import re
import sys

AGENT = re.compile(
    r'\b(agent|ai|assistant|model|bot|claude|cursor|codex|gemini|opencode|'
    r'cline|copilot|antigravity)\b', re.I)

RESULTS = {"PASS", "FAIL", "SKIP", "BLOCKED"}
SEC = {"VERIFIED_SAFE", "REVIEWED_LOW_RISK", "SUSPECTED_RISK",
       "VULNERABLE", "UNKNOWN"}


def _dup(ids):
    return sorted({i for i in ids if ids.count(i) > 1})


def _approval(e, tag, ap):
    """Approval may only ever be attributed to a user."""
    if ap.get("state") != "APPROVED":
        return
    who = (ap.get("decided_by") or "").strip()
    if not who:
        e.append("%s: APPROVED without decided_by" % tag)
    elif AGENT.search(who):
        e.append("%s: APPROVED attributed to non-user %r" % (tag, who))


def requirement(d):
    e = []
    for r in d.get("requirements", []):
        rid = r.get("requirement_id", "<no id>")
        if not re.fullmatch(r"REQ-[A-Z0-9]+-\d{2,}", str(rid)):
            e.append("%s: bad requirement_id" % rid)
            continue
        if not (r.get("acceptance_criteria") or []):
            e.append("%s: acceptance_criteria empty (MISSING_REQUIREMENT)" % rid)
            continue
        if not r.get("objective"):
            e.append("%s: missing objective" % rid)
        impl = r.get("implementation") or {}
        if impl.get("verified") and not impl.get("evidence"):
            e.append("%s: implementation.verified without evidence "
                     "(UNVERIFIED_IMPLEMENTATION)" % rid)
        if impl.get("state") == "COMPLETE" and not impl.get("refs"):
            e.append("%s: implementation COMPLETE without refs" % rid)
        ver = r.get("verification") or {}
        if ver.get("state") == "VERIFIED" and not ver.get("evidence"):
            e.append("%s: VERIFIED without evidence" % rid)
        if ver.get("state") == "VERIFIED" and ver.get("method") == "AGENT" \
           and (r.get("risk") or "") in ("HIGH", "CRITICAL"):
            e.append("%s: AGENT verification alone is insufficient for %s risk"
                     % (rid, r.get("risk")))
        _approval(e, rid, r.get("approval") or {})
    dup = _dup([r.get("requirement_id") for r in d.get("requirements", [])])
    if dup:
        e.append("duplicate requirement IDs: %s" % dup)
    return e


def capability(d):
    e = []
    for c in d.get("capabilities", []):
        cid = c.get("capability_id", "<no id>")
        if not re.fullmatch(r"CAP-[A-Z0-9]+-\d{3,}", str(cid)):
            e.append("%s: bad capability_id" % cid)
            continue
        sc = (c.get("security") or {}).get("status")
        if sc not in SEC:
            e.append("%s: invalid security status %r" % (cid, sc))
            continue
        if sc in {"SUSPECTED_RISK", "VULNERABLE", "UNKNOWN"} \
           and c.get("install_scope") == "GLOBAL":
            e.append("%s: security %s blocks GLOBAL install" % (cid, sc))
            continue
        if c.get("install_scope") == "GLOBAL":
            who = (c.get("global_installation_authorized_by") or "").strip()
            if not who:
                e.append("%s: GLOBAL scope without user authorization" % cid)
            elif AGENT.search(who):
                e.append("%s: GLOBAL authorized by non-user %r" % (cid, who))
        comp = c.get("compatibility") or {}
        if comp.get("agent_neutral") and comp.get("agent_specific_dependency"):
            e.append("%s: claims agent_neutral with dependency %r"
                     % (cid, comp.get("agent_specific_dependency")))
        st = c.get("staleness") or {}
        if st.get("state") == "STALE" and st.get("review_due") is None:
            e.append("%s: STALE without review_due" % cid)
        if c.get("lifecycle_state") in ("VERIFIED", "ACTIVE") \
           and not ((c.get("verification") or {}).get("evidence") or []):
            e.append("%s: lifecycle %s without evidence"
                     % (cid, c.get("lifecycle_state")))
        _approval(e, cid, c.get("approval") or {})
    dup = _dup([c.get("capability_id") for c in d.get("capabilities", [])])
    if dup:
        e.append("duplicate capability IDs: %s" % dup)
    return e


def evidence(d):
    e = []
    for r in d.get("records", []):
        rid = r.get("evidence_id", "<no id>")
        if not re.fullmatch(r"EV-[A-Z0-9]+-\d{3,}", str(rid)):
            e.append("%s: bad evidence_id" % rid)
            continue
        if r.get("result") not in RESULTS:
            e.append("%s: invalid result %r" % (rid, r.get("result")))
            continue
        if r.get("result") == "PASS" \
           and not (r.get("observed_result") or "").strip():
            e.append("%s: PASS with empty observed_result" % rid)
        if r.get("result") in ("SKIP", "BLOCKED") \
           and len(r.get("observed_result") or "") < 20:
            e.append("%s: SKIP/BLOCKED without a stated reason" % rid)
    dup = _dup([r.get("evidence_id") for r in d.get("records", [])])
    if dup:
        e.append("duplicate evidence IDs (append-only violation): %s" % dup)
    return e


def decision(d):
    e = []
    for x in d.get("decisions", []):
        did = x.get("decision_id", "<no id>")
        if not re.fullmatch(r"DEC-\d{4}", str(did)):
            e.append("%s: bad decision_id" % did)
            continue
        if not x.get("reason") or not x.get("evidence"):
            e.append("%s: decision missing reason or evidence" % did)
        _approval(e, did, x.get("approval") or {})
    dup = _dup([x.get("decision_id") for x in d.get("decisions", [])])
    if dup:
        e.append("duplicate decision IDs: %s" % dup)
    return e


def handoff(d):
    e = []
    for h in d.get("handoffs", []):
        hid = h.get("handoff_id", "<no id>")
        if not h.get("next_allowed_action") or not h.get("forbidden_next_action"):
            e.append("%s: handoff must state next AND forbidden actions" % hid)
        for k in ("completed", "not_completed", "blockers"):
            if not isinstance(h.get(k), list):
                e.append("%s: %s must be a list" % (hid, k))
    return e


def action(d):
    e = []
    for a in d.get("actions", []):
        aid = a.get("action_id", "<no id>")
        if a.get("assumption") == "MATERIAL_DECISION" \
           and (a.get("approval") or {}).get("state") != "APPROVED":
            e.append("%s: MATERIAL_DECISION without user approval "
                     "(MISSING_USER_DECISION)" % aid)
        if a.get("install_scope") == "GLOBAL":
            who = (a.get("global_installation_authorized_by") or "").strip()
            if not who:
                e.append("%s: GLOBAL install without user authorization" % aid)
            elif AGENT.search(who):
                e.append("%s: GLOBAL authorized by non-user %r" % (aid, who))
        if a.get("risk_level") == "CRITICAL" and not a.get("rollback_method"):
            e.append("%s: CRITICAL action without rollback_method" % aid)
    return e


MAP = {"requirement": requirement, "capability": capability, "evidence": evidence,
       "decision": decision, "handoff": handoff, "action": action}


def main():
    if len(sys.argv) != 3:
        print("usage: check_sps2.py <kind> <json-file>")
        return 2
    kind, path = sys.argv[1], sys.argv[2]
    if kind not in MAP:
        print("unknown kind: %s" % kind)
        return 2
    try:
        data = json.load(open(path))
    except Exception as ex:
        print("ERR\tnot valid JSON: %s" % ex)
        return 0
    for msg in MAP[kind](data):
        print("ERR\t%s" % msg)
    return 0


if __name__ == "__main__":
    sys.exit(main())
