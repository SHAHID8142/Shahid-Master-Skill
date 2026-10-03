# SPS 2.0

**Version:** `0.1.0-foundation` · **Status:** P1 foundation — `AWAITING_USER_APPROVAL`
**Lineage:** designed by Phase 05 (approved by User, 2026-10-03); foundation built in P1.

SPS 2.0 is an **orchestration and control framework** for AI-assisted software
development — not a single skill and not a single prompt.

> **This is not the legacy SPS.** The legacy implementation lives at the repository root
> (`skills/`, `scripts/`, `plugins/`, installers) and is **reference-only**. Nothing in
> `sps2/` may modify or depend on it. See `legacy/MANIFEST.md`.

---

## Architecture

```
sps2/
├── core/            agent-neutral orchestration: lifecycle, protocols, gates, adapters
├── governance/      contracts (JSON Schemas), validators, policies
├── capability/      capability model, registry, security gate (engine in P4)
├── research/        technology research gate (populated in P6)
├── project/         project-local layout definition
├── skills/          project-local skill layout (selection in P5)
├── mcp/             project-local MCP layout (discovery in later phase)
├── tests/           conformance suite + deliberately invalid fixtures
├── docs/            architecture docs and ADRs
├── legacy/          legacy protection manifest (read-only)
└── tools/           the P1 validator
```

### The one-way dependency rule

```
core/  +  governance/      agent-neutral, portable, deterministic
        ▲
        │  one-way (core MUST NOT import, reference or branch on an agent)
        │
   adapters/                thin, replaceable, deletable
```

**Portability test:** the core suite must pass with **every adapter deleted.**

---

## Global vs project-local

**Default: project-local.** Global state is exceptional and must be explicitly justified
and user-authorised.

| Class | Scope |
|---|---|
| Selected skills, capabilities, MCP config | **Project-local** |
| Capability registry, research cache, memory, decisions, evidence, tasks | **Project-local** |
| Icon library, design tokens | **Project-local** |
| This framework (`sps2/`) | Global (optional, read-only) |
| Machine-global installer | **Never** |

Two projects must be able to select **different** capabilities for the same domain with
no interference. Nothing is "install once, reuse forever".

---

## No emoji

**NO EMOJI by default** — in UI, buttons, labels, docs, code comments, generated copy and
status indicators. Use an appropriate icon library. Emoji are permitted only when a
specific project explicitly authorises them.

Icon libraries are **selectable capabilities**, not a globally pinned choice — pinning one
globally would recreate the legacy permanent-preference failure.

This rule is machine-checked by `tools/validate-sps2.sh`, not merely documented.

---

## Validation

```bash
bash sps2/tools/validate-sps2.sh              # structural + negative suite
bash sps2/tools/validate-sps2.sh --negative   # negative tests only
```

Validates **structured state**, not the presence of words in Markdown. Exit `0` valid,
`1` failure, `2` tooling unavailable.

---

## What P1 deliberately does NOT implement

Dynamic discovery · skill selection · MCP discovery · CMS · SEO · application workflows ·
concrete agent adapters beyond the contract · legacy migration · global installation ·
machine-global configuration · any Phase 01 remediation.

Those belong to later, separately approved phases.