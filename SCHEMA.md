# aions-tmp-layer-catalog

Source of truth: E:\server wiedzy (dates + evolution). Not Darkstar. Not Codex. Not a venv/chroma/.env dump.

One file = one commit. After each add: read full file, run if runnable, write metadata row.

## metadata fields
- rel_path
- source_mtime
- concept_id
- session_author (claude-desktop / claude-code / cursor / codex / unknown)
- duplicate_of
- mutant_of
- runnable (yes/no/n-a)
- run_result
- notes

Ignore: venv, data/chroma, *.gguf, .env, zip, dll/exe/pdb, node_modules, __pycache__