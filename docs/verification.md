# Development verification

## Focused checks and the final gate

Build changed Websieve sources with `bundle exec rake build_extract_assets` before
running affected integration specs. The final `bundle exec rake` verifies assets,
runs RSpec and RuboCop. The minimum SimpleCov threshold applies to narrow runs as
well: report passing examples separately from a coverage-only exit 2.

`spec/fetch_util/browser_acquisition_spec.rb` exercises real Chromium against an
ephemeral loopback HTTP server: redirect/hydration, an open background request,
navigation failure followed by recovery, and cookie scope across pages/browsers.
Browser unit contracts additionally inject partial-page setup, dead-browser,
close and shutdown failures. These controlled fixtures complement frozen replay;
they do not emulate every live site's acquisition behavior.

Chromium is required for native checks. Set `BROWSER_PATH` explicitly when needed.
`FETCH_UTIL_ALLOW_MISSING_CHROMIUM=1` is an explicit limited-environment opt-out,
not a release-gate pass.

## Opt-in phase observation

For development diagnostics, `FetchUtil::Fetcher.new(phase_observer: callback)`
accepts a callable receiving frozen event hashes. This is a diagnostic seam;
normal `Result`, CLI and append-only request-log schemas do not gain these fields.

```ruby
events = []
fetcher = FetchUtil::Fetcher.new(phase_observer: ->(event) { events << event })
begin
  result = fetcher.fetch("https://example.com/article")
ensure
  fetcher.quit
end
```

Events identify `request_id`, credential-redacted `url`, `phase`, `edge`, and
`attempt`. Finish events also contain monotonic `duration`, `outcome`, and
`error_class`. The observed phases cover normalization, PDF probing, browser
launch/reuse, setup, navigation, stabilization, pre-extraction settling,
extraction, retry waiting, fallback work, and page cleanup. Injected browser
implementations keep their existing `with_page(url)` interface and get aggregate
browser observation instead of owned-browser internals.

Events can nest; do not sum inclusive phase times into total latency. Callbacks
run synchronously, outside the browser lifecycle mutex, and their work can affect
observed timing. Callback `StandardError`s do not alter the fetch result. The
disabled observer creates no events and reads no phase clock. Keep callbacks
lightweight; concurrent fetchers need a thread-safe sink.

This instrumentation does not create a whole-fetch deadline. `timeout:` retains
the separate existing stage budgets, and native extraction keeps its 60-second
minimum evaluation allowance. A public total timeout requires demonstrated
in-flight interruption and bounded cleanup before it can be promised.

## Frozen native replay

[The replay guide](../script/native_replay/README.md) includes a runnable manifest
example. The runner uses the actual selected `FetchUtil::Extractor#extract`,
compiled assets and vendor files. It restores immutable HTML/runtime state at the
captured final URL, blocks secondary traffic, saves the native payload before
diagnostics, and records complete before/after snapshots.

The tooling's hard per-case watchdog requires Linux `/proc`. Ruby workers and
Ferrum's independently created Chromium process groups are tracked separately;
deadline termination is followed by bounded cleanup and a check for survivors.
This process-isolated test harness is separate from the in-process product API.

The validator rejects altered artifacts, mismatched loaded sources, missing or
duplicate cases, incomplete successful rows, and stale review bindings. Its
successful exit means **evidence integrity**, not content acceptance. Preserve
errors, deadlines, acquisition failures, source-state differences and shadow-DOM
limitations in the denominator. Equal payloads do not prove source completeness.
Use the existing fidelity-contract helpers for record identity, ownership, order,
links, media and attribution; review every changed native payload against its
single immutable acquisition. `--include-html` returns extracted HTML and is not
an acquisition snapshot.

## Repeated-failure resource probe

Run the same probe in separate processes for a pinned baseline library and the
candidate. Supply an existing output directory and a Chromium executable:

```sh
bundle exec ruby script/browser_resource_probe.rb BASELINE_LIB CHROMIUM BASELINE_JSON
bundle exec ruby script/browser_resource_probe.rb CANDIDATE_LIB CHROMIUM CANDIDATE_JSON
```

The fixed protocol warms one browser, then executes three rounds of twelve real
page creations with an injected header-setup failure. Every round ends with a
successful recovery navigation. It records settled open-tab counts, process-tree
counts, a sum of process RSS, runtime/source/binary fingerprints and timings.
It refuses to overwrite an existing report. Set `TMPDIR` to the desired temporary
storage directory when running either the probe or the specs.

**Primary resource criterion:** the candidate retains no additional tabs after
any failure round and every next-request recovery succeeds. Compare all three
rounds; a monotonic baseline leak versus a candidate plateau is a resource result.
RSS sums include shared pages and are not unique physical memory. The small
controlled sample does not establish a general latency improvement.

For later latency optimization, first pilot and freeze a representative workload,
repetitions, cold/warm split, measurement overhead and meaningful-change/noise
thresholds. Retain p50/p95/max, failure and timeout counts, cleanup costs and raw
samples. Compare uninstrumented end-to-end runs under matched conditions;
diagnostic serialization time and selectively excluded timeouts cannot count as
product speedups. A timing gain is acceptable only with preserved source fidelity.
