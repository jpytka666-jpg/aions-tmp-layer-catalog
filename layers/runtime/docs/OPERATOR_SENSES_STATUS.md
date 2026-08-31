# Operator Senses — integration status

Last updated: 2026-07-12 (calendar E2E smoke)

| Integration | Provider | Mode | Status | MCP tool | Notes |
|-------------|----------|------|--------|----------|-------|
| Gmail | Google | read + send | YELLOW | — | code ready; token E2E pending |
| Google Calendar | Google | read + write | **GREEN** | `calendar_get_events` (alias `calendar.get_events`) | live E2E OK after token |
| Outlook mail | Microsoft | — | STUB | — | placeholder |
| Outlook calendar | Microsoft | — | STUB | — | placeholder |

## Google Calendar (GREEN)

- OAuth client: `runtime/secrets/google_calendar_oauth.json`
- Token: `runtime/secrets/google_calendar_token.json`
- Module: `runtime/integrations/calendar/get_events.py`
- Smoke: `scripts/calendar_e2e_smoke.py`

```powershell
cd "E:\server wiedzy"
.\scripts\aions_python.ps1 scripts\calendar_e2e_smoke.py
```

MCP (aions-context, after Reload MCP):

```
calendar_get_events(start="2026-07-12", end="2026-07-13", max_results=10)
```

## AI handoff (2026-07-12)

Dense machine handoff for successor agents: `runtime/docs/AI_HANDOFF_OPERATOR_SENSES_2026-07-12.json` · CBMS chunk `KHANDFFCAL001`.

## Faza 6 node registry (2026-07-12)

MVP scaffolding (not live multi-worker): `control_plane/node_registry.py`, `POST/GET /v1/nodes`, `runtime/host/install_aions_node.sh`, heartbeat `scripts/aions_node_heartbeat.py`. Smoke: `scripts/test_node_registry.py`.

## Security

Never log or print: `client_secret`, `refresh_token`, access `token` JSON contents.
