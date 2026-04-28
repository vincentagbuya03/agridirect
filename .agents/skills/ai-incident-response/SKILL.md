---
name: ai-incident-response
description: "Run incident response for AI security events including containment, forensics, and recovery."
---

# AI Incident Response Skill

Use this skill during suspected or confirmed AI security incidents.

## When to Apply

- Prompt injection leading to unsafe output/actions
- Suspected data leakage through AI responses
- Unauthorized tool/action execution
- Provider outage or compromise affecting AI operations

## Incident Lifecycle

1. Detect: alert triage and incident classification.
2. Contain: disable risky tools/features and rotate credentials.
3. Investigate: gather logs, prompts, context, and tool traces.
4. Eradicate: patch root cause and strengthen controls.
5. Recover: staged restore with heightened monitoring.
6. Learn: postmortem and control updates.

## Immediate Containment Actions

- Disable high-risk actions in agent tool router
- Revoke and rotate affected API keys/tokens
- Restrict outbound calls to known-safe allowlist
- Switch to safer fallback model/policy mode

## Forensics Data to Preserve

- Request IDs and timestamps
- Prompt and retrieval context snapshots
- Model outputs and tool call payloads
- Auth actor and tenant metadata
- Deployment/version metadata

## Done Criteria

- Incident impact and scope confirmed
- Root cause identified and fixed
- Regression tests added
- Postmortem completed with action owners

## Quick Checklist

- [ ] Containment executed quickly
- [ ] Evidence preserved
- [ ] Keys rotated if needed
- [ ] Customer/internal comms completed
- [ ] Lessons captured and tracked
