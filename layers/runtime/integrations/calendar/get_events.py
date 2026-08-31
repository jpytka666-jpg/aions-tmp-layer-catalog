"""Google Calendar read helpers — date-range queries and token refresh check.

MCP alias: ``calendar.get_events`` (registered as ``calendar_get_events``).
"""

from __future__ import annotations

from datetime import date, datetime, time, timedelta, timezone
from typing import Any

from .. import google_oauth as _g
from .oauth_skeleton import (
    GOOGLE_SCOPES,
    NotConfiguredError,
    Provider,
    _require_google,
    _to_rfc3339,
    get_credentials,
    get_service,
    token_path,
)


def parse_datetime_bound(value: str | datetime | date, *, end_of_day: bool = False) -> datetime:
    """Parse ISO date or datetime string to a timezone-aware datetime (UTC)."""
    if isinstance(value, datetime):
        dt = value
    elif isinstance(value, date):
        dt = datetime.combine(value, time.max if end_of_day else time.min)
    else:
        raw = str(value).strip()
        if "T" not in raw and len(raw) >= 10:
            d = date.fromisoformat(raw[:10])
            dt = datetime.combine(d, time.max if end_of_day else time.min)
        else:
            dt = datetime.fromisoformat(raw.replace("Z", "+00:00"))
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc)


def get_events(
    start: str | datetime | date,
    end: str | datetime | date,
    *,
    max_results: int = 10,
    calendar_id: str = "primary",
    provider: Provider = "google",
) -> list[dict[str, Any]]:
    """List calendar events in [start, end], ordered by start time (read-only).

    Parameters
    ----------
    start, end:
        ISO-8601 datetime or date string (``YYYY-MM-DD``). Date-only ``end``
        is treated as end-of-day inclusive.
    max_results:
        Maximum events returned (default 10).
    """
    _require_google(provider)
    if not token_path(provider).is_file():
        raise NotConfiguredError(
            f"Brak tokena kalendarza: {token_path(provider)}. "
            "Uruchom oauth_skeleton.py google aby uzyskac token."
        )
    if max_results < 1:
        raise ValueError("max_results musi byc >= 1")

    time_min = parse_datetime_bound(start, end_of_day=False)
    time_max = parse_datetime_bound(end, end_of_day=True)

    service = get_service(provider)
    resp = (
        service.events()
        .list(
            calendarId=calendar_id,
            timeMin=_to_rfc3339(time_min),
            timeMax=_to_rfc3339(time_max),
            maxResults=max_results,
            singleEvents=True,
            orderBy="startTime",
        )
        .execute()
    )

    out: list[dict[str, Any]] = []
    for ev in resp.get("items", []):
        ev_start = ev.get("start", {})
        ev_end = ev.get("end", {})
        out.append(
            {
                "id": ev.get("id"),
                "summary": ev.get("summary", "(bez tytulu)"),
                "start": ev_start.get("dateTime") or ev_start.get("date"),
                "end": ev_end.get("dateTime") or ev_end.get("date"),
                "location": ev.get("location", ""),
                "htmlLink": ev.get("htmlLink", ""),
                "status": ev.get("status", ""),
            }
        )
    return out


def verify_token_refresh(*, provider: Provider = "google", force: bool = True) -> dict[str, Any]:
    """Verify OAuth refresh path without exposing secrets.

    Loads credentials (auto-refresh if expired), optionally forces
    ``credentials.refresh()`` when a refresh token is present, and reports
    whether the token file was rewritten.
    """
    _require_google(provider)
    tp = token_path(provider)
    if not tp.is_file():
        raise NotConfiguredError(f"Brak tokena: {tp}")

    mtime_before = tp.stat().st_mtime
    creds = get_credentials(provider)

    status: dict[str, Any] = {
        "token_file": str(tp),
        "valid": creds.valid,
        "expired": creds.expired,
        "has_refresh_token": bool(creds.refresh_token),
        "refreshed": False,
        "token_rewritten": False,
    }

    if force and creds.refresh_token:
        _g.ensure_google_libs()
        from google.auth.transport.requests import Request

        creds.refresh(Request())
        _g.persist_credentials(tp, creds)
        status["refreshed"] = True
        status["valid"] = creds.valid
        status["expired"] = creds.expired
        status["token_rewritten"] = tp.stat().st_mtime > mtime_before

    return status


def events_for_day(
    day: date,
    *,
    max_results: int = 50,
    provider: Provider = "google",
) -> list[dict[str, Any]]:
    """Convenience: all events on a single calendar day."""
    return get_events(day, day, max_results=max_results, provider=provider)


def format_event_line(ev: dict[str, Any]) -> str:
    """Safe one-line display: start + title only."""
    return f"{ev.get('start', '?')} | {ev.get('summary', '(bez tytulu)')}"
