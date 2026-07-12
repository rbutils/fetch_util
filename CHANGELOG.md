# Changelog

## Unreleased

## v0.5.0 - 2026-07-13

### Added

- Add direct, concurrent HTTP search transport for Brave, Bing, DuckDuckGo, Google, and Ecosia with finite source diagnostics, wrapper decoding, and shared deadline enforcement.

### Fixed

- Prevent generic-list ranking scores, malformed engine wrappers, non-SERP engine pages, challenges, and query-mismatched source responses from appearing as valid search results.

### Changed

- Change default search sources from DuckDuckGo and Google to Brave and Bing. Search now returns typed direct-source results instead of reparsing browser Markdown.
- Apply `limit:` only after aggregation and deduplication, with no default result cap. `verbose: true` adds ordered source diagnostics and result provenance.
- Remove browser-only search options such as `fetcher:`, `concurrency:`, waits, and reader mode from `FetchUtil.search` and `FetchUtil::Searcher`; use `sources:`, `limit:`, `timeout:`, and `verbose:` for direct search.

### Performance

- Remove Chromium startup and generic browser stabilization from the normal search path.

## v0.4.0 - 2026-07-11

### Added

- Add dedicated result types and structured fields for social posts, threads, feeds, and profiles; products; properties; lodging; jobs; events; recipes; podcasts; sports; medical content; government notices; and press releases.
- Add explicit language output, direct PDF results, YAML front matter for the default Markdown format, and opt-in URL fields through `--include-urls`.
- Add public extraction support for Mastodon, Bluesky, Telegram, Hacker News, GitHub discussions, Reddit, Discourse, Stack Exchange, Stack Overflow, Wykop, and other social/community page shapes.
- Add deterministic content-fidelity contracts covering section coverage, DOM order, card-local context, canonical deduplication, chrome leakage, and focal article structure.

### Fixed

- Preserve complete, DOM-ordered visible content across portal sections, feeds, search results, documentation indexes, social threads, structured content, financial links, glossary entries, large sports tables, and search snippets without silent presentation caps.
- Improve generic homepage, article, list, documentation, warning, and content-ownership arbitration across multilingual news, reference, commerce, social, legal, medical, and JavaScript-heavy pages.
- Improve WP and Onet homepage fidelity, Wykop home/tag feeds, Ringier article bodies, MDN reference hierarchy, Mastodon and Telegram live routes, and Polish portal warning semantics.
- Prevent publisher-specific Ringier extraction from mutating the shared media engine; separate WP and Onet homepage ownership while retaining neutral shared list primitives.
- Normalize IRI input, strengthen browser navigation resilience, constrain false financial appendices, and reduce mismatch, multi-topic, homepage-index, access-wall, and truncation false positives.

### Changed

- Move editable JavaScript and its ordered manifest to root `websieve/`; generated runtime assets remain packaged under `lib/fetch_util/assets/`.
- Reorganize JavaScript by systems, content types, profiles, classifiers, and extraction concerns; split oversized modules and normalize manifest dependency order and registration ownership.
- Change default fetch rendering to YAML-front-matter-prefixed Markdown. JSON, JSONL, and front matter now share one filtered field contract, with URL fields hidden unless requested.
- Sanitize unreleased fixtures and assertions with synthetic content while preserving selectors, schemas, structure, scripts, counts, order, and regression intent.

### Performance

- Reduce browser stabilization and consent-handling latency while preserving retry behavior for transient navigation and pending-connection failures.
- Remove redundant fixture resets and consolidate shared extraction, metadata, address, description, cleanup, and registration helpers.

## v0.3.2 - 2026-07-09

### Added

- Add dedicated extraction coverage for public Chosun, Xinhua weekly indexes, O Pais, Avesta, Walla, Jang, 20minutos, NHK, Protothema, Lenta, and YNA article/list pages.
- Add a Hurriyet homepage regression fixture to protect non-English homepage extraction.

### Fixed

- Normalize non-ASCII IRI input URLs before browser navigation.
- Harden fetch resilience by retrying transient navigation and pending-connection failures.
- Improve generic article extraction and MediaWiki/Wikipedia handling while preserving localized truncation and warning semantics.
- Reduce false positives for homepage index mismatches, stale content, script-language mismatches, short news CTA multi-topic pages, transliterated slugs, and long non-English articles.
- Preserve article content through video metadata, France24 DOM stabilization, and short-description-root edge cases.

### Changed

- Consolidate list extraction helpers and reduce duplicated extraction/profile code across generic, WordPress, simple-profile, and job-list paths.
- Refine generic extraction and non-Latin spec style without changing the public API.

### Performance

- Speed up browser stabilization and Ruby fetch runtime.
- Share browser pools, avoid unnecessary asset rebuilds in specs, optimize asset checks/readable text, and streamline extractor integration specs.

## v0.3.1 - 2026-07-06

- Improve primary content-root selection across long documents, article pages, docs, Drupal and institutional pages, publisher abstracts, Substack, Discourse, Trope Wiki, PLOS, Elsevier, ACS, HighWire, and legal/statute pages so body content is preferred over chrome, teasers, and related rails.
- Expand list, index, card, and hub classification for section feeds, job results, government and legal portals, legal contents/search pages, institutional case lists, AEM/Drupal/custom CMS cards, commerce product grids, Statuspage boards, standards records, package registries, and public Mastodon timelines.
- Add or improve extraction for structured reference and scholarly records including arXiv abstracts, dictionary definitions, GitLab repository READMEs, Cornell Wex articles, legal conventions, US Code provisions, OEIS/RCSB/NIST records, NCBI/Ensembl gene records, IUCN species assessments, IEEE Xplore abstracts, and official statute text.
- Reduce false positive warnings for stale content, reposts, consent/paywall walls, Polish language mismatches, docs pages, subscriptions, scientific/legal/institutional pages, legal cases, DOI/publisher redirects, same-organization redirects, statutes, and treaty indexes.
- Improve error and interstitial handling for auth redirects, PDFs, dominant unavailable pages, soft errors, press-hold challenges, dead DOI redirects, legal soft 404s, publisher unavailable pages, not-found pages, nav-only records, short landing heroes, and privacy fragments.
- Clean markdown artifacts from malformed card grids, legal citations, table-based content, nested tables, treaty collections, article promo widgets, reference rails, undefined image text, and repeated list card details.
- Ensure browser extraction assets are rebuilt during verify, spec, build, and release paths; guard extraction asset manifest completeness.
- Consolidate shared extraction helpers for CMS component hubs, scholarly articles, platform profiles, repository READMEs, card lists, not-found/interstitial detection, legal text, table markdown, cleanup vocabulary, result field mapping, profile HTML/articles, Chrome stripping, platform signatures, list item results, and spec assertions.
- Ignore local Serena project metadata from Git.

## v0.3.0 - 2026-06-21

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
- Change `fetch` default output format from JSON to pure markdown so agents get clean readable content without parsing JSON. Use `--format json` for structured output with metadata, warnings, and content_type fields.

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
