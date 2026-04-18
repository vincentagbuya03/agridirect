---
name: ai-data-privacy-compliance
description: "Apply privacy and compliance controls for AI data handling, retention, and user rights."
---

# AI Data Privacy and Compliance Skill

Use this skill for secure handling of personal, sensitive, and regulated data in AI systems.

## When to Apply

- AI features processing user-generated text or profile data
- Logging prompts/outputs
- Third-party model provider integrations
- Compliance-focused releases (GDPR/CCPA/SOC2/ISO)

## Data Governance Rules

1. Data minimization: only send required fields to models.
2. Purpose limitation: do not repurpose data without approval.
3. Retention controls: define and enforce deletion timelines.
4. Right-to-delete support: remove user data from logs/indexes.
5. Region controls: keep data in approved jurisdictions.

## Technical Controls

- PII detection and redaction before model calls
- Encryption in transit and at rest
- Tokenization/pseudonymization of identifiers
- Segregated logs for operational vs security uses
- Access controls and break-glass procedures

## Provider Risk Checks

- Model provider data usage terms reviewed
- Training-on-customer-data disabled where possible
- DPA and compliance documentation recorded
- Incident notification clauses verified

## Done Criteria

- Data flow diagram with PII tags exists
- Retention/deletion policy implemented
- Provider controls validated
- Privacy impact review completed

## Quick Checklist

- [ ] PII redaction in prompt pipeline
- [ ] Retention period defined
- [ ] Delete workflow tested
- [ ] Provider settings documented
- [ ] Access audited
