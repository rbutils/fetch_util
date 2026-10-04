# Development verification

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
