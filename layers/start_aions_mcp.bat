@echo off
REM AIONS Context MCP Server — automat Python (nigdy bare python)
REM Restart Cursor MCP po zmianie: Settings -> MCP -> aions-context -> Reload

cd /d "E:\server wiedzy"
set CHROMA_PATH=E:\server wiedzy\data\chroma
set AIONS_VECTOR_BACKEND=api
set AIONS_PATH=E:\server wiedzy\aions_core
set PYTHONPATH=E:\server wiedzy;E:\server wiedzy\server;E:\server wiedzy\mcpServers\VS_CODE_MCP_CODEX
set PYTHONIOENCODING=utf-8
set PYTHONUNBUFFERED=1

REM Provenance - stamped onto every memory write. Session stays single.
if "%AIONS_AGENT%"=="" set AIONS_AGENT=claude
if "%AIONS_SURFACE%"=="" set AIONS_SURFACE=local-stdio

powershell -NoProfile -ExecutionPolicy Bypass -File "E:\server wiedzy\scripts\aions_python.ps1" "E:\server wiedzy\mcpServers\VS_CODE_MCP_CODEX\src\__main__.py" stdio
