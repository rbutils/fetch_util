# Development verification

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
