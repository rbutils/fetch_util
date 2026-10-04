# frozen_string_literal: true

require "digest"

module NativeReplay
  class Comparison
    REVIEW_DECISIONS = %w[reviewed_tie gain loss mixed inconclusive].freeze

    def initialize(manifest, manifest_path)
      @manifest = manifest
      @manifest_path = manifest_path
    end

    def compare(entry, baseline, candidate, review)
      errors = [baseline, candidate].any? do |row|
        row["error"] || row["deadline_exceeded"] || !row.fetch("cleanup_errors", []).empty?
      end
      same_inputs = baseline["input_sha256"] == candidate["input_sha256"] &&
                    baseline["runtime_state_sha256"] == candidate["runtime_state_sha256"] &&
                    baseline["final_url"] == candidate["final_url"] && baseline["viewport"] == candidate["viewport"]
      equal_snapshot = %w[before_snapshot after_snapshot].to_h do |key|
        baseline_hash = baseline.dig(key, "value_sha256")
        [key, !baseline_hash.nil? && baseline_hash == candidate.dig(key, "value_sha256")]
      end
      source_refs_equal = baseline["source_snapshot"] == candidate["source_snapshot"]
      baseline_payload_hash = baseline.dig("payload", "value_sha256")
      payload_equal = !baseline_payload_hash.nil? && baseline_payload_hash == candidate.dig("payload", "value_sha256")
      qualified = baseline["review_required"] || candidate["review_required"] || !source_refs_equal
      execution_tie = !errors && same_inputs && equal_snapshot.values.all? && payload_equal && !qualified
      validate_review_binding!(review, entry, baseline, candidate) if review
      {
        "case_id" => entry.fetch("case_id"), "input_equal" => same_inputs,
        "before_snapshot_equal" => equal_snapshot.fetch("before_snapshot"),
        "after_snapshot_equal" => equal_snapshot.fetch("after_snapshot"),
        "payload_equal" => payload_equal, "execution_tie" => execution_tie,
        "status" => errors ? "inconclusive" : "review_required",
        "source_review_required" => true, "review" => review&.slice("decision", "reviewer", "evidence")
      }
    end

    private

    def validate_review_binding!(review, entry, baseline, candidate)
      expected = {
        "manifest_sha256" => Digest::SHA256.file(@manifest_path).hexdigest,
        "input_sha256" => entry.dig("frozen_html", "sha256"),
        "runtime_state_sha256" => baseline.fetch("runtime_state_sha256"),
        "source_snapshot_sha256" => entry.dig("source_snapshot", "sha256"),
        "baseline_payload_sha256" => baseline.dig("payload", "value_sha256"),
        "candidate_payload_sha256" => candidate.dig("payload", "value_sha256")
      }
      %w[before_snapshot after_snapshot payload].each do |key|
        expected["baseline_#{key}_file_sha256"] = baseline.dig(key, "sha256")
        expected["candidate_#{key}_file_sha256"] = candidate.dig(key, "sha256")
      end
      expected.each { |key, value| raise "review #{key} binding mismatch" unless review.fetch(key) == value }
      return unless [baseline, candidate].any? do |row|
        row["error"] || row["deadline_exceeded"] || !row.fetch("cleanup_errors", []).empty?
      end

      raise "review cannot turn an error into success" if %w[reviewed_tie gain loss mixed].include?(review.fetch("decision"))
    end
  end
end
