# SPS Governance — Canonical Project State

> **This repository is the source of truth for SPS project state.**
> Agents are *clients* of this repository. Project-critical state must never live
> only in an agent's hidden memory, global memory, or machine-local planning dir.
>
> Read order for any agent picking up this project: **`STATE.md` → `tasks/` →
> `evidence/` → `decisions/`**. Do not rely on hidden memory.

**Tool-agnostic:** this format uses plain Markdown + JSON. It does not depend on
Cline, Claude, Codex, Antigravity, Gemini, OpenCode, any model, or any IDE.

---

## Current Phase

| Field | Value |
|---|---|
| Phase ID | `PHASE-02` |
| Phase name | Governance, Git & Evidence Foundation |
| Phase status | `VERIFIED` |
| Completion | `COMPLETE` |
| Verification | `VERIFIED` |
| **Approval** | **`PENDING_USER_APPROVAL`** — not granted |
| Started | 2026-10-03 |
| Previous phase | `PHASE-01` — Baseline Forensic Audit (`VERIFIED`, read-only) |
| Next phase | `PHASE-03` — **NOT STARTED, NOT APPROVED** |

> **Note on the three axes:** this phase is `COMPLETE` and `VERIFIED`, but approval is
> still `PENDING_USER_APPROVAL`. Only the user can change that field. An agent must
> never set it to `APPROVED` on the user's behalf.

## Current Position

```
PHASE-01 (audit)  ──►  PHASE-02 (governance)  ──►  PHASE-03 (remediation)
   VERIFIED              VERIFIED                  NOT_STARTED
                                                       ▲
                                          requires explicit user approval
```

## Phase Status Legend

`PLANNED` → `IN_PROGRESS` → `AWAITING_USER_APPROVAL` → `APPROVED` → `VERIFIED`

Terminal alternatives: `REJECTED` · `BLOCKED` · `FAILED`

**Critical distinction — these three are NOT the same:**

| Concept | Meaning | Recorded in |
|---|---|---|
| **Completed** | An agent believes the work was performed | `tasks/*.md` → `completion` |
| **Verified** | Objective evidence proves it works | `evidence/*.json` → `verification` |
| **Approved** | The *user* explicitly accepted it | `approval` block |

A phase may be `Completed` but not `Verified`, and `Verified` but not `Approved`.
Never collapse these into a single field.

## Phase Inventory

| Phase | Scope | Status | Report |
|---|---|---|---|
| `PHASE-01` | Read-only forensic audit | `VERIFIED` | `AUDIT-PHASE-01-BASELINE-FORENSIC.md` |
| `PHASE-02` | Governance + Git + evidence foundation | `VERIFIED` | `AUDIT-PHASE-02-GOVERNANCE-IMPLEMENTATION.md` |
| `PHASE-03` | Functional remediation (scope TBD, awaiting approval) | `NOT_STARTED` | — |

## Governance Map

```
.sps/
├── STATE.md                    ◀── you are here: canonical entry point
├── GOVERNANCE.md               ◀── rules: states, maturity, IDs, evidence, approval
├── SCHEMA.md                   ◀── machine-readable contracts for every record
├── tasks/
│   └── PHASE-02-TASKS.md       ◀── task register for the active phase
├── evidence/
│   └── PHASE-02-EVIDENCE.json  ◀── objective verification records
├── decisions/
│   └── DEC-0001-*.md           ◀── decision records (why, not just what)
├── handoff/
│   └── HANDOFF-CURRENT.md      ◀── agent-to-agent contract
└── audits/
    └── README.md               ◀── index of audit reports + known-issue register
```

Existing SPS files (`profile.md`, `handoff.md`, `agent.md`, `audit-report.md`,
`mistakes.md`, `learned/`) are retained unchanged — governance **extends** the
existing convention rather than replacing it.

## Provenance

| Field | Value |
|---|---|
| Baseline commit | `10ab67a` — `chore(governance): establish pre-remediation baseline` |
| Governance commit | see `evidence/PHASE-02-EVIDENCE.json` |
| Remote | `REMOTE_NOT_CONFIGURED` |
| Branch | `main` |

## Rules

1. **No hidden memory.** If it is not in this repository, another agent cannot see it.
2. **No claim without evidence.** Every status claim links to an evidence record.
3. **Never mark `APPROVED` on the user's behalf.** Only the user grants approval.
4. **Never mark `VERIFIED` without an executed command and its real output.**
5. **Traceability is mandatory:** phase → task → requirement → implementation →
   evidence → approval.
6. **Out-of-scope means documented, not fixed.**