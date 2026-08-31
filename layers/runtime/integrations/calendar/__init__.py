"""Calendar integration (Google read + write; Outlook placeholder)."""

from .get_events import (
    events_for_day,
    format_event_line,
    get_events,
    parse_datetime_bound,
    verify_token_refresh,
)
from .oauth_skeleton import (
    GOOGLE_SCOPES,
    OUTLOOK_SCOPES,
    DependencyMissingError,
    NotConfiguredError,
    create_event,
    delete_event,
    get_credentials,
    get_service,
    list_events,
    oauth_config_path,
    start_oauth_flow,
    token_path,
)

__all__ = [
    "GOOGLE_SCOPES",
    "OUTLOOK_SCOPES",
    "DependencyMissingError",
    "NotConfiguredError",
    "create_event",
    "delete_event",
    "events_for_day",
    "format_event_line",
    "get_credentials",
    "get_events",
    "get_service",
    "list_events",
    "oauth_config_path",
    "parse_datetime_bound",
    "start_oauth_flow",
    "token_path",
    "verify_token_refresh",
]
