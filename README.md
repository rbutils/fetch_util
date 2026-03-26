# fetch_util

AI for fetching.

`fetch_util` is an intelligent web-fetch engine for Ruby that turns messy web pages into clean, usable content. It renders modern pages, inspects the live DOM, chooses an extraction strategy, and returns compact markdown plus structured metadata.

The `AI` here is practical and specific: `fetch_util` applies content intelligence to the fetch step. It recognizes articles, lists, docs pages, search results, login walls, consent screens, and challenge pages, then adapts automatically so applications get useful output instead of raw page noise.

## AI for Fetching

The easiest way to explain `fetch_util` is in three steps:

- `Perceive` - render the real page, inspect the DOM, read metadata, and detect patterns that do not show up in raw HTML alone.
- `Decide` - determine whether the page is an article, list/index, docs page, search page, consent wall, login wall, challenge page, or some other shell, then choose the best extraction path.
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
```

Installed gem usage:

```sh
fetch_util fetch https://example.com/article
fetch_util search ruby language
```

## API

- `FetchUtil.fetch(url, **options)` returns a `FetchUtil::Result`
- `FetchUtil.fetch_many(urls, **options)` fetches multiple URLs in parallel and preserves input order
- `FetchUtil.search(query, **options)` returns compact aggregated search results
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

## Behavior

- Extracts articles, list/index pages, and search pages into compact markdown.
- Applies narrow-AI style classification and strategy selection instead of treating every page as the same generic document.
- Normalizes many consent, login, and challenge shells into short summaries with warning tags.
- Cleans up docs/reference pages aggressively enough for agent consumption.
- Preserves `final_url`, `canonical_url`, and warning metadata so callers can reason about redirects, mismatches, and interstitials.

Headlessness mitigation is intentionally limited to basic fingerprint reduction. The project does not aim to defeat hardened anti-bot systems.

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
