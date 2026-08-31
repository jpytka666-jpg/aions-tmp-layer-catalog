"""Gmail integration — read AND write (list/get/send).

OAuth client config + token live in ``runtime/secrets/`` (gitignored). No secrets
in this file. First run of :func:`start_oauth_flow` opens a browser consent and
persists a refresh token; later calls refresh automatically.

Config file : ``runtime/secrets/gmail_oauth.json``
Token file  : ``runtime/secrets/gmail_token.json``
"""

from __future__ import annotations

import base64
import sys
from email.mime.text import MIMEText
from pathlib import Path
from typing import Any

# Support running both as a package module and as a bare script. Load the shared
# helper by file path (not via sys.path) so we never expose the sibling
# ``calendar`` subpackage as a top-level module that would shadow stdlib.
if __package__:
    from .. import google_oauth as _g
else:  # pragma: no cover - CLI convenience
    import importlib.util as _ilu

    _g_path = Path(__file__).resolve().parents[1] / "google_oauth.py"
    _g_spec = _ilu.spec_from_file_location("aions_google_oauth", _g_path)
    _g = _ilu.module_from_spec(_g_spec)
    _g_spec.loader.exec_module(_g)  # type: ignore[union-attr]

NotConfiguredError = _g.NotConfiguredError
DependencyMissingError = _g.DependencyMissingError

PROVIDER = "gmail"
# modify = read + label/modify; send = send mail. Together: full read+write.
SCOPES = (
    "https://www.googleapis.com/auth/gmail.modify",
    "https://www.googleapis.com/auth/gmail.send",
)
DEFAULT_REDIRECT_URI = "http://localhost:8080/"
_REDIRECT_PORT = 8080


def oauth_config_path() -> Path:
    return _g.secrets_dir() / f"{PROVIDER}_oauth.json"


def token_path() -> Path:
    return _g.secrets_dir() / f"{PROVIDER}_token.json"


def get_credentials(*, open_browser: bool = True):
    return _g.get_credentials(
        config_path=oauth_config_path(),
        token_path=token_path(),
        scopes=SCOPES,
        redirect_uri=DEFAULT_REDIRECT_URI,
        port=_REDIRECT_PORT,
        open_browser=open_browser,
    )


def get_service():
    return _g.build_service("gmail", "v1", get_credentials())


def start_oauth_flow() -> Path:
    """Run consent (if needed) and persist the token. Returns token path."""
    get_credentials(open_browser=True)
    return token_path()


def _header(headers: list[dict[str, str]], name: str) -> str:
    lname = name.lower()
    for h in headers:
        if h.get("name", "").lower() == lname:
            return h.get("value", "")
    return ""


def list_messages(*, max_results: int = 10, query: str = "") -> list[dict[str, Any]]:
    """List recent messages with subject/from/date metadata (read)."""
    service = get_service()
    resp = (
        service.users()
        .messages()
        .list(userId="me", maxResults=max_results, q=query or None)
        .execute()
    )
    out: list[dict[str, Any]] = []
    for ref in resp.get("messages", []):
        msg = (
            service.users()
            .messages()
            .get(
                userId="me",
                id=ref["id"],
                format="metadata",
                metadataHeaders=["Subject", "From", "Date"],
            )
            .execute()
        )
        headers = msg.get("payload", {}).get("headers", [])
        out.append(
            {
                "id": msg.get("id"),
                "threadId": msg.get("threadId"),
                "subject": _header(headers, "Subject"),
                "from": _header(headers, "From"),
                "date": _header(headers, "Date"),
                "snippet": msg.get("snippet", ""),
            }
        )
    return out


def _decode_part(data: str) -> str:
    return base64.urlsafe_b64decode(data.encode("utf-8")).decode("utf-8", "replace")


def get_message(message_id: str, *, fmt: str = "full") -> dict[str, Any]:
    """Fetch a single message. Returns headers + best-effort plain-text body."""
    service = get_service()
    msg = (
        service.users()
        .messages()
        .get(userId="me", id=message_id, format=fmt)
        .execute()
    )
    payload = msg.get("payload", {})
    headers = payload.get("headers", [])
    body_text = ""
    stack = [payload]
    while stack:
        part = stack.pop()
        mime = part.get("mimeType", "")
        data = part.get("body", {}).get("data")
        if mime == "text/plain" and data:
            body_text = _decode_part(data)
            break
        stack.extend(part.get("parts", []) or [])
    return {
        "id": msg.get("id"),
        "threadId": msg.get("threadId"),
        "labelIds": msg.get("labelIds", []),
        "subject": _header(headers, "Subject"),
        "from": _header(headers, "From"),
        "to": _header(headers, "To"),
        "date": _header(headers, "Date"),
        "snippet": msg.get("snippet", ""),
        "body_text": body_text,
    }


def send_message(
    *,
    to: str,
    subject: str,
    body_text: str,
    cc: str | None = None,
    bcc: str | None = None,
) -> dict[str, Any]:
    """Send a plaintext email (write). Returns {id, threadId, labelIds}."""
    service = get_service()
    mime = MIMEText(body_text, _charset="utf-8")
    mime["To"] = to
    mime["Subject"] = subject
    if cc:
        mime["Cc"] = cc
    if bcc:
        mime["Bcc"] = bcc
    raw = base64.urlsafe_b64encode(mime.as_bytes()).decode("utf-8")
    sent = (
        service.users()
        .messages()
        .send(userId="me", body={"raw": raw})
        .execute()
    )
    return {
        "id": sent.get("id"),
        "threadId": sent.get("threadId"),
        "labelIds": sent.get("labelIds", []),
    }


def _cli() -> None:
    try:
        path = start_oauth_flow()
        print(f"[gmail] Token OK -> {path}")
        msgs = list_messages(max_results=3)
        print(f"[gmail] Ostatnie {len(msgs)} wiadomosci:")
        for m in msgs:
            print(f"  - {m['date']} | {m['from']} | {m['subject']}")
    except (NotConfiguredError, DependencyMissingError) as exc:
        print(f"[gmail] {exc}")


if __name__ == "__main__":
    _cli()
