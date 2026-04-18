---
name: ai-security-architecture
description: "Design and enforce security architecture for AI systems, including trust boundaries, control mapping, and defense-in-depth."
---

# AI Security Architecture Skill

Use this skill to define secure-by-default architecture for AI features and services.

## When to Apply

- Building new AI features (chat, recommendation, automation)
- Integrating external models or APIs
- Splitting trusted/untrusted runtime components
- Defining baseline controls before implementation

## Core Architecture Principles

1. Define strict trust boundaries: client, API, model gateway, model provider, data stores.
2. Treat prompts, retrieved context, and tool outputs as untrusted input.
3. Apply least privilege for model tool access and service credentials.
4. Enforce policy before model execution and before side effects.
5. Keep auditability end-to-end: request, context, model output, action.

## Security Control Layers

- Input controls: sanitization, policy filters, size/token caps, schema validation
- Runtime controls: scoped tool permissions, sandboxing, outbound allowlists
- Output controls: redaction, policy checks, structured output validation
- Action controls: approval gates for sensitive actions
- Monitoring controls: logs, anomaly detection, alerting

## Reference Blueprint

- Edge/API Layer: authN/authZ, rate limits, request validation
- AI Orchestrator: prompt templates, policy engine, tool router
- Model Layer: provider abstraction, fallback model, timeout budget
- Tool Layer: signed requests, minimal scopes, deterministic interfaces
- Data Layer: PII tags, encrypted storage, retention policy

## Done Criteria

- Trust boundaries documented
- Security controls mapped per layer
- Privilege model defined for each tool/action
- Sensitive actions gated and auditable
- Abuse and failure modes documented

## Quick Checklist

- [ ] Boundary map exists
- [ ] Tool permissions are scoped
- [ ] Prompt/context treated as untrusted
- [ ] Output validation enabled
- [ ] Logging supports incident forensics
