"""
AIONS Context MCP Server - Entry Point
PATCHED for Windows stdio buffering issues
"""

import sys
import os
from pathlib import Path


def _expected_venv_roots() -> list[Path]:
    repo_root = Path(__file__).resolve().parents[3]
    roots = [repo_root / "venv", repo_root.parent.parent / "venv"]
    for env_key in ("AIONS_VENV_LINUX", "AIONS_VENV_WIN"):
        venv_base = os.environ.get(env_key)
        if venv_base:
            roots.append(Path(venv_base))
    return roots


def _in_project_venv() -> bool:
    """Accept prod Windows venv, Linux bin, and AIONS_DEV sibling venv layout."""
    prefix = Path(sys.prefix)
    for root in _expected_venv_roots():
        try:
            if prefix.resolve() == root.resolve():
                return True
        except OSError:
            continue

    # Fallback when prefix check is inconclusive (direct python.exe path on Windows).
    exe = Path(sys.executable)
    for root in _expected_venv_roots():
        for sub in ("Scripts", "bin"):
            marker = root / sub
            try:
                resolved_marker = marker.resolve()
                if resolved_marker.exists() and resolved_marker in exe.resolve().parents:
                    return True
            except OSError:
                continue

    return False


if not _in_project_venv():
    print(
        f"[AIONS] Refusing to start outside venv (got {sys.executable})",
        file=sys.stderr,
        flush=True,
    )
    sys.exit(1)

# WINDOWS FIX: Prevent binary mode issues
if sys.platform == "win32":
    # Don't use binary mode - it breaks JSON-RPC
    pass

# Ensure src package is importable
parent = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if parent not in sys.path:
    sys.path.insert(0, parent)


def main():
    from src.server import mcp_server, log
    import anyio

    transport = sys.argv[1] if len(sys.argv) > 1 else "stdio"
    log(f"Starting with transport: {transport} (PATCHED)")

    if transport == "stdio":
        if sys.platform == "win32":
            from src.patched_stdio import patched_stdio_server

            async def run_stdio():
                async with patched_stdio_server() as (read_stream, write_stream):
                    await mcp_server._mcp_server.run(
                        read_stream,
                        write_stream,
                        mcp_server._mcp_server.create_initialization_options(),
                    )
        else:
            from mcp.server.stdio import stdio_server

            async def run_stdio():
                async with stdio_server() as (read_stream, write_stream):
                    await mcp_server._mcp_server.run(
                        read_stream,
                        write_stream,
                        mcp_server._mcp_server.create_initialization_options(),
                    )

        anyio.run(run_stdio)
    elif transport in ("http", "streamable-http", "sse"):
        # LAN mode: same FastMCP instance, exposed over HTTP so a remote
        # Claude Code client (other machine on the network) can attach.
        # Host/port are env-driven so nothing network-specific is baked in.
        host = os.environ.get("AIONS_HTTP_HOST", "0.0.0.0")
        port = int(os.environ.get("AIONS_HTTP_PORT", "8787"))
        mcp_server.settings.host = host
        mcp_server.settings.port = port

        # The SDK's DNS-rebinding guard rejects any Host header that is not
        # localhost (HTTP 421), which blocks LAN clients. Opt out explicitly
        # with "*", or pin the exact hosts the server should answer to.
        from mcp.server.transport_security import TransportSecuritySettings

        allowed = [
            h.strip()
            for h in os.environ.get("AIONS_HTTP_ALLOWED_HOSTS", "*").split(",")
            if h.strip()
        ]
        if "*" in allowed:
            mcp_server.settings.transport_security = TransportSecuritySettings(
                enable_dns_rebinding_protection=False
            )
            log("HTTP host check: DISABLED (AIONS_HTTP_ALLOWED_HOSTS=*)")
        else:
            mcp_server.settings.transport_security = TransportSecuritySettings(
                enable_dns_rebinding_protection=True,
                allowed_hosts=allowed,
                allowed_origins=[f"http://{h}" for h in allowed],
            )
            log(f"HTTP host check: {allowed}")

        wire = "sse" if transport == "sse" else "streamable-http"
        path = (
            mcp_server.settings.sse_path
            if wire == "sse"
            else mcp_server.settings.streamable_http_path
        )
        log(f"HTTP transport={wire} listening on http://{host}:{port}{path}")
        mcp_server.run(transport=wire)
    else:
        print(f"Unsupported transport: {transport}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
