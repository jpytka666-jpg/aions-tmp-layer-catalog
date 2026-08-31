"""Shared Google OAuth 2.0 helper for AIONS integrations (Gmail + Calendar).

Read AND write. Handles the installed-app OAuth flow, token persistence, and
automatic refresh. No secrets live in this file or anywhere in the tracked repo
— OAuth client config and tokens are read from / written to ``runtime/secrets/``
which is gitignored.

Design notes
------------
* Google libraries are imported lazily so the rest of the codebase (and static
  import scanners) do not hard-fail when the libs are absent. Call
  :func:`ensure_google_libs` (or any high-level function) to trigger the check.
* ``get_credentials`` accepts either the simple AIONS config shape
  ``{"client_id": ..., "client_secret": ...}`` or a raw Google Cloud Console
  download (``{"installed": {...}}`` / ``{"web": {...}}``).
"""

from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Any, Iterable, Sequence

DEFAULT_AUTH_URI = "https://accounts.google.com/o/oauth2/auth"
DEFAULT_TOKEN_URI = "https://oauth2.googleapis.com/token"


class NotConfiguredError(RuntimeError):
    """Raised when OAuth client config or a saved token is missing/incomplete."""


class DependencyMissingError(RuntimeError):
    """Raised when the google-auth / google-api-python-client libs are absent."""


def _repo_root() -> Path:
    env = os.environ.get("AIONS_PATH", "").strip()
    if env:
        return Path(env).parent
    for candidate in (
        Path(r"E:\server wiedzy"),
        Path("/mnt/e/server wiedzy"),
        Path("/mnt/d/AIONS_DEV/repo/server-wiedzy"),
    ):
        if candidate.exists():
            return candidate
    return Path(__file__).resolve().parents[2]


def secrets_dir() -> Path:
    path = _repo_root() / "runtime" / "secrets"
    path.mkdir(parents=True, exist_ok=True)
    return path


def ensure_google_libs() -> None:
    """Raise a clear error if the Google client libraries are not installed."""
    try:
        import google.auth  # noqa: F401
        import google_auth_oauthlib  # noqa: F401
        import googleapiclient  # noqa: F401
    except ImportError as exc:  # pragma: no cover - environment dependent
        raise DependencyMissingError(
            "Brak bibliotek Google. Zainstaluj do prod venv:\n"
            "  .\\scripts\\aions_python.ps1 -m pip install "
            "google-api-python-client google-auth google-auth-oauthlib\n"
            f"(oryginalny blad importu: {exc})"
        ) from exc


def _normalize_client_config(raw: dict[str, Any], redirect_uri: str | None) -> dict[str, Any]:
    """Return an InstalledAppFlow-compatible client_config dict.

    Accepts the AIONS-simple shape or a raw Google Cloud Console download.
    """
    if "installed" in raw or "web" in raw:
        key = "installed" if "installed" in raw else "web"
        section = dict(raw[key])
        if redirect_uri:
            uris = list(section.get("redirect_uris") or [])
            if redirect_uri not in uris:
                uris.append(redirect_uri)
            section["redirect_uris"] = uris or [redirect_uri]
        return {key: section}

    client_id = str(raw.get("client_id", "")).strip()
    client_secret = str(raw.get("client_secret", "")).strip()
    if not client_id or not client_secret:
        raise NotConfiguredError(
            "Niekompletny config OAuth: wymagane 'client_id' i 'client_secret'."
        )
    section: dict[str, Any] = {
        "client_id": client_id,
        "client_secret": client_secret,
        "auth_uri": str(raw.get("auth_uri", DEFAULT_AUTH_URI)),
        "token_uri": str(raw.get("token_uri", DEFAULT_TOKEN_URI)),
    }
    ruri = redirect_uri or str(raw.get("redirect_uri", "")).strip()
    if ruri:
        section["redirect_uris"] = [ruri]
    return {"installed": section}


def load_client_config(config_path: Path, redirect_uri: str | None = None) -> dict[str, Any]:
    if not config_path.is_file():
        raise NotConfiguredError(
            f"Brak pliku OAuth client: {config_path}. "
            "Wygeneruj w Google Cloud Console i zapisz do runtime/secrets/."
        )
    raw = json.loads(config_path.read_text(encoding="utf-8"))
    return _normalize_client_config(raw, redirect_uri)


def _load_saved_credentials(token_path: Path, scopes: Sequence[str]):
    from google.oauth2.credentials import Credentials

    if not token_path.is_file():
        return None
    try:
        return Credentials.from_authorized_user_file(str(token_path), list(scopes))
    except (ValueError, json.JSONDecodeError):
        return None


def _save_credentials(token_path: Path, creds) -> None:
    token_path.parent.mkdir(parents=True, exist_ok=True)
    token_path.write_text(creds.to_json(), encoding="utf-8")
    try:
        os.chmod(token_path, 0o600)
    except OSError:
        pass


def persist_credentials(token_path: Path, creds) -> None:
    """Public wrapper — persist OAuth token to disk (no values returned)."""
    _save_credentials(token_path, creds)


def _oauth_no_browser() -> bool:
    """True when OAuth must not open a system browser (Cursor IDE browser path)."""
    return os.environ.get("AIONS_OAUTH_NO_BROWSER", "").strip().lower() in (
        "1",
        "true",
        "yes",
    )


def get_credentials(
    *,
    config_path: Path,
    token_path: Path,
    scopes: Iterable[str],
    redirect_uri: str | None = None,
    port: int = 0,
    open_browser: bool = False,
):
    """Return valid Google OAuth credentials, running consent flow if needed.

    * If a token exists and is valid -> return it.
    * If expired with a refresh token -> refresh and persist.
    * Otherwise -> run the installed-app consent flow and persist token.

    Default: no system browser. Prints ``AIONS_OAUTH_AUTH_URL=...`` for
    Cursor IDE browser (``cursor-ide-browser``) navigation only.
    """
    ensure_google_libs()
    from google.auth.transport.requests import Request
    from google_auth_oauthlib.flow import InstalledAppFlow

    scope_list = list(scopes)
    creds = _load_saved_credentials(token_path, scope_list)

    if creds and creds.valid:
        return creds

    if creds and creds.expired and creds.refresh_token:
        try:
            creds.refresh(Request())
            _save_credentials(token_path, creds)
            return creds
        except Exception:  # noqa: BLE001 - fall back to full re-consent
            creds = None

    no_browser = (not open_browser) or _oauth_no_browser()

    client_config = load_client_config(config_path, redirect_uri)
    flow = InstalledAppFlow.from_client_config(client_config, scope_list)
    oauth_kwargs = {"access_type": "offline", "prompt": "consent"}
    if no_browser:
        # Do NOT call flow.authorization_url() here: that would mint a different
        # OAuth ``state`` than run_local_server(), causing MismatchingStateError
        # when the printed URL is opened while the local listener expects another.
        ruri = redirect_uri or f"http://localhost:{port}/"
        flow.redirect_uri = ruri
        print(
            "[aions-oauth] Otworz URL z linii AIONS_OAUTH_AUTH_URL "
            "(ten sam state co listener :%s):" % (port,),
            flush=True,
        )
    creds = flow.run_local_server(
        port=port,
        open_browser=False if no_browser else True,
        authorization_prompt_message="AIONS_OAUTH_AUTH_URL={url}" if no_browser else None,
        **oauth_kwargs,
    )
    _save_credentials(token_path, creds)
    return creds


def build_service(api_name: str, api_version: str, creds):
    """Thin wrapper around googleapiclient.discovery.build."""
    ensure_google_libs()
    from googleapiclient.discovery import build

    return build(api_name, api_version, credentials=creds, cache_discovery=False)


def token_exists(token_path: Path) -> bool:
    return token_path.is_file()
