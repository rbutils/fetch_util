# Changelog

## Unreleased

## v0.2.0 - 2026-04-08

- Reuse browser process across fetches instead of spawning Chromium per URL, dramatically reducing batch fetch overhead.
- Recover partial results on parallel fetch failures instead of discarding all progress.
- Retry navigation on transient PendingConnectionsError and TimeoutError before raising.
- Log per-URL fetch duration in the request log.
- Add comprehensive Polish-language noise stripping to DOM cleanup, markdown post-processing, and sidebar heading detection.
- Remove hard caps on index link extraction so all scored candidates are returned from generic and site-profile extractors.

## v0.1.1 - 2026-04-06

- Initial standalone `rbutils` gem scaffold for reader-friendly web fetch.
- Added Ferrum-based page loading, Readability-first extraction, heuristic fallback extraction, and Turndown markdown conversion.
- Added RSpec coverage, RuboCop config, and a basic end-to-end smoke verification path.
