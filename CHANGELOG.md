# Changelog

## Unreleased

## v0.2.1 - 2026-04-09

- Detect liveblog and briefing/digest content formats via structured data, DOM heuristics, and multilingual title patterns; expose `content_format` field and `multi_topic_page` warning.
- Detect paywall signals via structured data, meta tags, DOM elements, and multilingual text patterns; expose `paywall_state` field and `paywall_partial_content` warning.
- Add diacritics-aware slug matching to reduce false `url_content_mismatch` warnings for Polish, Turkish, Latvian, and other accented-language URLs.
- Add ratio-based truncation detection and `content_completeness_ratio` field for better short-extraction diagnostics.
- Expand consent button patterns for Finnish, Lithuanian, Macedonian, and Romanian; support trailing clause variants.
- Strip related-content sections by multilingual heading detection across 20+ European languages.
- Expand language stopword coverage from 7 to 22 languages for more accurate content-language heuristics.
- Remove Gemfile.lock from version control.

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
