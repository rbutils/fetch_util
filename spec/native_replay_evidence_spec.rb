# frozen_string_literal: true

require_relative "support/native_replay_helpers"
require_relative "../script/native_replay/comparison"

RSpec.describe "native replay evidence validation" do
  include_context "native replay runs"

  it "keeps successful comparisons review-required and does not tie unequal payloads" do
    output = File.join(@temporary_root, "comparison.json")
    _, stderr, status = Open3.capture3(
      RbConfig.ruby, File.join(@project_root, "script/validate_replay_evidence.rb"), @manifest_path,
      @run_paths.fetch("baseline"), @run_paths.fetch("candidate"), output, chdir: @project_root
    )
    expect(status.success?).to be(true), stderr
    result = NativeReplay::Support.read_json(output)
    expect(result.dig("rows", 0, "payload_equal")).to be(true)
    expect([true, false]).to include(result.dig("rows", 0, "execution_tie"))
    expect(result.dig("rows", 0, "status")).to eq("review_required")
    expect(result.fetch("semantic_scope")).to include("no semantic wins")

    baseline = {
      "input_sha256" => "input", "runtime_state_sha256" => "runtime", "final_url" => "url", "viewport" => [1, 1],
      "review_required" => false, "source_snapshot" => { "sha256" => "source" },
      "before_snapshot" => { "value_sha256" => "before" }, "after_snapshot" => { "value_sha256" => "after" },
      "payload" => { "value_sha256" => "payload-a" }
    }
    candidate = baseline.merge("payload" => { "value_sha256" => "payload-b" })
    comparison = NativeReplay::Comparison.new({}, "unused").compare({ "case_id" => "unit" }, baseline, candidate, nil)
    expect(comparison.fetch("payload_equal")).to be(false)
    expect(comparison.fetch("execution_tie")).to be(false)
  end

  it "rejects stale review bindings to payload, source snapshots, and input" do
    baseline = NativeReplay::Support.read_json(@run_paths.fetch("baseline")).dig("rows", 0)
    candidate = NativeReplay::Support.read_json(@run_paths.fetch("candidate")).dig("rows", 0)
    cases = {
      "baseline_payload_file_sha256" => "review baseline_payload_file_sha256 binding mismatch",
      "baseline_before_snapshot_file_sha256" => "review baseline_before_snapshot_file_sha256 binding mismatch",
      "source_snapshot_sha256" => "review source_snapshot_sha256 binding mismatch",
      "input_sha256" => "review input_sha256 binding mismatch"
    }
    cases.each do |field, message|
      review = review_row(baseline, candidate)
      review[field] = "0" * 64
      review_path = File.join(@temporary_root, "stale-#{field}.json")
      write_review(review_path, review)
      _, stderr, status = Open3.capture3(
        RbConfig.ruby, File.join(@project_root, "script/validate_replay_evidence.rb"), @manifest_path,
        @run_paths.fetch("baseline"), @run_paths.fetch("candidate"), File.join(@temporary_root, "bad-review.json"),
        review_path, chdir: @project_root
      )
      expect(status.success?).to be(false)
      expect(stderr).to include(message)
    end
  end

  it "rejects duplicate/missing rows and edited output artifacts" do
    run = NativeReplay::Support.read_json(@run_paths.fetch("candidate"))
    run["rows"] = [run.fetch("rows").first, run.fetch("rows").first]
    run["case_ids"] = %w[local-article local-article]
    duplicate = File.join(@temporary_root, "duplicate.json")
    NativeReplay::Support.write_json(duplicate, run)
    _, stderr, status = Open3.capture3(
      RbConfig.ruby, File.join(@project_root, "script/validate_replay_evidence.rb"), @manifest_path,
      @run_paths.fetch("baseline"), duplicate, File.join(@temporary_root, "bad-ids.json"), chdir: @project_root
    )
    expect(status.success?).to be(false)
    expect(stderr).to include("duplicate, missing, or unexpected IDs")

    row = NativeReplay::Support.read_json(@run_paths.fetch("candidate")).dig("rows", 0)
    payload_path = File.expand_path(row.dig("payload", "path"), File.dirname(@run_paths.fetch("candidate")))
    original = File.binread(payload_path)
    payload = JSON.parse(original)
    payload["markdown"] = "edited after capture"
    NativeReplay::Support.write_json(payload_path, payload)
    _, stderr, status = Open3.capture3(
      RbConfig.ruby, File.join(@project_root, "script/validate_replay_evidence.rb"), @manifest_path,
      @run_paths.fetch("baseline"), @run_paths.fetch("candidate"), File.join(@temporary_root, "edited.json"),
      chdir: @project_root
    )
    expect(status.success?).to be(false)
    expect(stderr).to include("candidate payload file fingerprint mismatch")
  ensure
    File.binwrite(payload_path, original) if payload_path && original
  end

  it "rejects error-as-tie, missing snapshots, and malformed deadline tuples without leaving mutations" do
    candidate_path = @run_paths.fetch("candidate")
    baseline = NativeReplay::Support.read_json(@run_paths.fetch("baseline")).dig("rows", 0)
    run = NativeReplay::Support.read_json(candidate_path)
    row = run.dig("rows", 0)
    row_path = File.expand_path(row.fetch("row_path"), File.dirname(candidate_path))
    original_row = File.binread(row_path)
    review_path = File.join(@temporary_root, "error-review.json")
    write_review(review_path, review_row(baseline, row))
    row["error"] = { "class" => "FixtureFailure", "message" => "simulated", "backtrace" => [] }
    row["deadline_exceeded"] = false
    NativeReplay::Support.write_json(row_path, row)
    error_run = File.join(@temporary_root, "error-run.json")
    NativeReplay::Support.write_json(error_run, run)
    _, stderr, status = Open3.capture3(
      RbConfig.ruby, File.join(@project_root, "script/validate_replay_evidence.rb"), @manifest_path,
      @run_paths.fetch("baseline"), error_run, File.join(@temporary_root, "error-tie.json"), review_path,
      chdir: @project_root
    )
    expect(status.success?).to be(false)
    expect(stderr).to include("review cannot turn an error into success")

    File.binwrite(row_path, original_row)
    incomplete_run = NativeReplay::Support.read_json(candidate_path)
    incomplete_row = incomplete_run.dig("rows", 0)
    incomplete_row.delete("after_snapshot")
    NativeReplay::Support.write_json(row_path, incomplete_row)
    incomplete_path = File.join(@temporary_root, "incomplete-run.json")
    NativeReplay::Support.write_json(incomplete_path, incomplete_run)
    _, stderr, status = Open3.capture3(
      RbConfig.ruby, File.join(@project_root, "script/validate_replay_evidence.rb"), @manifest_path,
      @run_paths.fetch("baseline"), incomplete_path, File.join(@temporary_root, "incomplete-output.json"),
      chdir: @project_root
    )
    expect(status.success?).to be(false)
    expect(stderr).to include("successful row requires payload and both snapshots")

    File.binwrite(row_path, original_row)
    malformed_run = NativeReplay::Support.read_json(candidate_path)
    malformed_row = malformed_run.dig("rows", 0)
    malformed_row["error"] = { "class" => "FixtureFailure", "message" => "bad tuple", "backtrace" => [] }
    malformed_row["deadline_exceeded"] = true
    malformed_path = File.join(@temporary_root, "malformed-deadline-run.json")
    NativeReplay::Support.write_json(malformed_path, malformed_run)
    _, stderr, status = Open3.capture3(
      RbConfig.ruby, File.join(@project_root, "script/validate_replay_evidence.rb"), @manifest_path,
      @run_paths.fetch("baseline"), malformed_path, File.join(@temporary_root, "malformed-deadline-output.json"),
      chdir: @project_root
    )
    expect(status.success?).to be(false)
    expect(stderr).to include("deadline error must be Timeout::Error")
  ensure
    File.binwrite(row_path, original_row) if row_path && original_row
  end
end
