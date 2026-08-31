# Gmail (read + write)

Google Gmail API — **read AND write** (list / get / send). Brak credentiali w repo.

## Scopes

```
https://www.googleapis.com/auth/gmail.modify   # read + labels/modify
https://www.googleapis.com/auth/gmail.send     # send mail
```

## Konfiguracja (Marcin) — jednorazowo

1. [Google Cloud Console](https://console.cloud.google.com/) → wybierz/utwórz projekt.
2. **APIs & Services → Library** → włącz **Gmail API**.
3. **APIs & Services → OAuth consent screen** → typ **External** → dodaj siebie jako
   **Test user** (adres Gmail). Scope'y dodadzą się automatycznie przy flow.
4. **APIs & Services → Credentials → Create credentials → OAuth client ID** →
   typ **Desktop app**. Pobierz JSON.
5. Zapisz plik poza gitem jako `runtime/secrets/gmail_oauth.json`. Akceptowane formaty:
   - surowy plik z Google (`{"installed": {...}}`), **lub**
   - uproszczony:

```json
{
  "client_id": "YOUR_CLIENT_ID.apps.googleusercontent.com",
  "client_secret": "YOUR_CLIENT_SECRET",
  "redirect_uri": "http://localhost:8080/"
}
```

6. Pierwszy flow (otworzy przeglądarkę, poprosi o zgodę):

```powershell
cd "E:\server wiedzy"
.\scripts\aions_python.ps1 runtime\integrations\gmail\oauth_skeleton.py
```

Token trafi do `runtime/secrets/gmail_token.json` (gitignored). Kolejne uruchomienia
odświeżają token automatycznie (refresh token) — bez ponownej zgody.

## API

| Funkcja | Tryb | Opis |
|---------|------|------|
| `start_oauth_flow()` | — | Consent + zapis tokena, zwraca ścieżkę tokena |
| `get_credentials()` / `get_service()` | — | Poświadczenia / klient Gmail API |
| `list_messages(max_results=10, query="")` | read | Lista ostatnich maili (subject/from/date/snippet) |
| `get_message(message_id)` | read | Pełna wiadomość + tekst body |
| `send_message(to=, subject=, body_text=, cc=, bcc=)` | **write** | Wysłanie maila (plaintext) |

## Przykład

```python
from runtime.integrations.gmail import list_messages, send_message

for m in list_messages(max_results=3):
    print(m["date"], m["from"], m["subject"])

# send jest gotowy — wywołuj świadomie:
# send_message(to="ktos@example.com", subject="Test", body_text="Hej")
```
