# SPS Governance — Machine-Readable Schemas

Contracts for every governance record. Plain Markdown + JSON so any tool, agent,
model, or IDE can read them without a vendor runtime. No YAML parser, no framework.

---

## 1. Task Record

```json
{
  "id": "PHASE-02-T01",
  "phase": "PHASE-02",
  "title": "Establish Git provenance",
  "requirement": "REQ-P02-01",
  "status": "VERIFIED",
  "completion": "COMPLETE",
  "verification": "VERIFIED",
  "approval": "PENDING_USER_APPROVAL",
  "implemented_by": ["<agent-id>"],
  "files_changed": ["<path>"],
  "evidence": ["EV-P02-001"],
  "decisions": ["DEC-0001"],
  "blocked_by": null,
  "notes": ""
}
```

**Field rules:**
- `status` — the state machine value (`GOVERNANCE.md` §2).
- `completion` — `NOT_STARTED` | `PARTIAL` | `COMPLETE` (agent-set).
- `verification` — `UNVERIFIED` | `VERIFIED` | `FAILED` (agent-set, needs evidence).
- `approval` — `NOT_REQUIRED` | `PENDING_USER_APPROVAL` | `APPROVED` | `REJECTED`
  (**user-set only**).

---

## 2. Evidence Record

```json
{
  "id": "EV-P02-001",
  "task": "PHASE-02-T01",
  "requirement": "REQ-P02-01",
  "command": "<exact command>",
  "expected": "<what success looks like>",
  "actual": "<verbatim captured output>",
  "result": "PASS",
  "timestamp": "2026-10-03T00:00:00Z",
  "file": "<relevant file or null>",
  "test": "<validator/test name>",
  "commit": "<sha or null>",
  "maturity": "VERIFIED"
}
```

`result` enum: `PASS` | `FAIL` | `SKIP` | `BLOCKED`

---

## 3. Decision Record

```json
{
  "id": "DEC-0001",
  "title": "Initialise Git locally without a remote",
  "decision": "<what was decided>",
  "reason": "<why>",
  "evidence": ["<evidence ids or file:line refs>"],
  "alternatives": [
    { "option": "<considered>", "rejected_because": "<why>" }
  ],
  "approval": {
    "required": true,
    "status": "PENDING_USER_APPROVAL",
    "approved_by": null,
    "approved_at": null
  },
  "supersedes": null,
  "date": "2026-10-03"
}
```

---

## 4. Handoff Record

```json
{
  "id": "HANDOFF-PHASE-02-01",
  "phase": "PHASE-02",
  "from": "<agent-id>",
  "to": "<agent-id or ANY>",
  "timestamp": "2026-10-03T00:00:00Z",
  "task_performed": "<what was being worked on>",
  "completed": ["<done>"],
  "not_completed": ["<explicitly not done>"],
  "files_changed": ["<path>"],
  "tests_executed": ["<command>"],
  "tests_passed": ["<id>"],
  "tests_failed": ["<id or none>"],
  "known_risks": ["<risk>"],
  "unresolved_questions": ["<question>"],
  "decisions_made": ["DEC-0001"],
  "next_recommended_action": "<action>",
  "user_approval_required": true,
  "git_commit": "<sha>"
}
```

All 12 fields from §9 of the brief are mandatory. `"not_completed"` and
`"unresolved_questions"` may be `[]` but must never be omitted.

---

## 5. Approval Record

```json
{
  "subject": "PHASE-02",
  "requested_by": "<agent-id>",
  "requested_at": "2026-10-03T00:00:00Z",
  "scope": "<what is being approved>",
  "evidence_summary": ["EV-P02-001"],
  "state": "PENDING_USER_APPROVAL",
  "decided_by": null,
  "decided_at": null,
  "decision_comment": null
}
```

`state` enum: `PENDING_USER_APPROVAL` | `APPROVED` | `REJECTED`

**Rule:** `decided_by` may only be set to a value identifying the **user**. An
agent must never populate it.

---

---

## 6. Requirement Contract (Phase 03)

Extends the Phase 02 record set. Traceability chain:
**Requirement → Task → Implementation → Verification → Evidence → Approval.**

```json
{
  "requirement_id": "REQ-P03-01",
  "title": "<short imperative title>",
  "description": "<what must be true, and why>",
  "source": "<origin: user | audit finding | decision | regulation>",
  "priority": "LOW | MEDIUM | HIGH | CRITICAL",
  "scope": "IN_SCOPE | OUT_OF_SCOPE",
  "acceptance_criteria": ["<observable outcome, verifiable by executing something>"],
  "dependencies": ["REQ-...", "TASK-..."],
  "implementation_status": "DECLARED | IMPLEMENTED",
  "implementation_refs": ["<file:line>"],
  "verification_status": "UNVERIFIED | VERIFIED",
  "verification_refs": ["VER-P03-001"],
  "approval_status": "NOT_REQUIRED | PENDING_USER_APPROVAL | APPROVED | REJECTED",
  "evidence": ["EV-P03-001"],
  "related_tasks": ["PHASE-03-T01"],
  "related_decisions": ["DEC-0003"]
}
```

**Field rules (enforced by `validate-control.sh`):**
- `requirement_id` must match `REQ-PNN-NN`.
- `acceptance_criteria` must be **non-empty** and each entry must be observable.
  Vague criteria (`good`, `fast`, `nice`, `robust`, `proper`) are **rejected** — `CASE A`.
- `implementation_status: IMPLEMENTED` requires ≥1 entry in `implementation_refs`.
- `verification_status: VERIFIED` requires ≥1 entry in `verification_refs`.
- `approval_status: APPROVED` requires an attributable user decision — never agent-set.

### Acceptance criteria quality (§7)

| BAD | GOOD |
|---|---|
| "Build a good homepage" | "Route renders HTTP 200; responsive at 320/768/1440; passes the defined a11y check" |
| "Improve performance" | "Lighthouse performance score >= 90 on the target route" |
| "Add tests" | "New branch covered by >=1 test that fails without the change" |

Rule: a criterion is acceptable if it names **what is observed**, **where**, and **how it is
checked**. Phase 03 does not invent project-specific criteria — it makes them mandatory.

---

## 7. Verification Contract (Phase 03)

```json
{
  "verification_id": "VER-P03-001",
  "requirement_id": "REQ-P03-01",
  "task_id": "PHASE-03-T01",
  "method": "AUTOMATED | AGENT | USER | EXTERNAL",
  "command_or_procedure": "<exact command or the manual procedure>",
  "expected_result": "<what success looks like>",
  "actual_result": "<verbatim observed output>",
  "status": "PASS | FAIL | SKIP | BLOCKED",
  "evidence_reference": "EV-P03-001",
  "verifier": "<agent or human identifier>",
  "timestamp": "2026-10-03T00:00:00Z"
}
```

**Field rules:**
- `method` ∈ the four verifier classes (`CONTROL-MODEL.md` §6).
- `method: AGENT` may **not** be the sole verification for `HIGH`/`CRITICAL` risk, nor for
  enforcement Level 3/4.
- `status: PASS` requires non-empty `actual_result` (never "should pass").
- `status: FAIL`/`BLOCKED` requires a stated reason.
- Verification is **append-only**; a changed outcome requires a new record with `supersedes`.

---

## 8. Agent Action Contract (Phase 03)

Representation for a *significant* action before it is performed. Not an agent runtime.

```json
{
  "action_id": "ACT-P03-001",
  "actor": "<agent or human identifier>",
  "phase": "PHASE-03",
  "task": "PHASE-03-T01",
  "intent": "<why this action is being taken>",
  "inputs": ["<file, parameter, or state consumed>"],
  "expected_output": "<observable result>",
  "action_class": "READ | ANALYZE | WRITE | EXECUTE | INSTALL | DELETE | DEPLOY | PUBLISH | DESTRUCTIVE",
  "risk_level": "LOW | MEDIUM | HIGH | CRITICAL",
  "assumption_classification": "SAFE_INFERENCE | MATERIAL_DECISION",
  "required_approval": "NONE | USER | BLOCKING",
  "validation_method": "<how the result will be checked>",
  "rollback_method": "<how to undo, or null>",
  "rollback_available": "yes | no | partial",
  "rollback_scope": "<what it restores>",
  "rollback_verified": true
}
```

**Field rules:**
- `action_class` ∈ the nine classes; `DESTRUCTIVE` is an overlay that wins.
- `risk_level` ∈ `LOW|MEDIUM|HIGH|CRITICAL`.
- `assumption_classification: MATERIAL_DECISION` **requires** `required_approval: USER` —
  otherwise `MISSING_USER_DECISION` (stop condition). Encodes the no-assumption rule.
---

## 9. Rollback Contract (Phase 03)

Referenced by the action contract; recorded per high-risk task.

```json
{
  "action_id": "ACT-P03-001",
  "rollback_available": "yes | no | partial",
  "rollback_method": "<concrete procedure>",
  "rollback_scope": "FILE | COMMIT | DATABASE | CONFIG | ENVIRONMENT | DATA",
  "rollback_verified": true,
  "verified_by": "<verifier id>",
  "verified_at": "2026-10-03T00:00:00Z"
}
```

Rule: `rollback_verified: false` on a `CRITICAL` action is a stop condition.

---

## 10. Handoff Extension (Phase 03)

`SCHEMA.md` §4 (Phase 02) is extended with these fields. Existing fields are unchanged.

```json
{
  "current_phase": "PHASE-03",
  "current_task": "PHASE-03-T01",
  "current_state": "<lifecycle stage>",
  "blockers": ["<stop-condition codes>"],
  "requirements": ["REQ-P03-01"],
  "implementation": ["<file:line refs>"],
  "verification": ["VER-P03-001"],
  "evidence": ["EV-P03-001"],
  "user_approval": "PENDING_USER_APPROVAL",
  "next_allowed_action": "<action class + description that IS permitted>",
  "forbidden_next_action": "<action class + description that is NOT permitted>"
}
```

**The two critical fields** (Phase 03 brief §20):

- `next_allowed_action` — what a receiving agent **may** do next.
- `forbidden_next_action` — what it **must not** do, even if it believes that would help.

These exist to stop a receiving agent from simply deciding what it wants to do next.

---

## 11. Validation (updated)

```bash
bash .sps/tools/validate-governance.sh          # Phase 02 governance rules
bash .sps/tools/validate-control.sh             # Phase 03 control rules + CASE A-F
bash .sps/tools/validate-control.sh --negative  # run the negative test suite only
```

Exit codes: `0` all valid · `1` validation failure · `2` tooling unavailable.
- `risk_level: CRITICAL` requires `rollback_available != "no"` and `rollback_verified: true`.