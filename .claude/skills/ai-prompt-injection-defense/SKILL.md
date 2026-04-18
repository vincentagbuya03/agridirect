---
name: ai-prompt-injection-defense
description: "Defend against prompt injection and context poisoning in LLM and agent pipelines."
---

# AI Prompt Injection Defense Skill

Use this skill when implementing or reviewing protections against prompt injection.

## When to Apply

- Any feature that accepts user text, files, URLs, or retrieved content
- RAG pipelines and web/document ingestion
- Agent tool-calling workflows

## Defensive Patterns

1. Role separation: system policy isolated from user/retrieved content.
2. Structured prompts: explicit fields, no free-form policy blending.
3. Context labeling: mark untrusted chunks with source and trust level.
4. Policy firewall: block disallowed intents before tool execution.
5. Output gate: validate final output against safety and schema.
6. Human-in-the-loop for sensitive operations.

## Required Safeguards

- Content provenance tracking
- URL/domain allowlists for retrieval
- Prompt budget limits to reduce attack surface
- Tool allowlist with per-tool argument validation
- Rejection templates for policy-violating requests

## Anti-Patterns to Avoid

- Directly appending untrusted text into system instructions
- Allowing model to choose unrestricted tools
- Treating markdown/code blocks as trusted commands
- Executing model-generated shell or SQL without validation

## Done Criteria

- Untrusted context isolation implemented
- Tool call policy enforcement active
- Injection test cases pass
- Sensitive actions require explicit approval

## Quick Checklist

- [ ] Context is trust-labeled
- [ ] Tool calls are policy-checked
- [ ] Output is schema-validated
- [ ] Retrieval sources are restricted
- [ ] Injection regression tests exist
