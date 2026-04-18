AgriDirect Network Diagram

What this shows:

- Clients: Flutter mobile (Android/iOS) and Flutter Web (hosted on Vercel).
- Device features used on mobile: Camera, ML Kit, Google Sign-In.
- Supabase components: Auth, Postgres (database), Storage (buckets), Realtime, Edge Functions, and Supabase Studio for admin.
- External providers: Google OAuth, SMTP/email provider, S3-compatible storage and third-party analytics/APIs.

How to render:

- Quick: Paste `network_diagram.mmd` content into https://mermaid.live to preview and export PNG/SVG.
- VS Code: Install a Mermaid preview extension (e.g., "Markdown Preview Mermaid Support") and open the `.mmd` file.
- CLI: Use `mmdc` (mermaid-cli) to convert to PNG/SVG:

  npm install -g @mermaid-js/mermaid-cli
  mmdc -i diagrams/network_diagram.mmd -o diagrams/network_diagram.png

Notes and assumptions:

- Supabase is used as the primary backend (Auth + Postgres + Storage + Realtime + Edge); config exists in `supabase/config.toml`.
- `google-services.json` is present for Android (project may use Firebase for some Android-specific integrations).
- If you want a rendered PNG/SVG here, I can generate and add it to `diagrams/` next.
