# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "pathname"
require "rbconfig"
require "time"
require_relative "native_replay_support"
require_relative "native_replay/process_supervisor"

module NativeReplay
  class Runner
    POLL_INTERVAL = 0.05

    def initialize(manifest_path, variant_name, output_path)
      @manifest_path = File.expand_path(manifest_path)
      @base = File.dirname(@manifest_path)
      @manifest = Support.read_json(@manifest_path)
      @variant_name = variant_name
      @variant = @manifest.fetch("variants").fetch(variant_name)
      @output_path = File.expand_path(output_path)
      validate_manifest!
    end

    def run
      prepare_output!
      write_index
      @manifest.fetch("cases").each do |entry|
        row = run_case(entry)
        @rows << row
        write_index
        puts "#{row.fetch("case_id")}: #{row["error"] ? "error" : "saved"}"
      end
      @rows.any? { |row| row["error"] || !row.fetch("cleanup_errors", []).empty? } ? 1 : 0
    rescue StandardError => e
      @startup_error = error_record(e)
      write_index if @index_created
      warn "native replay failed: #{e.class}: #{e.message}"
      1
    ensure
      cleanup_active_tree if @active_tree
    end

    private

    def validate_manifest!
      ProcessSupervisor.ensure_supported!
      raise "unsupported manifest schema" unless @manifest.fetch("schema_version") == 1
      raise "run_id must be a non-empty string" unless nonempty_string?(@manifest.fetch("run_id"))
      raise "entrypoint must be FetchUtil::Extractor#extract" unless @manifest.fetch("entrypoint") == "FetchUtil::Extractor#extract"
      raise "reader_mode must be boolean" unless [true, false].include?(@manifest.fetch("reader_mode"))
      deadline = @manifest.fetch("case_deadline_seconds")
      raise "case deadline must be finite and positive" unless deadline.is_a?(Numeric) && deadline.finite? && deadline.positive?
      raise "cases must be a non-empty array" unless @manifest.fetch("cases").is_a?(Array) && !@manifest.fetch("cases").empty?
      raise "browser viewport must contain two positive integers" unless valid_viewport?(@manifest.fetch("browser").fetch("viewport"))
      browser_settings = @manifest.fetch("browser")
      browser = Support.verify_file!(@base, browser_settings, "browser")
      raise "browser binary is not executable" unless File.executable?(browser)

      ids = @manifest.fetch("cases").map { |entry| entry.fetch("case_id") }
      raise "case IDs must be unique non-empty strings" unless ids.all? { |id| nonempty_string?(id) } && ids.uniq == ids
      paths = ids.map { |id| Support.safe_id(id) }
      raise "case IDs collide in artifact paths" unless paths.uniq == paths
      raise "unknown variant" unless %w[baseline candidate].include?(@variant_name)
      raise "variant identity mismatch" unless @variant.fetch("name") == @variant_name
      @manifest.fetch("cases").each { |entry| validate_case!(entry) }
    end

    def validate_case!(entry)
      raise "final_url must be HTTP(S)" unless entry.fetch("final_url").is_a?(String) && entry.fetch("final_url").match?(%r{\Ahttps?://})
      raise "viewport must contain two positive integers" unless valid_viewport?(entry.fetch("viewport"))
      %w[frozen_html runtime_state source_snapshot].each { |key| Support.verify_file!(@base, entry.fetch(key), key) }
      runtime = Support.read_json(Support.resolve(@base, entry.fetch("runtime_state").fetch("path")))
      raise "runtime state must be an object" unless runtime.is_a?(Hash)
      %w[runtime_omissions source_state_differences].each do |key|
        raise "#{key} must be an array of strings" unless string_array?(entry.fetch(key))
      end
      shadows = entry.fetch("open_shadow_roots")
      raise "open_shadow_roots must be a non-negative integer" unless shadows.is_a?(Integer) && shadows >= 0
    end

    def prepare_output!
      artifact_directory = Support.artifact_root(@output_path, @manifest.fetch("run_id"), @variant_name)
      raise "refusing to overwrite run output: #{@output_path}" if File.exist?(@output_path)
      raise "refusing to reuse artifact directory: #{artifact_directory}" if File.exist?(artifact_directory)

      FileUtils.mkdir_p(artifact_directory)
      @artifact_directory = artifact_directory
      @rows = []
      @worker_pids = []
    end

    def run_case(entry)
      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      @last_process_groups = []
      expected_path = row_path(entry)
      pid = Process.spawn(RbConfig.ruby, File.join(__dir__, "native_replay", "case_runner.rb"),
                          @manifest_path, @variant_name, @output_path, entry.fetch("case_id"),
                          out: File::NULL, pgroup: true)
      @worker_pids << pid
      @active_tree = { "root_pid" => pid, "groups" => ProcessSupervisor.descendant_groups(pid) }
      status = wait_worker(pid, @manifest.fetch("case_deadline_seconds"))
      row = if status == :deadline
              failed_row(entry, "Timeout::Error", "per-case hard deadline exceeded", true, started_at)
            elsif File.file?(expected_path)
              Support.read_json(expected_path)
            else
              failed_row(entry, "WorkerExit", "case worker exited without persisting evidence (status #{status.exitstatus})", false, started_at)
            end
      validate_worker_row!(row, entry)
      row
    rescue StandardError => e
      failed_row(entry, e.class.name, e.message, false, started_at)
    ensure
      if @active_tree
        begin
          cleanup_active_tree
        rescue StandardError => e
          message = e.message
          message = "#{message}; original case error: #{row.dig("error", "message")}" if row && row["error"]
          cleanup_row = failed_row(entry, "ProcessCleanupError", message, false, started_at)
          @rows << cleanup_row
          write_index
          raise e
        end
      end
    end

    def wait_worker(pid, deadline)
      expires = Process.clock_gettime(Process::CLOCK_MONOTONIC) + deadline
      loop do
        result = Process.waitpid2(pid, Process::WNOHANG)
        return result.last if result
        @active_tree.fetch("groups").concat(ProcessSupervisor.descendant_groups(pid))
        @active_tree.fetch("groups").uniq! { |group| group.fetch("pgid") }
        break if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= expires

        sleep POLL_INTERVAL
      end
      cleanup_active_tree
      :deadline
    ensure
      begin
        Process.waitpid(pid)
      rescue Errno::ECHILD
        nil
      end
    end

    def cleanup_active_tree
      tree = @active_tree
      return unless tree

      tree["groups"] = ProcessSupervisor.terminate_tree(tree.fetch("root_pid"), tree.fetch("groups"))
      @last_process_groups = tree.fetch("groups")
      @active_tree = nil
    end

    def validate_worker_row!(row, entry)
      raise "worker case identity mismatch" unless row.fetch("case_id") == entry.fetch("case_id")
      Support.validate_error!(row.fetch("error"), row.fetch("deadline_exceeded"))
      return unless row["error"].nil?

      %w[payload before_snapshot after_snapshot].each do |key|
        raise "successful worker lacks #{key}" unless row.key?(key)
      end
    end

    def failed_row(entry, klass, message, deadline, started_at = nil)
      runtime = Support.read_json(Support.resolve(@base, entry.fetch("runtime_state").fetch("path")))
      review_required = !entry.fetch("runtime_omissions").empty? || entry.fetch("open_shadow_roots").positive? ||
                        !entry.fetch("source_state_differences").empty?
      elapsed = started_at ? Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at : 0.0
      row = {
        "case_id" => entry.fetch("case_id"), "run_id" => @manifest.fetch("run_id"), "variant_name" => @variant_name,
        "manifest_sha256" => Support.file_sha(@manifest_path), "started_at" => timestamp, "finished_at" => timestamp,
        "reader_mode" => @manifest.fetch("reader_mode"), "final_url" => entry.fetch("final_url"),
        "viewport" => entry.fetch("viewport"), "input_sha256" => entry.dig("frozen_html", "sha256"),
        "runtime_state_sha256" => Support.value_sha(runtime), "review_required" => review_required,
        "runtime_omissions" => entry.fetch("runtime_omissions"), "source_state_differences" => entry.fetch("source_state_differences"),
        "open_shadow_roots_at_acquisition" => entry.fetch("open_shadow_roots"), "source_snapshot" => entry.fetch("source_snapshot"),
        "observed_process_groups" => @active_tree ? @active_tree.fetch("groups") : (@last_process_groups || []),
        "requests" => [], "cleanup_errors" => [],
        "error" => { "class" => klass, "message" => message, "backtrace" => [] },
        "deadline_exceeded" => deadline,
        "elapsed_seconds" => elapsed
      }
      path = row_path(entry)
      path = path.sub(/run_row\.json\z/, "parent_error_row.json") if File.exist?(path)
      row["row_path"] = relative_artifact_path(path)
      Support.write_json(path, row)
      row
    end

    def validate_run_identities!
      variants = @rows.filter_map { |row| row["variant"] }.uniq
      raise "case workers loaded different variant identities" if variants.length > 1
      ferrum_versions = @rows.filter_map { |row| row.dig("ferrum", "version") }.uniq
      raise "case workers used different Ferrum versions" if ferrum_versions.length > 1
    end

    def write_index
      validate_run_identities! if @rows
      index = {
        "schema_version" => 1, "run_id" => @manifest.fetch("run_id"),
        "manifest_sha256" => Support.file_sha(@manifest_path), "variant_name" => @variant_name,
        "entrypoint" => @manifest.fetch("entrypoint"), "reader_mode" => @manifest.fetch("reader_mode"),
        "ruby" => { "description" => RUBY_DESCRIPTION, "executable" => File.realpath(RbConfig.ruby) },
        "case_ids" => @manifest.fetch("cases").map { |entry| entry.fetch("case_id") },
        "worker_pids" => @worker_pids || [],
        "rows" => @rows || [], "startup_error" => @startup_error,
        "semantic_verdict" => "No semantic wins assigned; source review is required.", "finished_at" => timestamp
      }
      identity = @rows&.find { |row| row["variant"] }
      index["variant"] = identity["variant"] if identity
      Support.write_json(@output_path, index)
      @index_created = true
    end

    def row_path(entry)
      File.join(@artifact_directory || Support.artifact_root(@output_path, @manifest.fetch("run_id"), @variant_name),
                Support.safe_id(entry.fetch("case_id")), "run_row.json")
    end

    def relative_artifact_path(path)
      Pathname.new(path).relative_path_from(Pathname.new(File.dirname(@output_path))).to_s
    end

    def valid_viewport?(value)
      value.is_a?(Array) && value.length == 2 && value.all? { |dimension| dimension.is_a?(Integer) && dimension.positive? }
    end

    def nonempty_string?(value)
      value.is_a?(String) && !value.empty?
    end

    def string_array?(value)
      value.is_a?(Array) && value.all? { |item| item.is_a?(String) }
    end

    def error_record(error)
      { "class" => error.class.name, "message" => error.message, "backtrace" => Array(error.backtrace) }
    end

    def timestamp
      Time.now.utc.iso8601(6)
    end
  end
end

if $PROGRAM_NAME == __FILE__
  if ARGV.length != 3
    warn "Usage: ruby script/native_replay.rb MANIFEST.json baseline|candidate OUTPUT.json"
    exit 64
  end
  begin
    exit NativeReplay::Runner.new(*ARGV).run
  rescue StandardError => e
    warn "native replay failed: #{e.class}: #{e.message}"
    exit 65
  end
end
