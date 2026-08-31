"""Gmail integration (read + send/modify)."""

from .oauth_skeleton import (
    SCOPES,
    DependencyMissingError,
    NotConfiguredError,
    get_credentials,
    get_message,
    get_service,
    list_messages,
    oauth_config_path,
    send_message,
    start_oauth_flow,
    token_path,
)

__all__ = [
    "SCOPES",
    "DependencyMissingError",
    "NotConfiguredError",
    "get_credentials",
    "get_message",
    "get_service",
    "list_messages",
    "oauth_config_path",
    "send_message",
    "start_oauth_flow",
    "token_path",
]
