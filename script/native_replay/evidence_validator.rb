# frozen_string_literal: true

require "digest"
require "json"
require "rubygems/package"
require "rbconfig"
require "time"
require "tmpdir"
require_relative "../native_replay_support"
require_relative "comparison"

module NativeReplay
  class EvidenceValidator
    SHA256 = /\A[0-9a-f]{64}\z/

    def initialize(manifest_path, baseline_path, candidate_path, output_path, review_path = nil)
      @manifest_path = File.expand_path(manifest_path)
      @base = File.dirname(@manifest_path)
      @manifest = Support.read_json(@manifest_path)
      @runs = {
        "baseline" => load_run(baseline_path, "baseline"),
        "candidate" => load_run(candidate_path, "candidate")
      }
      @output_path = File.expand_path(output_path)
      @review_path = File.expand_path(review_path) if review_path
      @reviews = load_reviews
    end

    def run
      raise "refusing to overwrite comparison output: #{@output_path}" if File.exist?(@output_path)
      validate_manifest!
      ids = @manifest.fetch("cases").map { |entry| entry.fetch("case_id") }
      indexed = @runs.transform_values { |run| validate_run(run, ids) }
      rows = @manifest.fetch("cases").map do |entry|
        compare_case(entry, indexed.fetch("baseline").fetch(entry.fetch("case_id")),
                     indexed.fetch("candidate").fetch(entry.fetch("case_id")))
      end
      record = {
        "schema_version" => 1, "run_id" => @manifest.fetch("run_id"),
        "manifest_sha256" => Support.file_sha(@manifest_path),
        "run_sha256" => @runs.transform_values { |run| run.fetch("file_sha256") },
        "cases" => rows.length, "status_counts" => rows.map { |row| row.fetch("status") }.tally,
        "review_decision_counts" => rows.filter_map { |row| row.dig("review", "decision") }.tally,
        "rows" => rows,
        "semantic_scope" => "Evidence integrity only; no semantic wins are assigned and successful rows remain review_required.",
        "finished_at" => Time.now.utc.iso8601(6)
      }
      Support.write_json(@output_path, record)
      puts JSON.generate(record.reject { |key, _| key == "rows" })
      0
    end

    private

    def load_run(path, variant)
      absolute = File.expand_path(path)
      { "data" => Support.read_json(absolute), "path" => absolute,
        "file_sha256" => Support.file_sha(absolute), "variant_name" => variant }
    end

    def validate_manifest!
      raise "unsupported manifest schema" unless @manifest.fetch("schema_version") == 1
      raise "entrypoint mismatch" unless @manifest.fetch("entrypoint") == "FetchUtil::Extractor#extract"
      browser_path = Support.verify_file!(@base, @manifest.fetch("browser"), "browser")
      raise "browser binary is not executable" unless File.executable?(browser_path)
      ids = @manifest.fetch("cases").map { |entry| entry.fetch("case_id") }
      raise "empty or duplicate manifest case IDs" if ids.empty? || ids.uniq != ids
      raise "variants must contain baseline and candidate" unless @manifest.fetch("variants").keys.sort == %w[baseline candidate]
      @manifest.fetch("cases").each do |entry|
        %w[frozen_html runtime_state source_snapshot].each { |key| Support.verify_file!(@base, entry.fetch(key), key) }
      end
    end

    def validate_run(run, expected_ids)
      data = run.fetch("data")
      variant = run.fetch("variant_name")
      raise "#{variant} run schema mismatch" unless data.fetch("schema_version") == 1
      raise "#{variant} run manifest binding mismatch" unless data.fetch("manifest_sha256") == Support.file_sha(@manifest_path)
      raise "#{variant} run identity mismatch" unless data.fetch("run_id") == @manifest.fetch("run_id") && data.fetch("variant_name") == variant
      raise "#{variant} entrypoint mismatch" unless data.fetch("entrypoint") == @manifest.fetch("entrypoint")
      raise "#{variant} reader mode mismatch" unless data.fetch("reader_mode") == @manifest.fetch("reader_mode")
      raise "#{variant} Ruby identity malformed" unless data.fetch("ruby").values.all? { |value| value.is_a?(String) && !value.empty? }
      expected_ruby = { "description" => RUBY_DESCRIPTION, "executable" => File.realpath(RbConfig.ruby) }
      raise "#{variant} Ruby identity differs from validator runtime" unless data.fetch("ruby") == expected_ruby
      Support.validate_error!(data.fetch("startup_error"), false) if data["startup_error"]

      rows = data.fetch("rows")
      ids = rows.map { |row| row.fetch("case_id") }
      raise "#{variant} run has duplicate, missing, or unexpected IDs" unless ids.uniq == ids && ids == expected_ids
      raise "#{variant} case_ids index mismatch" unless data.fetch("case_ids") == ids
      identity = expected_variant(variant)
      raise "#{variant} run identity stamp mismatch" if data["variant"] && data.fetch("variant") != identity
      validated = rows.to_h { |row| [row.fetch("case_id"), validate_row(row, run, identity)] }
      successful = rows.reject { |row| row["error"] }
      raise "#{variant} run-level Ruby identity mismatch" unless successful.all? { |row| row.fetch("ruby") == data.fetch("ruby") }
      ferrum = successful.map { |row| row.dig("ferrum", "version") }.uniq
      raise "#{variant} Ferrum identities missing or inconsistent" unless successful.empty? || (ferrum.one? && ferrum.first.is_a?(String))
      raise "#{variant} Ruby identity differs between rows" unless successful.map { |row| row.fetch("ruby") }.uniq.length <= 1
      browser_consistent = successful.all? do |row|
        row["browser"] == successful.first["browser"] &&
          row["browser_binary"] == successful.first["browser_binary"]
      end
      raise "#{variant} browser identity missing or inconsistent" unless browser_consistent
      validated
    end

    def expected_variant(name)
      spec = @manifest.fetch("variants").fetch(name)
      library_root = Support.resolve(@base, spec.fetch("library_root"))
      library_tree = File.join(library_root, "fetch_util")
      extractor = Support.verify_file!(@base, spec.fetch("extractor_source"), "#{name} extractor")
      version = Support.verify_file!(@base, spec.fetch("version_source"), "#{name} version")
      assets_root = Support.resolve(@base, spec.fetch("asset_root"))
      assets = Support.asset_fingerprints(assets_root)
      raise "#{name} asset pin mismatch" unless assets == spec.fetch("assets")
      raise "#{name} assets outside selected library" unless File.realpath(assets_root) == File.realpath(File.join(library_tree, "assets"))
      raise "#{name} extractor outside selected library" unless extractor.start_with?("#{library_tree}/")
      raise "#{name} version source outside selected library" unless version.start_with?("#{library_tree}/")

      identity = {
        "name" => name, "version" => spec.fetch("version"), "identity_mode" => spec.fetch("identity_mode"),
        "extractor_source_sha256" => Support.file_sha(extractor), "version_source_sha256" => Support.file_sha(version),
        "assets" => assets
      }
      if spec.fetch("identity_mode") == "gem"
        package_path = Support.verify_file!(@base, spec.fetch("package"), "#{name} package")
        package = Gem::Package.new(package_path)
        raise "#{name} package name mismatch" unless package.spec.name == "fetch_util"
        raise "#{name} package version mismatch" unless package.spec.version.to_s == spec.fetch("version")
        Dir.mktmpdir("native-replay-validation-") do |directory|
          package.extract_files(directory)
          packaged_tree = File.join(directory, "lib")
          packaged_members = Support.directory_fingerprints(packaged_tree)
          selected_members = Support.directory_fingerprints(library_root)
          raise "#{name} package members differ from selected source" unless packaged_members == selected_members
        end
        identity["package_sha256"] = Support.file_sha(package_path)
      elsif spec.fetch("identity_mode") == "source_tree"
        source_tree = Support.resolve(@base, spec.fetch("source_tree").fetch("path"))
        raise "#{name} source tree does not match selected source" unless File.realpath(source_tree) == File.realpath(library_root)
        actual = Support.directory_sha(source_tree)
        raise "#{name} source tree pin mismatch" unless actual == spec.fetch("source_tree").fetch("sha256")
        identity["source_tree_sha256"] = actual
      else
        raise "#{name} identity mode unsupported"
      end
      identity
    end

    def validate_row(row, run, identity)
      variant = run.fetch("variant_name")
      raise "#{variant} row run identity mismatch" unless row.fetch("run_id") == @manifest.fetch("run_id") && row.fetch("variant_name") == variant
      raise "#{variant} row manifest mismatch" unless row.fetch("manifest_sha256") == Support.file_sha(@manifest_path)
      Support.validate_error!(row.fetch("error"), row.fetch("deadline_exceeded"))
      cleanup_errors = row.fetch("cleanup_errors")
      valid_cleanup_errors = cleanup_errors.is_a?(Array) && cleanup_errors.all? do |error|
        error.is_a?(Hash) && error.keys.sort == %w[backtrace class message phase] &&
          %w[class message phase].all? { |key| error.fetch(key).is_a?(String) && !error.fetch(key).empty? } &&
          error.fetch("backtrace").is_a?(Array) && error.fetch("backtrace").all? { |line| line.is_a?(String) }
      end
      raise "#{variant} cleanup error record malformed" unless valid_cleanup_errors
      if row["error"].nil?
        raise "#{variant} row actual variant mismatch" unless row.fetch("variant") == identity
        selected = @manifest.fetch("variants").fetch(variant)
        expected_paths = {
          "entrypoint" => File.realpath(File.join(Support.resolve(@base, selected.fetch("library_root")), "fetch_util.rb")),
          "version" => File.realpath(Support.resolve(@base, selected.fetch("version_source").fetch("path"))),
          "extractor" => File.realpath(Support.resolve(@base, selected.fetch("extractor_source").fetch("path")))
        }
        raise "#{variant} loaded source paths differ from selected variant" unless row.fetch("loaded_source_paths") == expected_paths
        raise "#{variant} row Ruby identity mismatch" unless row.fetch("ruby").is_a?(Hash) && !row.fetch("ruby").empty?
        ferrum = row.fetch("ferrum")
        installed_ferrum = Gem::Specification.find_by_name("ferrum")
        ferrum_matches = ferrum.fetch("version") == installed_ferrum.version.to_s &&
                         File.realpath(ferrum.fetch("gem_path")) == File.realpath(installed_ferrum.full_gem_path)
        raise "#{variant} Ferrum identity differs from validator runtime" unless ferrum_matches
        browser = row.fetch("browser")
        raise "#{variant} browser version malformed" unless browser.fetch("product").is_a?(String) && browser.fetch("userAgent").is_a?(String)
        binary_path = Support.resolve(@base, @manifest.fetch("browser").fetch("path"))
        expected_binary = { "path" => binary_path, "sha256" => @manifest.fetch("browser").fetch("sha256") }
        raise "#{variant} browser binary identity mismatch" unless row.fetch("browser_binary") == expected_binary
        process_group = row.fetch("browser_process_group")
        valid_process_group = process_group.fetch("pid").is_a?(Integer) && process_group.fetch("pid").positive? &&
                              process_group.fetch("pgid") == process_group.fetch("pid") &&
                              process_group.fetch("start_time_ticks").is_a?(String) &&
                              File.realpath(process_group.fetch("executable")) == File.realpath(binary_path)
        raise "#{variant} browser process group identity mismatch" unless valid_process_group
      end
      entry = @manifest.fetch("cases").find { |item| item.fetch("case_id") == row.fetch("case_id") }
      raise "#{variant} reader_mode mismatch" unless row.fetch("reader_mode") == @manifest.fetch("reader_mode")
      raise "#{variant} final URL or viewport mismatch" unless row.fetch("final_url") == entry.fetch("final_url") && row.fetch("viewport") == entry.fetch("viewport")
      raise "#{variant} input binding mismatch" unless row.fetch("input_sha256") == entry.dig("frozen_html", "sha256")
      runtime = Support.read_json(Support.resolve(@base, entry.fetch("runtime_state").fetch("path")))
      raise "#{variant} runtime binding mismatch" unless row.fetch("runtime_state_sha256") == Support.value_sha(runtime)
      raise "#{variant} source snapshot reference mismatch" unless row.fetch("source_snapshot") == entry.fetch("source_snapshot")
      raise "#{variant} source qualifications mismatch" unless row.fetch("runtime_omissions") == entry.fetch("runtime_omissions") &&
                                                               row.fetch("source_state_differences") == entry.fetch("source_state_differences") &&
                                                               row.fetch("open_shadow_roots_at_acquisition") == entry.fetch("open_shadow_roots")
      expected_review = !entry.fetch("runtime_omissions").empty? || entry.fetch("open_shadow_roots").positive? || !entry.fetch("source_state_differences").empty?
      raise "#{variant} review marker mismatch" unless row.fetch("review_required") == expected_review

      row_path = safe_path(run_directory(run), row.fetch("row_path"))
      raise "#{variant} case row missing" unless File.file?(row_path)
      raise "#{variant} case row differs from run" unless Support.read_json(row_path) == row
      %w[payload before_snapshot after_snapshot].each do |key|
        verify_output!(row.fetch(key), run_directory(run), "#{variant} #{key}") if row.key?(key)
      end
      if row["error"].nil?
        raise "#{variant} successful row requires payload and both snapshots" unless %w[payload before_snapshot after_snapshot].all? { |key| row.key?(key) }
        payload = verify_output!(row.fetch("payload"), run_directory(run), "#{variant} payload")
        raise "#{variant} payload must be a JSON object" unless payload.is_a?(Hash)
      end
      elapsed = row.fetch("elapsed_seconds")
      raise "#{variant} elapsed time malformed" unless elapsed.is_a?(Numeric) && elapsed.finite? && elapsed >= 0
      if row["before_snapshot"]
        before = verify_output!(row.fetch("before_snapshot"), run_directory(run), "#{variant} before snapshot")
        raise "#{variant} pre-DOM fingerprint mismatch" unless Digest::SHA256.hexdigest(before.fetch("documentHtml")) == row.fetch("pre_dom_sha256")
      end
      row
    end

    def compare_case(entry, baseline, candidate)
      Comparison.new(@manifest, @manifest_path).compare(entry, baseline, candidate, @reviews[entry.fetch("case_id")])
    end

    def load_reviews
      return {} unless @review_path
      data = Support.read_json(@review_path)
      raise "unsupported review schema" unless data.fetch("schema_version") == 1
      raise "review run identity mismatch" unless data.fetch("run_id") == @manifest.fetch("run_id")
      raise "review manifest binding mismatch" unless data.fetch("manifest_sha256") == Support.file_sha(@manifest_path)
      rows = data.fetch("rows")
      ids = rows.map { |row| row.fetch("case_id") }
      expected = @manifest.fetch("cases").map { |entry| entry.fetch("case_id") }
      raise "duplicate or unexpected review IDs" unless ids.uniq == ids && (ids - expected).empty?
      rows.each do |row|
        raise "unknown review decision" unless Comparison::REVIEW_DECISIONS.include?(row.fetch("decision"))
        raise "reviewer must be named" unless row.fetch("reviewer").is_a?(String) && !row.fetch("reviewer").empty?
        raise "review evidence must be hashed file references" unless row.fetch("evidence").is_a?(Array) && !row.fetch("evidence").empty?
        row.fetch("evidence").each { |reference| verify_file_reference!(reference, File.dirname(@review_path), "review evidence") }
      end
      rows.to_h { |row| [row.fetch("case_id"), row] }
    end

    def verify_output!(reference, base, label)
      raise "#{label} reference malformed" unless reference.is_a?(Hash) && reference.fetch("sha256").match?(SHA256) && reference.fetch("value_sha256").match?(SHA256)
      path = safe_path(base, reference.fetch("path"))
      raise "missing #{label}" unless File.file?(path)
      raise "#{label} file fingerprint mismatch" unless Support.file_sha(path) == reference.fetch("sha256")
      value = Support.read_json(path)
      raise "#{label} value fingerprint mismatch" unless Support.value_sha(value) == reference.fetch("value_sha256")
      value
    end

    def verify_file_reference!(reference, base, label)
      raise "#{label} reference malformed" unless reference.is_a?(Hash) && reference.fetch("sha256").match?(SHA256)
      path = safe_path(base, reference.fetch("path"))
      raise "missing #{label}" unless File.file?(path)
      raise "#{label} fingerprint mismatch" unless Support.file_sha(path) == reference.fetch("sha256")
      path
    end

    def safe_path(base, relative)
      raise "artifact path must be relative" unless relative.is_a?(String) && !Pathname.new(relative).absolute?
      path = File.expand_path(relative, base)
      raise "artifact path escapes its evidence directory" unless path.start_with?("#{File.expand_path(base)}/")
      path
    end

    def run_directory(run)
      File.dirname(run.fetch("path"))
    end
  end
end

if $PROGRAM_NAME == __FILE__
  unless (4..5).cover?(ARGV.length)
    warn "Usage: ruby script/validate_replay_evidence.rb MANIFEST.json BASELINE_RUN.json CANDIDATE_RUN.json OUTPUT.json [REVIEWS.json]"
    exit 64
  end
  exit NativeReplay::EvidenceValidator.new(*ARGV).run
end
