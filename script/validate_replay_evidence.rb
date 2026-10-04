# frozen_string_literal: true

require_relative "native_replay/evidence_validator"

if $PROGRAM_NAME == __FILE__
  unless (4..5).cover?(ARGV.length)
    warn "Usage: ruby script/validate_replay_evidence.rb MANIFEST.json BASELINE_RUN.json CANDIDATE_RUN.json OUTPUT.json [REVIEWS.json]"
    exit 64
  end

  begin
    exit NativeReplay::EvidenceValidator.new(*ARGV).run
  rescue StandardError => e
    warn "evidence validation failed: #{e.class}: #{e.message}"
    exit 65
  end
end
