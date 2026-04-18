---
name: agridirect-engineering
description: "Agridirect Flutter + Supabase implementation skill. Use for auth flows, schema migrations, RPC/Edge Function integration, and web/mobile parity updates."
---

# Agridirect Engineering Skill

Use this skill when implementing or fixing Agridirect features across Flutter web/mobile and Supabase.

## When to Apply

Apply this skill for requests involving:

- Authentication screens and service logic
- OTP and password reset behavior
- Supabase schema cleanup and migrations
- Admin/farmer/consumer data queries
- Route updates and navigation consistency

## Stack Context

- Frontend: Flutter (web + mobile)
- Backend: Supabase (PostgreSQL, RPC, Edge Functions)
- Routing: GoRouter
- Primary folders:
  - lib/mobile
  - lib/web
  - lib/shared/services
  - lib/shared/router
  - supabase/migrations
  - supabase/database.sql

## Implementation Rules

1. Keep web and mobile behavior aligned unless explicitly different by requirement.
2. Put business logic in services, not directly in UI widgets.
3. Validate user input in UI before service calls.
4. Keep database enums/domains hardcoded via CHECK constraints when requested.
5. Prefer additive migrations; avoid unsafe destructive changes without explicit request.
6. Preserve compatibility views only when actively used.
7. For auth UX, provide clear error messages and loading guards.
8. Reuse active OTP codes if security policy allows and code is still valid.

## Auth Flow Patterns

### Password Reset with Hidden Code

- Send/reset entry step:
  - Trigger sendResetCode(email)
  - Reuse active unexpired code when available
- Reset step:
  - Ask only for new password and confirm password
  - Resolve active code server-side via service
  - Fail with clear message if code expired/used

### OTP UX

- Prefer automatic verification when code length is complete.
- Prevent duplicate concurrent verification calls.
- Show actionable error copy for expired/invalid code.

## Supabase Migration Workflow

1. Create focused migration in supabase/migrations with timestamped filename.
2. Update canonical schema in supabase/database.sql to match migration intent.
3. Handle dependent views/functions before dropping columns/tables.
4. Backfill data before applying NOT NULL constraints.
5. Push and verify with db push.

## Query and Relation Safety

- Use explicit relation paths when PostgREST embeds are ambiguous.
- Keep service query shape stable for UI consumers.
- Normalize email and identity fields before lookups.

## Done Criteria

A task is complete when:

- Changed UI compiles without errors
- Service methods are wired to current flow
- Route/navigation paths are valid
- Migration and canonical schema are consistent
- User-facing messages match expected UX

## Quick Checklist

- [ ] No duplicate submit calls
- [ ] Mounted checks before navigation/snackbar after async
- [ ] Password confirmation validated
- [ ] Error handling returns friendly messages
- [ ] Web/mobile parity reviewed
- [ ] Supabase schema drift avoided
