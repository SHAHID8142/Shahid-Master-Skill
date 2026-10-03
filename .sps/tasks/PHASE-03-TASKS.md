# PHASE-03 Task Register

**Phase:** `PHASE-03` — Enforcement & Control Foundation
**Status:** `AWAITING_USER_APPROVAL` (implementation `COMPLETE`, verification `VERIFIED`)
**Approval:** **`PENDING_USER_APPROVAL`** — explicit user approval, not inferred
**Contract:** `.sps/SCHEMA.md` §6–§10 · **Model:** `.sps/control/CONTROL-MODEL.md`

> Reminder: `completion`, `verification` and `approval` are independent axes. This phase is
> the first two only. Only the user may set the third.

---

## Task Summary

| ID | Title | Requirements | Status | Completion | Verification | Approval |
|---|---|---|---|---|---|---|
| `PHASE-03-T01` | Define control model, lifecycle, enforcement levels | `REQ-P03-01,02,04,06,07,09,10` | `VERIFIED` | `COMPLETE` | `VERIFIED` | `PENDING_USER_APPROVAL` |
| `PHASE-03-T02` | Machine-readable contracts + requirement register | `REQ-P03-03` | `VERIFIED` | `COMPLETE` | `VERIFIED` | `PENDING_USER_APPROVAL` |
| `PHASE-03-T03` | Requirement validator + negative suite (CASE A–E) | `REQ-P03-02,03,05` | `VERIFIED` | `COMPLETE` | `VERIFIED` | `PENDING_USER_APPROVAL` |
| `PHASE-03-T04` | Evidence append-only enforcement + CASE F | `REQ-P03-08` | `VERIFIED` | `COMPLETE` | `VERIFIED` | `PENDING_USER_APPROVAL` |
| `PHASE-03-T05` | Handoff extension (`NEXT_ALLOWED_ACTION`) | `REQ-P03-09` | `VERIFIED` | `COMPLETE` | `VERIFIED` | `PENDING_USER_APPROVAL` |
| `PHASE-03-T06` | Validation, scope discipline, existing-SPS audit | all | `VERIFIED` | `COMPLETE` | `VERIFIED` | `PENDING_USER_APPROVAL` |

---

## T01 — Control model, lifecycle, enforcement levels

- **Evidence:** `EV-P03-001` · **Decisions:** `DEC-0003`
- **Files:** `.sps/control/CONTROL-MODEL.md`, `.sps/control/ENFORCEMENT.md`,
  `.sps/control/ENFORCEMENT-VS-INSTRUCTION.md`
- **Done:** 11-stage lifecycle mapped to Phase 02 statuses (no duplicate state system); four
  truths with non-collapse rules; 9 action classes; 4 risk levels; 4 verifier classes;
  rollback contract; 5 enforcement levels; 10 stop conditions; phase gate; no-assumption rule;
  honest enforcement inventory.
- **Not done:** no machine gate blocks phase transitions (documented as `DECLARED` only).

## T02 — Contracts and requirement register

- **Evidence:** `EV-P03-002`
- **Files:** `.sps/SCHEMA.md` (§6–§11), `.sps/requirements/PHASE-03-REQUIREMENTS.json`
- **Done:** requirement / verification / agent-action / rollback / handoff-extension contracts.
  10 real Phase 03 requirements with observable acceptance criteria; 6 verification records.

## T03 — Requirement validator and negative suite

- **Evidence:** `EV-P03-003`, `EV-P03-004`, `EV-P03-005`
- **Done:** `validate-control.sh` evaluates the requirement contract and rejects: empty
  acceptance criteria (CASE A), non-observable criteria (CASE A2), VERIFIED without evidence
  (CASE B), CRITICAL verified without approval (CASE C), blocked-but-approved (CASE D),
  agent-attributed approval (CASE E), approval with no decider (CASE E2).

## T04 — Evidence append-only enforcement

- **Evidence:** `EV-P03-006` · **Decision:** `DEC-0004`
- **Done:** CASE F detects duplicate IDs, invalid `result` enum, and a `PASS` whose captured
  output was erased.
- **Honest limit:** detection-based, not prevention-based. Recorded in `DEC-0004`.

## T05 — Handoff extension

- **Evidence:** `EV-P03-001`
- **Done:** `SCHEMA.md` §10 adds `current_phase`, `current_state`, `blockers`,
  `next_allowed_action`, `forbidden_next_action`; `HANDOFF-CURRENT.md` records both action
  fields so the next agent cannot self-select its next move.

## T06 — Validation, scope, audit

- **Evidence:** `EV-P03-007`, `EV-P03-008`, `EV-P03-009`
- **Done:** existing SPS lint + Phase 02 validator re-run green; scope discipline asserted
  mechanically; no machine-global change; focused audit of existing SPS in
  `AUDIT-PHASE-03-ENFORCEMENT-CONTROL.md` §19.
- **Not done:** no Phase 01 finding fixed. `KI-01` (hardcoded secret) remains open by design.