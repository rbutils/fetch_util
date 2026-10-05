# frozen_string_literal: true

require_relative "support/native_replay_helpers"
require_relative "../script/native_replay"

RSpec.describe "native replay runner" do
  include_context "native replay runs"

  it "replays each pinned variant through Extractor#extract without artifact collisions" do
    %w[baseline candidate].each do |variant|
      run = NativeReplay::Support.read_json(@run_paths.fetch(variant))
      row = run.fetch("rows").fetch(0)
      payload = NativeReplay::Support.read_json(File.expand_path(row.dig("payload", "path"), File.dirname(@run_paths.fetch(variant))))
      expect(payload.fetch("markdown")).to include("Frozen Replay Article", "second paragraph")
      expect(row.fetch("variant").fetch("identity_mode")).to eq(variant == "baseline" ? "gem" : "source_tree")
      expect(row.fetch("ferrum").fetch("version")).not_to be_empty
      expect(row.fetch("browser").fetch("product")).not_to be_empty
      expect(row.fetch("final_url")).to eq("https://native-replay.invalid/article")
      expect(row.fetch("viewport")).to eq([1280, 900])
    end
    expect(File.dirname(@run_paths.fetch("baseline"))).to eq(File.dirname(@run_paths.fetch("candidate")))

    _, stderr, status = Open3.capture3(
      RbConfig.ruby, File.join(@project_root, "script/native_replay.rb"), @manifest_path,
      "baseline", @run_paths.fetch("baseline"), chdir: @project_root
    )
    expect(status.exitstatus).to eq(1)
    expect(stderr).to include("refusing to overwrite run output")
  end

  it "kills the actual Chromium group on deadline, validates both failed runs, then continues" do
    manifest = NativeReplay::Support.read_json(@manifest_path)
    deadline = Float(ENV.fetch("FETCH_UTIL_TEST_REPLAY_DEADLINE", "5"))
    manifest["case_deadline_seconds"] = deadline
    manifest["cases"].unshift(
      manifest.fetch("cases").first.merge(
        "case_id" => "hung-script", "frozen_html" => file_reference(File.join(@project_root, "spec/fixtures/native_replay/infinite.html"))
      )
    )
    watchdog_manifest = File.join(@temporary_root, "watchdog-manifest.json")
    NativeReplay::Support.write_json(watchdog_manifest, manifest)
    outputs = %w[baseline candidate].to_h do |variant|
      output = File.join(@temporary_root, "watchdog-#{variant}.json")
      stdout, stderr, status = Open3.capture3(
        RbConfig.ruby, File.join(@project_root, "script/native_replay.rb"), watchdog_manifest, variant, output,
        chdir: @project_root
      )
      run = NativeReplay::Support.read_json(output)
      expect(status.exitstatus).to eq(1), "#{stdout}\n#{stderr}"
      expect(run.fetch("rows").map { |row| row.fetch("case_id") }).to eq(%w[hung-script local-article])
      failed = run.fetch("rows").first
      expect(failed.fetch("deadline_exceeded")).to be(true)
      expect(failed.fetch("runtime_state_sha256")).to match(/\A[0-9a-f]{64}\z/)
      expect(failed.fetch("review_required")).to be(false)
      expect(failed.fetch("elapsed_seconds")).to be >= deadline * 0.9
      expect(run.fetch("rows").last["error"]).to be_nil
      expect([nil, "Z"]).to include(process_state(run.fetch("worker_pids").first))
      browser_group = failed.fetch("observed_process_groups").find do |group|
        File.realpath(group.fetch("executable")) == File.realpath(@browser_path)
      end
      expect(browser_group).not_to be_nil
      expect(NativeReplay::ProcessSupervisor.live_members(browser_group)).to be_empty
      expect([nil, "Z"]).to include(process_state(browser_group.fetch("pid")))
      [variant, output]
    end

    comparison = File.join(@temporary_root, "watchdog-comparison.json")
    _, stderr, status = Open3.capture3(
      RbConfig.ruby, File.join(@project_root, "script/validate_replay_evidence.rb"), watchdog_manifest,
      outputs.fetch("baseline"), outputs.fetch("candidate"), comparison, chdir: @project_root
    )
    expect(status.success?).to be(true), stderr
    result = NativeReplay::Support.read_json(comparison)
    expect(result.dig("rows", 0, "status")).to eq("inconclusive")
    expect(result.dig("rows", 1, "status")).to eq("review_required")
  end

  it "rejects package bytes that differ from the selected library tree" do
    manifest = NativeReplay::Support.read_json(@manifest_path)
    baseline_gem = NativeReplay::Support.resolve(@temporary_root, manifest.dig("variants", "baseline", "package", "path"))
    package_root = File.join(@temporary_root, "mismatched-package")
    Gem::Package.new(baseline_gem).extract_files(package_root)
    File.write(File.join(package_root, "lib/fetch_util/extractor.rb"), "\n# altered fixture\n", mode: "a")
    bad_gem = File.join(@temporary_root, "mismatched.gem")
    build_fixture_package(package_root, bad_gem)
    manifest.dig("variants", "baseline")["package"] = file_reference(bad_gem)
    bad_manifest = File.join(@temporary_root, "bad-package-manifest.json")
    NativeReplay::Support.write_json(bad_manifest, manifest)
    output = File.join(@temporary_root, "bad-package-run.json")
    stdout, stderr, status = Open3.capture3(
      RbConfig.ruby, File.join(@project_root, "script/native_replay.rb"), bad_manifest, "baseline", output,
      chdir: @project_root
    )
    row = NativeReplay::Support.read_json(output).dig("rows", 0)
    expect(status.exitstatus).to eq(1), "#{stdout}\n#{stderr}"
    expect(row.dig("error", "message")).to include("package members differ")
    expect(row.fetch("elapsed_seconds")).to be > 0
  end

  it "rejects malformed CLI, deadline/runtime values, and an unpinned browser" do
    _, stderr, status = Open3.capture3(RbConfig.ruby, File.join(@project_root, "script/native_replay.rb"), chdir: @project_root)
    expect(status.exitstatus).to eq(64)
    expect(stderr).to include("Usage:")

    manifest = NativeReplay::Support.read_json(@manifest_path)
    manifest["case_deadline_seconds"] = 0
    bad_path = File.join(@temporary_root, "bad-manifest.json")
    NativeReplay::Support.write_json(bad_path, manifest)
    _, stderr, status = Open3.capture3(
      RbConfig.ruby, File.join(@project_root, "script/native_replay.rb"), bad_path, "candidate",
      File.join(@temporary_root, "bad-run.json"), chdir: @project_root
    )
    expect(status.exitstatus).to eq(65)
    expect(stderr).to include("case deadline must be finite and positive")

    manifest = NativeReplay::Support.read_json(@manifest_path)
    invalid_runtime = File.join(@temporary_root, "invalid-runtime.json")
    NativeReplay::Support.write_json(invalid_runtime, [])
    manifest.fetch("cases").first["runtime_state"] = file_reference(invalid_runtime)
    NativeReplay::Support.write_json(bad_path, manifest)
    _, stderr, status = Open3.capture3(
      RbConfig.ruby, File.join(@project_root, "script/native_replay.rb"), bad_path, "candidate",
      File.join(@temporary_root, "bad-runtime-run.json"), chdir: @project_root
    )
    expect(status.exitstatus).to eq(65)
    expect(stderr).to include("runtime state must be an object")

    manifest = NativeReplay::Support.read_json(@manifest_path)
    manifest.fetch("browser")["sha256"] = "0" * 64
    NativeReplay::Support.write_json(bad_path, manifest)
    _, stderr, status = Open3.capture3(
      RbConfig.ruby, File.join(@project_root, "script/native_replay.rb"), bad_path, "candidate",
      File.join(@temporary_root, "bad-browser-run.json"), chdir: @project_root
    )
    expect(status.exitstatus).to eq(65)
    expect(stderr).to include("browser SHA-256 mismatch")
  end
end
