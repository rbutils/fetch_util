# fetch_util

Reliable browser-backed fetching for Ruby.

`fetch_util` renders modern pages, inspects the live DOM, classifies page shape, and returns compact markdown plus structured metadata.

It also provides a plain-Ruby regulatory inspector for machine-readable crawl, index, and text-and-data-mining signals such as `robots.txt`, `X-Robots-Tag`, robots meta tags, and TDM reservation metadata.

It helps applications distinguish between content pages and access/interstitial states such as consent prompts, login-required pages, and challenge screens. When original content is not available, it returns a compact summary with warnings rather than pretending the page was extracted successfully.

## How It Works

The easiest way to explain `fetch_util` is in three steps:

- `Render` - load the page in Chromium, inspect the rendered DOM, and read page metadata.
- `Classify` - identify whether the page is an article, list/index, docs page, search result, or an interstitial/access-limited state.
- `Shape` - return compact markdown, normalized URLs, and warning metadata so the result is usable by agents, LLM workflows, and ordinary Ruby applications.

In short: `fetch_util` makes the web easier to build on.

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
bundle exec exe/fetch_util search ruby language
bundle exec exe/fetch_util regulatory https://example.com
bundle exec exe/fetch_util regulatory https://example.com/article --sources=machine,human
```

Installed gem usage:

```sh
fetch_util fetch https://example.com/article
fetch_util search ruby language
fetch_util regulatory https://example.com/article --sources=machine,human
```

## API

- `FetchUtil.fetch(url, **options)` returns a `FetchUtil::Result`
- `FetchUtil.fetch_many(urls, **options)` fetches multiple URLs in parallel and preserves input order
- `FetchUtil.search(query, **options)` returns compact aggregated search results
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

- `timeout:` browser timeout in seconds
- `wait:` additional settle delay after page load
- `wait_for_idle:` wait for Ferrum network idle before extraction
- `idle_duration:` idle duration passed to Ferrum when `wait_for_idle` is enabled
- `reader_mode:` prefer Readability before heuristic fallbacks
- `viewport:` viewport hash with `:width` and `:height`
- `user_agent:` override the browser user agent
- `accept_language:` override request language headers
- `browser_path:` explicit Chromium path

## Output Shape

`fetch` defaults to compact JSON intended for downstream agent/tool consumption. The default payload keeps the fields that are usually most useful in practice:

- `url`
- `final_url`
- `canonical_url`
- `title`
- `byline`
- `site_name`
- `published_time`
- `markdown`
- `content_type`
- `suspect`
- `warnings`

Pass `--include-html` when you explicitly need extracted HTML. Multiple fetch URLs can be streamed as JSON Lines with `--format jsonl`.

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
- Detects consent prompts, login-required pages, and challenge/interstitial screens and reports them with concise summaries and warning tags.
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
- Source JS lives under `lib/fetch_util/assets/src/` and is ordered by `lib/fetch_util/assets/src/manifest.txt`.
- `bundle exec rake build_extract_assets` rebuilds the bundle and runs `npx terser -cm` before writing `extract.js`.
- `bundle exec rake verify_extract_assets` checks that the built bundle matches the current sources.
- The default `bundle exec rake` task runs asset verification, specs, and RuboCop.
- Direct `bundle exec rspec` runs still check bundle freshness through `spec/build_extract_assets_spec.rb` and enforce the repo-wide SimpleCov minimum.

Do not hand-edit `lib/fetch_util/assets/extract.js`; edit the source files under `lib/fetch_util/assets/src/` and rebuild.
