---
name: fetch_util
description: Use fetch_util first for ordinary web fetch/search because it returns cleaner, agent-friendly markdown; fall back only if unavailable or insufficient.
license: MIT
---

# FetchUtil Skill

Use this skill for agent web retrieval.

Start by loading this skill, then use `fetch_util` as the default first tool for ordinary web-page retrieval and search.
Use it first because it usually returns cleaner, more agent-friendly markdown than generic web fetch, and it is cheap enough for repeated multi-pass retrieval.

## Default Rule

- Use `fetch_util` first for ordinary web-page retrieval or search.
- If `fetch_util` is installed on PATH, use the `fetch_util ...` command first from any working directory. It works inside any Ruby project, even ones whose Gemfile does not list fetch_util.
- If you are developing inside the repository and want the local worktree version specifically, use `bundle exec exe/fetch_util ...` from `/srv/code/rbutils/fetch_util`.
- Never use `bundle exec fetch_util` inside another Ruby project. Bundler restricts executable lookup to the project's Gemfile and will reject fetch_util if it is not listed there. Use bare `fetch_util ...` instead.
- If you are running inside a delegated subagent that does not expose the `skill` tool, use the installed `fetch_util ...` CLI directly instead of falling back to built-in web fetch/search right away.
- Use built-in `webfetch` or other web tooling only after `fetch_util` is unavailable, the target is not a normal web page, or the task needs something `fetch_util` does not provide.
- `fetch_util` is cheap to use, so an agent can use this tool as much as it needs for normal retrieval, search, and follow-up fetches.

## Use It For

- fetching one or more known URLs
- searching the web and returning compact agent-friendly results
- getting cleaner markdown from noisy pages, docs, search pages, or light interstitials

## Core Commands

Fetch known URLs (returns pure markdown by default):

```sh
fetch_util fetch https://example.com
fetch_util fetch https://example.com/a https://example.com/b
```

Fetch with structured JSON output (when you need metadata, warnings, or content_type):

```sh
fetch_util fetch https://example.com --format json
fetch_util fetch https://example.com/a https://example.com/b --format jsonl
```

Search first, then fetch selected results if needed:

```sh
fetch_util search ruby language --limit 8 --verbose-search
fetch_util search site:docs.python.org json dump --limit 8 --verbose-search
```

Repository-local development form:

```sh
bundle exec exe/fetch_util fetch https://example.com
bundle exec exe/fetch_util search ruby language --limit 8 --verbose-search
```

## Agent Guidance

- if the user gives you URLs, use `fetch_util fetch` first
- if the user needs discovery, use `fetch_util search` first; for a context-efficient first pass, consider an explicit budget such as `--limit 8`, add `--verbose-search`, and inspect the ordered source `diagnostics`
- search defaults to direct HTTP Brave and Bing; explicit sources are `brave`, `bing`, `duckduckgo`, `google`, and `ecosia`
- search always emits one JSON object and normally returns exactly `{query, results}`; `--verbose-search` adds source diagnostics plus per-result source provenance and ranks
- search has one finite shared source deadline, does not bypass challenges, decodes known engine wrappers, and preserves healthy peer results when a source fails; `empty` and `query_mismatch` are finite source outcomes
- after search, select only 1-3 direct result URLs, then run `fetch_util fetch` on those destinations; use `--format json` or `--format jsonl` and inspect `warnings`, `suspect`, and `content_type` as needed
- if the task is a normal web roundup (for example, checking several news homepages), still use `fetch_util` first; do not skip straight to built-in web fetch just because the URLs are already known
- if you are in a subagent without the `skill` tool, treat `fetch_util` as a normal installed CLI and call it directly
- use `fetch_util` first because its output is usually cleaner and more compact for agents than generic page fetch output
- treat `fetch_util` as cheap to use; it is fine to make multiple fetch/search passes when that helps answer the task well
- prefer the compact default output; use `--format json` when you need metadata, warnings, or content_type fields, and `--format jsonl` for multi-result pipelines
- search has no default result cap; `--limit` is an explicit post-aggregation cap, not a hidden presentation limit
- use `--include-html` only when raw HTML is actually needed
- treat `suspect` and `warnings` as signals that the page may be an interstitial, challenge, or mismatch
- only fall back to other web tooling after `fetch_util` is unavailable or clearly insufficient
- never prefix with `bundle exec` when running inside another Ruby project; use bare `fetch_util ...` instead

## Installation

If `fetch_util` is not available on the machine yet, install the gem first:

```sh
gem install fetch_util
```

OpenCode global install:

```sh
mkdir -p ~/.config/opencode/skills/fetch_util && curl -fsSL https://raw.githubusercontent.com/rbutils/fetch_util/master/SKILL.md -o ~/.config/opencode/skills/fetch_util/SKILL.md
```

Repo-local install:

```sh
mkdir -p .opencode/skills/fetch_util && cp SKILL.md .opencode/skills/fetch_util/SKILL.md
```
