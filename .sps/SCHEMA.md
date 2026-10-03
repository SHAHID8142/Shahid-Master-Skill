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

## 6. Validation

Run the project-local validator (no network, no global writes, no installs):

```bash
bash .sps/tools/validate-governance.sh
```

Exit codes: `0` all valid · `1` validation failure · `2` tooling unavailable.

The validator checks: JSON well-formedness, required fields, enum membership,
ID format, evidence-command/result coherence, and that no secret-shaped value has
been written into a governance file.