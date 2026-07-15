# fetch_util

Reliable browser-backed fetching for Ruby.

`fetch_util` renders modern pages, inspects the live DOM, classifies page shape, and returns compact markdown plus structured metadata.

It also provides a plain-Ruby regulatory inspector for machine-readable crawl, index, and text-and-data-mining signals such as `robots.txt`, `X-Robots-Tag`, robots meta tags, and TDM reservation metadata.

It helps applications distinguish between content pages and access/interstitial states such as consent prompts, login-required pages, and challenge screens. When original content is not available, it returns a compact summary with warnings rather than pretending the page was extracted successfully.

## How It Works

The easiest way to explain `fetch_util` is in three steps:

- `Render` - load the page in Chromium, inspect the rendered DOM, and read page metadata. If a site delivers a JavaScript or WebAssembly proof-of-work challenge, the normal browser session may execute it and preserve its resulting cookies while waiting within the configured browser timeout.
- `Classify` - identify whether the page is an article, list/index, docs page, search result, or an interstitial/access-limited state.
- `Shape` - return compact markdown, normalized URLs, and warning metadata so the result is usable by agents, LLM workflows, and ordinary Ruby applications.

This is bounded native browser execution, not a custom challenge solver. If the challenge does not resolve within the bound, the result remains an explicit interstitial with warnings.

## Installation

Add the gem to your Gemfile:

```ruby
gem "fetch_util"
```

Then install dependencies:

```sh
bundle install
```

## Quick Start

```ruby
require "fetch_util"

result = FetchUtil.fetch(
  "https://example.com/article",
  timeout: 20,
  wait: 0.75,
  wait_for_idle: true,
  viewport: { width: 1366, height: 900 }
)

puts result.title
puts result.markdown
puts result.final_url
puts result.canonical_url
puts result.content_type
puts result.warnings.inspect
```

## CLI

Repo-local usage:

```sh
bundle exec exe/fetch_util fetch https://example.com/article
bundle exec exe/fetch_util fetch https://example.com/a https://example.com/b --format jsonl
bundle exec exe/fetch_util search ruby language --limit 8
bundle exec exe/fetch_util regulatory https://example.com
bundle exec exe/fetch_util regulatory https://example.com/article --sources=machine,human
```

Installed gem usage:

```sh
fetch_util fetch https://example.com/article
fetch_util search ruby language --limit 8
fetch_util regulatory https://example.com/article --sources=machine,human
```

### Search

Search uses direct HTTP requests to the supported sources in parallel. The default sources are `brave`, `bing`, and `yahoo`; explicit `--source` values may be any of `brave`, `bing`, `duckduckgo`, `google`, `ecosia`, or `yahoo`.

Search always emits one JSON object. The normal payload is exactly `{ "query": ..., "results": [...] }`. Results are interleaved by source rank, deduplicated by normalized URL, and retain every eligible result unless an explicit `--limit N` is supplied. `--limit` is applied after aggregation; there is no default result cap. Known Bing, Google, DuckDuckGo, and Yahoo result wrappers are decoded before destination validation.

Each search has one finite deadline shared by its source requests and parsing. After the initial Yahoo request, Yahoo may retry generic transport failures reported as `failed`, HTTP 429, or HTTP 5xx responses up to two times within that same deadline. Direct HTTP search challenges are diagnosed, not executed or bypassed. A source can be `ok`, `empty`, or `failed`; finite reasons include `challenge`, `failed`, `host`, `http_status`, `parse`, `query_mismatch`, `redirect`, `size`, and `timeout`.

`query_mismatch` is a candidate-bearing relevance warning, not a terminal query failure. The transport retains parsed candidates even when another source succeeds, so an uncertain lexical check cannot erase valid later-ranked evidence or force an empty query. Explicit source unions expose those retained candidates. Scoped operators and negated terms are excluded from lexical evidence, and snake_case/camelCase identifiers share token boundaries.


For agent discovery, use an explicit first-pass budget, choose only the best 1-3 direct result URLs, then fetch those destinations and inspect JSON `warnings`, `suspect`, and `content_type` when needed. Add `--verbose-search` when results are empty or suspicious, or when source health matters:

```sh
fetch_util search ruby language --limit 8
fetch_util search ruby language --limit 8 --verbose-search
fetch_util fetch https://example.com/selected --format json
```

## API

- `FetchUtil.fetch(url, **options)` returns a `FetchUtil::Result`
- `FetchUtil.fetch_many(urls, **options)` fetches multiple URLs in parallel and preserves input order
- `FetchUtil.search(query, **options)` returns direct-source aggregated search results; `limit:` is an explicit post-aggregation cap and is omitted by default
- `FetchUtil.regulatory(url, **options)` returns a source-keyed hash of allow/disallow signals for crawling, indexing, and TDM-style usage
- `FetchUtil::Fetcher.new(**options).fetch(url)` exposes the instance API directly

Useful result fields:

- `title`
- `markdown`
- `final_url`
- `canonical_url`
- `content_type` (`article`, `list`, or `search`)
- `suspect`
- `warnings`

## Common Options

- `timeout:` browser timeout in seconds; it is also the bounded observation budget for a delivered Anubis challenge
- `wait:` settle interval used by applicable post-load stabilization paths; it does not control the challenge-completion budget
- `wait_for_idle:` wait for Ferrum network idle before extraction
- `limit:` search-only explicit maximum result count; omitted by default, search returns every result in the fetched responses
- `idle_duration:` idle duration passed to Ferrum when `wait_for_idle` is enabled
- `reader_mode:` prefer Readability before heuristic fallbacks
- `viewport:` viewport hash with `:width` and `:height`
- `user_agent:` override the browser user agent
- `accept_language:` override request language headers
- `browser_path:` explicit Chromium path

## Output Shape

Structured `fetch` output is compact JSON intended for downstream agent/tool consumption. The default payload keeps the fields that are usually most useful in practice:

- `title`
- `byline`
- `site_name`
- `published_time`
- `markdown`
- `content_type`
- `suspect`
- `warnings`

The default `fetch URL` output is Markdown prefixed with standard YAML front matter. The front matter contains the same filtered fields as JSON except `markdown`; the Markdown body follows its closing `---` delimiter. URL fields are omitted from JSON, JSONL, and front matter by default. Pass `--include-urls` to include `url`, `final_url`, and `canonical_url`, and pass `--include-html` to include extracted HTML. Use `--format json` or `--format jsonl` for structured output; multiple Markdown results are emitted as separate front-matter documents.

Both CLI commands append requests to `~/.local/state/fetch_util/requests.log` by default. Override with `FETCH_UTIL_REQUEST_LOG` or `--log-path`.

## Regulatory

`regulatory` inspects machine-readable and rough human-readable signals about what a site allows or disallows for crawling, indexing, and text-and-data-mining style use.

- default source class: `machine`
- source selector syntax: `--sources=human,machine,-robotstxt`
- current machine sources:
  - `robotstxt`
  - `contentsignal`
  - `contentusagerobots`
  - `contentusageheader`
  - `trusttxt`
  - `xrobotstag`
  - `metarobots`
  - `tdmrep`
  - `tdmheaders`
  - `tdmmeta`
  - `tdmpolicy`
- current human source:
  - `human`
- structured per-request cache path: `~/.local/state/fetch_util/regulatory-cache`

The regulatory inspector now understands both Cloudflare-style `Content-Signal` robots rules and the emerging IETF AIPREF `Content-Usage` syntax in `robots.txt` and HTTP response headers.

It also understands site-wide `trust.txt` declarations using `datatrainingallowed=yes|no`, with `/trust.txt` first and `/.well-known/trust.txt` as fallback.

Origin-level queries such as `https://example.com` keep source paths in the output. Path/resource queries such as `https://example.com/article` filter to matching signals and omit the path field.

Example Ruby usage:

```ruby
require "fetch_util"

pp FetchUtil.regulatory(
  "https://example.com/article",
  sources: "machine,human"
)
```

## Behavior

- Extracts articles, list/index pages, and search pages into compact markdown.
- Uses page classification to select extraction logic appropriate to the rendered page type.
- Detects consent prompts, login-required pages, and challenge/interstitial screens and reports them with concise summaries and warning tags. A delivered JavaScript/WebAssembly proof-of-work may complete in the normal browser session within `timeout`; unresolved challenges remain explicit interstitials.
- Cleans up docs/reference pages aggressively enough for agent consumption.
- Preserves `final_url`, `canonical_url`, and warning metadata so callers can reason about redirects, mismatches, and interstitials.
- Extracts regulatory allow/disallow signals from `robots.txt`, page headers/meta tags, and TDM reservation metadata without caching raw page bodies.

## Compliance Boundaries

`fetch_util` is for rendering and summarizing publicly delivered page output. It may identify consent prompts, login-required pages, and challenge/interstitial states and return warning metadata for them. It is not intended to bypass account requirements, paywalls, verification systems, or other access controls.

Browser-profile normalization is intentionally limited to reducing obvious runtime inconsistencies that would otherwise change page behavior during extraction.

## Development

Run from `/srv/code/rbutils/fetch_util`:

```sh
bundle exec rake build_extract_assets
bundle exec rake verify_extract_assets
bundle exec rspec
bundle exec rake rubocop
bundle exec rake
```

- The shipped browser bundle is `lib/fetch_util/assets/extract.js`.
- Source JS lives under `websieve/` and is ordered by `websieve/manifest.txt`.
- `bundle exec rake build_extract_assets` rebuilds the bundle and runs `npx terser -cm` before writing `extract.js`.
- `bundle exec rake verify_extract_assets` checks that the built bundle matches the current sources.
- The default `bundle exec rake` task runs asset verification, specs, and RuboCop.
- Direct `bundle exec rspec` runs still check bundle freshness through `spec/build_extract_assets_spec.rb` and enforce the repo-wide SimpleCov minimum.

Do not hand-edit `lib/fetch_util/assets/extract.js`; edit the source files under `websieve/` and rebuild.
