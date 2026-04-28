---
name: ai-red-team-security
description: "Plan and execute adversarial testing for AI systems, including jailbreaks, prompt injection, and tool abuse."
---

# AI Red Team Security Skill

Use this skill to stress test AI behaviors under adversarial conditions.

## When to Apply

- Before production release of AI features
- After major model/prompt/tool changes
- After security incidents involving AI output/actions

## Test Categories

- Jailbreak attempts and policy evasion
- Prompt injection (direct and indirect)
- Role confusion and instruction override
- Data extraction and tenant-boundary tests
- Tool misuse and unauthorized action triggering
- Hallucinated function call and argument abuse

## Campaign Workflow

1. Define security objectives and forbidden outcomes.
2. Build adversarial test suite (manual + automated prompts).
3. Execute tests across model variants and temperatures.
4. Capture traces: prompt, context, output, tool calls.
5. Score findings by reproducibility and impact.
6. Patch controls and rerun regression set.

## Reporting Format

- Attack path
- Expected secure behavior
- Actual behavior
- Impact
- Proposed mitigation
- Retest result

## Done Criteria

- Critical and high findings addressed
- Regression suite added to CI/security checks
- Release sign-off includes AI red team report

## Quick Checklist

- [ ] Adversarial suite maintained
- [ ] Tool action tests included
- [ ] Multi-turn attacks tested
- [ ] Regression tests rerun after fixes
- [ ] Final report archived
