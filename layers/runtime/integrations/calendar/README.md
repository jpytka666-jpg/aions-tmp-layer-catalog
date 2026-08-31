# Calendar (read + write)

Google Calendar — **read AND write** (list / create / delete). Outlook = placeholder.

## Scopes

| Provider | Scope | Config | Token |
|----------|-------|--------|-------|
| Google | `https://www.googleapis.com/auth/calendar` | `runtime/secrets/google_calendar_oauth.json` | `google_calendar_token.json` |
| Microsoft | `Calendars.ReadWrite` (placeholder, nie zaimplementowane) | `runtime/secrets/outlook_oauth.json` | `outlook_token.json` |

## Konfiguracja Google Calendar (Marcin) — jednorazowo

1. [Google Cloud Console](https://console.cloud.google.com/) → ten sam projekt co Gmail
   (lub osobny).
2. **APIs & Services → Library** → włącz **Google Calendar API**.
3. **OAuth consent screen** → dodaj siebie jako **Test user**.
4. **Credentials → Create credentials → OAuth client ID → Desktop app** → pobierz JSON.
   Można użyć tego samego client ID co Gmail (wtedy skopiuj ten sam plik).
5. Zapisz jako `runtime/secrets/google_calendar_oauth.json` (surowy Google JSON lub):

```json
{
  "client_id": "YOUR_CLIENT_ID.apps.googleusercontent.com",
  "client_secret": "YOUR_CLIENT_SECRET",
  "redirect_uri": "http://localhost:8081/"
}
```

6. Pierwszy flow:

```powershell
cd "E:\server wiedzy"
.\scripts\aions_python.ps1 runtime\integrations\calendar\oauth_skeleton.py google
```

Token → `runtime/secrets/google_calendar_token.json` (gitignored), potem auto-refresh.

## API (Google)

| Funkcja | Tryb | Opis |
|---------|------|------|
| `start_oauth_flow("google")` | — | Consent + zapis tokena |
| `get_credentials()` / `get_service()` | — | Poświadczenia / klient Calendar API |
| `list_events(max_results=10, calendar_id="primary")` | read | Najbliższe wydarzenia |
| `get_events(start, end, max_results=10)` | read | Wydarzenia w zakresie dat (MCP: `calendar_get_events`) |
| `verify_token_refresh()` | — | Sprawdzenie odświeżania tokena (bez sekretów) |
| `create_event(summary=, start=, end=, ...)` | **write** | Utworzenie wydarzenia |
| `delete_event(event_id, calendar_id="primary")` | **write** | Usunięcie wydarzenia |

`start` / `end` przyjmują ISO-8601 string lub `datetime`.

## Przykład

```python
from datetime import datetime, timedelta, timezone
from runtime.integrations.calendar import list_events, create_event, delete_event

for e in list_events(max_results=5):
    print(e["start"], e["summary"])

start = datetime.now(timezone.utc) + timedelta(days=7)
ev = create_event(summary="AIONS test", start=start, end=start + timedelta(hours=1))
# delete_event(ev["id"])   # sprzątanie
```

## Outlook

Nie zaimplementowane. `provider="outlook"` rzuca `NotConfiguredError`. Wire `msal`
w kolejnej fali jeśli potrzebne.
