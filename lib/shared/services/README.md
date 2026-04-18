# Service Structure

This folder now supports domain-based service organization while keeping the
existing flat imports working.

Suggested grouping:

- `admin/`
- `auth/`
- `community/`
- `commerce/`
- `core/`
- `farmer/`
- `integration/`
- `user/`

New code can prefer the barrel files inside those folders, for example:

- `shared/services/auth/auth_services.dart`
- `shared/services/community/community_services.dart`
- `shared/services/core/core_services.dart`
