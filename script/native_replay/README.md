# Native replay evidence tooling

This small harness replays immutable HTML through the public `FetchUtil::Extractor#extract` entrypoint. Each variant and each case runs in its own Ruby subprocess. Network requests are intercepted: only the first navigation to the pinned final URL receives a blank document, then the captured HTML and explicitly JSON-encoded runtime globals are restored. The worker records complete by-value diagnostics before extraction, saves the payload immediately, then records diagnostics again.

The hard per-case watchdog is supported on Linux with readable `/proc`. Ferrum 0.17.1 starts Chromium in a separate process group, so the parent discovers descendant process groups while the worker is live and terminates each group independently before reaping the worker. Runs refuse to overwrite an existing output or artifact directory.

## Runnable smoke example

From the repository root, set `BROWSER_PATH` to an executable Chromium binary and generate a relative-path manifest plus its input/runtime/source-snapshot artifacts:

```sh
export BROWSER_PATH="$(command -v chromium || command -v chromium-browser)"
rtk bundle exec ruby script/native_replay/example_manifest.rb tmp/native-replay-example
rtk bundle exec ruby script/native_replay.rb tmp/native-replay-example/manifest.json baseline tmp/native-replay-example/baseline.json
rtk bundle exec ruby script/native_replay.rb tmp/native-replay-example/manifest.json candidate tmp/native-replay-example/candidate.json
```

The example uses the same current source tree for both labels as a wiring smoke test; it does not represent a baseline/candidate release comparison. Its source-snapshot metadata is intentionally synthetic and is marked as a source-state difference, so output remains `review_required`. For real evidence, replace the baseline with an actual pinned gem or immutable source tree and provide acquisition-bound source snapshot/runtime metadata from the audited case.

## Identity and interpretation

Each variant uses either `identity_mode: "gem"` with a package whose extracted `lib/fetch_util` file tree matches the selected library and assets, or `identity_mode: "source_tree"` with an explicit whole-tree SHA-256. The worker verifies the selected autoload paths and version before replay and checks the extractor source again after extraction. Browser path and SHA-256 are required manifest pins and are rechecked by each worker.

The focused browser spec requires Chromium and fails if it is unavailable. Set `FETCH_UTIL_ALLOW_MISSING_CHROMIUM=1` only when an explicitly limited environment should skip that browser example.
