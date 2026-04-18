---
name: ai-secure-mlops-supply-chain
description: "Secure model supply chain, dependencies, deployment, and runtime integrity for AI systems."
---

# AI Secure MLOps and Supply Chain Skill

Use this skill to secure model artifacts, dependencies, and deployment pipelines.

## When to Apply

- Introducing new model artifacts or embeddings
- Updating model versions/providers
- Containerizing and deploying AI services
- Hardening CI/CD for AI components

## Supply Chain Controls

1. Verify artifact integrity (hash/signature checks).
2. Pin model and dependency versions.
3. Use trusted registries and provenance attestations.
4. Scan containers and dependencies for vulnerabilities.
5. Restrict runtime network egress.

## CI/CD Security Steps

- Reproducible builds for model-serving services
- SBOM generation and storage
- Secret scanning and policy checks in pipeline
- Security gates before deployment
- Progressive rollout with rollback plan

## Runtime Integrity

- Read-only root filesystem where possible
- Non-root containers and minimal base images
- Memory/CPU quotas and timeout budgets
- Runtime telemetry and tamper alerts

## Done Criteria

- Artifact provenance verified
- Pipeline includes security gates
- Runtime hardening baseline applied
- Rollback and incident playbook tested

## Quick Checklist

- [ ] SBOM generated
- [ ] Vulnerability scans pass threshold
- [ ] Secrets not embedded in artifacts
- [ ] Egress restricted
- [ ] Rollback procedure documented
