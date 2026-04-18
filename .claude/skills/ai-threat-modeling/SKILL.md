---
name: ai-threat-modeling
description: "Run AI-specific threat modeling for LLM apps, agents, and model-integrated pipelines."
---

# AI Threat Modeling Skill

Use this skill to identify and mitigate AI-specific threats before release.

## When to Apply

- New AI endpoint, agent, or tool integration
- Major prompt or retrieval pipeline changes
- New model provider onboarding
- Security review before production launch

## Threat Areas

- Prompt injection and instruction hijacking
- Data exfiltration via context/tool calls
- Over-permissioned tools and function abuse
- Model output misuse (unsafe automation)
- Poisoned retrieval content
- Multi-tenant isolation failures

## Modeling Workflow

1. Define assets: secrets, PII, actions, business-critical workflows.
2. Define actors: normal user, malicious user, compromised integration.
3. Map entry points: prompt, file upload, URL input, tool responses.
4. Enumerate abuse cases per entry point.
5. Rate risk by likelihood x impact.
6. Add mitigations and owners.
7. Re-test high-risk paths after fixes.

## Severity Guidance

- Critical: secret leakage, unauthorized financial/admin action
- High: cross-tenant data exposure, policy bypass with side effects
- Medium: denial-of-service, degraded integrity
- Low: cosmetic output issues

## Done Criteria

- Threat model table completed
- Top risks have concrete mitigations
- Security tests cover critical/high threats
- Residual risk accepted explicitly

## Quick Checklist

- [ ] Assets and trust boundaries listed
- [ ] Prompt injection scenarios covered
- [ ] Tool abuse scenarios covered
- [ ] Data leakage paths assessed
- [ ] Risk owners assigned
