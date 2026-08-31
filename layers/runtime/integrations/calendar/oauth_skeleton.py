"""Calendar integration — Google Calendar read AND write.

Google: list / create / delete events. OAuth client config + token live in
``runtime/secrets/`` (gitignored). No secrets in this file.

Config file : ``runtime/secrets/google_calendar_oauth.json``
Token file  : ``runtime/secrets/google_calendar_token.json``

Outlook (Microsoft Graph) is intentionally left as a documented placeholder;
wire ``msal`` in a later wave if needed.
"""

from __future__ import annotations

import os
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Literal

if __package__:
    from .. import google_oauth as _g
else:  # pragma: no cover - CLI convenience
    # This package folder is named "calendar", which would shadow Python's stdlib
    # ``calendar`` (pulled in deep inside the google/requests libs). Adding the
    # integrations dir to sys.path would re-expose this subpackage as a top-level
    # ``calendar`` and break those libs, so load google_oauth by file path instead
    # (and drop any sys.path entry pointing at this folder).
    _self_dir = Path(__file__).resolve().parent
    sys.path[:] = [
        p for p in sys.path
        if (lambda q: q != _self_dir)(Path(p or ".").resolve())
    ]
    import importlib.util as _ilu

    _g_path = Path(__file__).resolve().parents[1] / "google_oauth.py"
    _g_spec = _ilu.spec_from_file_location("aions_google_oauth", _g_path)
    _g = _ilu.module_from_spec(_g_spec)
    _g_spec.loader.exec_module(_g)  # type: ignore[union-attr]

NotConfiguredError = _g.NotConfiguredError
DependencyMissingError = _g.DependencyMissingError

Provider = Literal["google", "outlook"]

# Full read+write calendar scope.
GOOGLE_SCOPES = ("https://www.googleapis.com/auth/calendar",)
OUTLOOK_SCOPES = ("Calendars.ReadWrite",)
DEFAULT_REDIRECT_URI = "http://localhost:8081/"
_REDIRECT_PORT = 8081

_CONFIG_NAMES: dict[Provider, str] = {
    "google": "google_calendar_oauth.json",
    "outlook": "outlook_oauth.json",
}
_TOKEN_NAMES: dict[Provider, str] = {
    "google": "google_calendar_token.json",
    "outlook": "outlook_token.json",
}


def oauth_config_path(provider: Provider = "google") -> Path:
    return _g.secrets_dir() / _CONFIG_NAMES[provider]


def token_path(provider: Provider = "google") -> Path:
    return _g.secrets_dir() / _TOKEN_NAMES[provider]


def _require_google(provider: Provider) -> None:
    if provider != "google":
        raise NotConfiguredError(
            "Outlook nie jest jeszcze zaimplementowany (placeholder). "
            "Uzyj provider='google' lub dodaj integracje msal w kolejnej fali."
        )


def get_credentials(provider: Provider = "google", *, open_browser: bool = False):
    _require_google(provider)
    return _g.get_credentials(
        config_path=oauth_config_path(provider),
        token_path=token_path(provider),
        scopes=GOOGLE_SCOPES,
        redirect_uri=DEFAULT_REDIRECT_URI,
        port=_REDIRECT_PORT,
        open_browser=open_browser,
    )


def get_service(provider: Provider = "google"):
    return _g.build_service("calendar", "v3", get_credentials(provider))


def start_oauth_flow(provider: Provider = "google") -> Path:
    """Run consent (if needed) and persist token. Returns token path."""
    get_credentials(provider, open_browser=False)
    return token_path(provider)


def _to_rfc3339(value: str | datetime) -> str:
    if isinstance(value, datetime):
        if value.tzinfo is None:
            value = value.replace(tzinfo=timezone.utc)
        return value.isoformat()
    return value


def list_events(
    *,
    provider: Provider = "google",
    max_results: int = 10,
    calendar_id: str = "primary",
    time_min: str | datetime | None = None,
) -> list[dict[str, Any]]:
    """List upcoming events ordered by start time (read)."""
    _require_google(provider)
    service = get_service(provider)
    tmin = _to_rfc3339(time_min) if time_min else datetime.now(timezone.utc).isoformat()
    resp = (
        service.events()
        .list(
            calendarId=calendar_id,
            timeMin=tmin,
            maxResults=max_results,
            singleEvents=True,
            orderBy="startTime",
        )
        .execute()
    )
    out: list[dict[str, Any]] = []
    for ev in resp.get("items", []):
        start = ev.get("start", {})
        end = ev.get("end", {})
        out.append(
            {
                "id": ev.get("id"),
                "summary": ev.get("summary", "(bez tytulu)"),
                "start": start.get("dateTime") or start.get("date"),
                "end": end.get("dateTime") or end.get("date"),
                "location": ev.get("location", ""),
                "htmlLink": ev.get("htmlLink", ""),
                "status": ev.get("status", ""),
            }
        )
    return out


def create_event(
    *,
    summary: str,
    start: str | datetime,
    end: str | datetime,
    provider: Provider = "google",
    calendar_id: str = "primary",
    description: str = "",
    location: str = "",
    timezone_name: str = "UTC",
) -> dict[str, Any]:
    """Create a timed event (write). Returns {id, summary, start, htmlLink}."""
    _require_google(provider)
    service = get_service(provider)
    body: dict[str, Any] = {
        "summary": summary,
        "description": description,
        "location": location,
        "start": {"dateTime": _to_rfc3339(start), "timeZone": timezone_name},
        "end": {"dateTime": _to_rfc3339(end), "timeZone": timezone_name},
    }
    ev = service.events().insert(calendarId=calendar_id, body=body).execute()
    return {
        "id": ev.get("id"),
        "summary": ev.get("summary"),
        "start": ev.get("start", {}).get("dateTime"),
        "end": ev.get("end", {}).get("dateTime"),
        "htmlLink": ev.get("htmlLink", ""),
    }


def delete_event(
    event_id: str,
    *,
    provider: Provider = "google",
    calendar_id: str = "primary",
) -> bool:
    """Delete an event by id (write). Returns True on success."""
    _require_google(provider)
    service = get_service(provider)
    service.events().delete(calendarId=calendar_id, eventId=event_id).execute()
    return True


def _cli() -> None:
    provider: Provider = "google"
    if len(sys.argv) > 1 and sys.argv[1] in _CONFIG_NAMES:
        provider = sys.argv[1]  # type: ignore[assignment]
    try:
        path = start_oauth_flow(provider)
        print(f"[calendar:{provider}] Token OK -> {path}")
        events = list_events(provider=provider, max_results=5)
        print(f"[calendar:{provider}] Najblizsze {len(events)} wydarzen:")
        for e in events:
            print(f"  - {e['start']} | {e['summary']}")
    except (NotConfiguredError, DependencyMissingError) as exc:
        print(f"[calendar:{provider}] {exc}")


if __name__ == "__main__":
    _cli()
