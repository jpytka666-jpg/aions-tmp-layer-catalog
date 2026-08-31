# CBMS KR Index

This directory contains a lightweight retrieval index derived from the KR_ROOT repository at D:/models/Mistral-7B-AIONS-REPACK/chunks.

Artifacts:
- kr_postings.bin: JSON-encoded postings map (term -> top doc scores).
- kr_meta.json: document payloads and digests.
- README.md: this file.

The index uses BM25-lite scoring and retains up to 12 documents per term. Evidence snippets are capped at 1500 characters during runtime composition.
