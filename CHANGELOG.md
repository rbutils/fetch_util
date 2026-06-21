# Changelog

## Unreleased

- Add generic portal, marketplace, and booking homepage root selection so lead-story lists are extracted from shell pages the previous docs, repo, and community dispatchers missed; already-handled homepages are unaffected.
- Improve dictionary, glossary, and citation definition root extraction with a reusable definition-reference metadata scorer, `dl`/`dt`/`dd` and `itemprop=description` container boosts, and repeated-sense dedupe that strips numbering, term prefixes, and citation tails.
- Surface commerce product card details from JSON-LD `Product`, `Offer`, `AggregateRating`, and `ItemList` structures with conservative DOM fallback via itemprop, price and rating classes, aria-label, and visible stock text; non-commerce lists are unchanged.
- Recover GitHub README content across multiple selector variants (`article.markdown-body`, `[data-testid='readme-content']`, aria containers) with a compact project-summary fallback when no README is present; GitLab behavior is unchanged.
- Enrich Google-style consent summaries with visible headings, consent paragraphs, bullets, and option/control labels; prefer a visible heading over the page title so control labels are not pushed past the highlight cutoff. No bypass or dismissal behavior is added.
- Deepen Antora landing card detail extraction with card-scoped boundaries and preserved relative hrefs; add nested STLDocs schema property groups and method-local parameter/response field bullets with shared docs-scoped text helpers.
- Fix pre-existing RuboCop offenses: split the 724-character multilingual homepage-phrase regex in `fetcher.rb` into a `Regexp.new` with string continuations, and correct `Style/RaiseArgs` in `browser_spec.rb`.
- Remove ~1,337 lines of manifest-ordered dead code where later source files silently overrode earlier ones: collapse `dom_base.js` (9 functions overridden by `dom_cleanup.js`), `lists.js` (18 functions overridden by `list_extraction.js`), and `generic_docs.js` (15 functions overridden by `generic_docs_frameworks.js`); remove `generic_docs.js` from the asset manifest.
- Restore missing forum/thread selectors in the live `list_extraction.js` that were present only in the dead `lists.js` override: `[class*='thread']`, `[class*='topic-list']`, `.structItem`, `.discussionListItem`.
- Merge mintlify docs selectors from the dead `generic_docs.js` into the live `generic_docs_frameworks.js`: table-of-contents, context menu, eyebrow, ctrl keybindings, ask-an-ai cleanup, and pagination selectors.
- Extract and adopt shared JS helpers: `listContentResult` and `bodyInnerText` in `core/metadata.js`; adopt existing `docsHostSignature` (7 sites) and `cleanDocsHeadings` (6 sites); refactor `listChromeOrNavigationNode` and `parseInstagramStats`.
- Extract a shared `COOKIE_CONSENT_KEYWORDS` multilingual constant in `challenges.js` consumed by `consentWallDominates`, `consentLikeInterstitial`, and `consentWallPage`; remove dead `challengeNoiseText`.
- Extract shared Ruby helpers: `FetchUtil.strip_www_host` (4 sites), `Regulatory#fetch_record` (4 record methods), and `Regulatory#signal_sort_prefix` (2 sort methods); `tdm_rep.rb` now calls existing `extract_tdm_value_signals`.
- Extract shared spec support (`fetcher_spec_helpers.rb`, `fixture_html.rb`) and split large spec files: 4 Nordic/Baltic consent examples from `content_quality_spec.rb` into `consent_language_walls_spec.rb`, 6 Reddit/Behance examples from `consent_and_social_walls_spec.rb` into `social_platform_walls_spec.rb`.
- Remove `require "bundler/setup"` from the installed executable so `fetch_util` works from inside any Ruby project, even ones whose Gemfile does not list fetch_util. Bundler is still activated by `bundle exec` for repo-local development.

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
