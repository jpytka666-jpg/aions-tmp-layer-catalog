# Runtime integrations (Senses — Fala 5)

Live integrations for external services — **read AND write**. No credentials in
repo; OAuth client config and tokens live in `runtime/secrets/` (gitignored).

**Encrypted vault (DPAPI):** long-term storage for OAuth client JSON — seal with
`scripts/vault/seal_secret.py`, open locally via `scripts/vault/open_secret.py`
→ see [`scripts/vault/README.md`](../../scripts/vault/README.md) and CBMS chunk
`KVAULTMETA001`. Agents must never echo secrets to chat.

**Stan 2026-07-12:** Google Calendar **GREEN** (live E2E po tokenie). Gmail kod REAL, token E2E pending. Outlook = **STUB**.
## Scope

| Service | Provider | Mode | Module |
|---------|----------|------|--------|
| Gmail | Google | read + send/modify | `gmail/` |
| Google Calendar | Google | read + create/delete | `calendar/` |
| Outlook (mail + calendar) | Microsoft | placeholder (not implemented) | `calendar/` |

Shared OAuth flow lives in `google_oauth.py` (installed-app flow, token persist,
auto-refresh).

## Security

1. **Never** print secret values (client_secret, tokens) to logs or reports.
2. OAuth client config + tokens live only in `runtime/secrets/` (gitignored).
3. Tokens saved with `0o600` perms where the OS allows.
4. Modules raise `NotConfiguredError` (missing config/token) or
   `DependencyMissingError` (google libs absent) instead of failing silently.

## OAuth flow (common)

```
Operator / CLI
    → oauth_skeleton.start_oauth_flow()
    → browser consent (Google or Microsoft)
    → redirect to localhost callback
    → token saved to runtime/secrets/<provider>_token.json
    → read client uses refresh token
```

### Google (Gmail + Calendar)

- Console: [Google Cloud Console](https://console.cloud.google.com/) → APIs & Services → Credentials.
- Enable Gmail API and/or Google Calendar API.
- OAuth 2.0 Client ID — **Desktop app** (recommended; loopback redirect).
- Scopes (read + write):
  - Gmail: `https://www.googleapis.com/auth/gmail.modify` + `.../gmail.send`
  - Calendar: `https://www.googleapis.com/auth/calendar`

### Microsoft (Outlook)

- [Azure Portal](https://portal.azure.com/) → App registrations.
- Redirect URI: `http://localhost:<port>/callback`.
- Scopes (delegated, read-only):
  - Mail: `Mail.Read`
  - Calendar: `Calendars.Read`

## Layout

```
runtime/integrations/
├── README.md          ← this file
├── google_oauth.py    ← shared OAuth flow (token persist + refresh)
├── gmail/
│   ├── README.md
│   └── oauth_skeleton.py   (list_messages / get_message / send_message)
└── calendar/
    ├── README.md
    └── oauth_skeleton.py   (list_events / create_event / delete_event)
```

## Next steps (Marcin)

1. Create a Google OAuth **Desktop app** client (Gmail API + Calendar API enabled).
2. Seal `client_secret.json` into the DPAPI vault (`google_oauth_client`), then
   `open_secret.py --out runtime/secrets/gmail_oauth.json` (and calendar copy).
   Plain drop into `runtime/secrets/` also works but vault is preferred.
3. Run `oauth_skeleton.py` once per provider to grant consent + persist token.
4. Code is live — API calls work immediately after the token exists.
