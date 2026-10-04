#!/usr/bin/env python3
"""SPS 2.0 P5 approval-attribution governance control.

This module lives in governance/, not core/, for a specific architectural
reason: the core must be agent-neutral and must never reference or branch on a
specific agent. Detecting an agent-attributed approval necessarily requires
knowing what agent names look like, so that knowledge is confined here, behind
the core/governance boundary, and the core receives it as an injected
predicate rather than hard-coding it.

Core therefore never names an agent, and the control still holds.
"""
import re

# Names that indicate the decision was made by an automated agent rather than
# by an identifiable human User.
AGENTISH = re.compile(
    r"\b(agent|ai|assistant|model|bot|claude|cursor|codex|gemini|opencode|"
    r"cline|copilot|windsurf|aider|chatgpt|gpt)\b", re.I)


def approval_is_user_attributable(approval):
    """True only for an APPROVED decision naming an identifiable User.

    Requires an APPROVED state, a non-empty decider that is not an agent name,
    and a decision date. Any missing element is not an approval.
    """
    a = approval or {}
    if a.get("state") != "APPROVED":
        return False
    who = (a.get("decided_by") or "").strip()
    if not who or AGENTISH.search(who):
        return False
    return bool((a.get("decided_on") or "").strip())


def reason_not_attributable(approval):
    """Explain why an approval is not valid. Empty string means valid."""
    a = approval or {}
    if a.get("state") != "APPROVED":
        return "approval state is %r, not APPROVED" % (a.get("state"),)
    who = (a.get("decided_by") or "").strip()
    if not who:
        return "APPROVED without decided_by"
    if AGENTISH.search(who):
        return "APPROVED by an agent, not a user: %r" % who
    if not (a.get("decided_on") or "").strip():
        return "APPROVED without decided_on"
    return ""