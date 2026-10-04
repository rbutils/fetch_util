# frozen_string_literal: true

require "digest"
require "fileutils"
require "rubygems/package"
require "json"
require "pathname"
require "rbconfig"
require "time"
require_relative "../native_replay_support"
require_relative "process_supervisor"

module NativeReplay
  class CaseRunner
    def initialize(manifest_path, variant_name, output_path, case_id)
      @manifest_path = File.expand_path(manifest_path)
      @base = File.dirname(@manifest_path)
      @manifest = Support.read_json(@manifest_path)
      @variant_name = variant_name
      @variant = @manifest.fetch("variants").fetch(variant_name)
      @output_path = File.expand_path(output_path)
      @entry = @manifest.fetch("cases").find { |item| item.fetch("case_id") == case_id }
      raise "unknown case ID" unless @entry
      @row = new_row(case_id)
    end

    def run
      begin
        run_case
      rescue StandardError => e
        @row["error"] = error_record(e)
      ensure
        @row["deadline_exceeded"] = false unless @row.key?("deadline_exceeded")
        @row["elapsed_seconds"] = Process.clock_gettime(Process::CLOCK_MONOTONIC) - @started_at if @started_at
        @row["finished_at"] = timestamp
        persist_row
      end
      @row["error"] || !@row.fetch("cleanup_errors").empty? ? 1 : 0
    end

    private

    def new_row(case_id)
      {
        "case_id" => case_id, "run_id" => @manifest.fetch("run_id"), "variant_name" => @variant_name,
        "manifest_sha256" => Support.file_sha(@manifest_path), "started_at" => timestamp,
        "reader_mode" => @manifest.fetch("reader_mode"), "final_url" => @entry.fetch("final_url"),
        "viewport" => @entry.fetch("viewport"), "runtime_omissions" => @entry.fetch("runtime_omissions"),
        "source_state_differences" => @entry.fetch("source_state_differences"),
        "open_shadow_roots_at_acquisition" => @entry.fetch("open_shadow_roots"),
        "source_snapshot" => @entry.fetch("source_snapshot"), "input_sha256" => @entry.dig("frozen_html", "sha256"),
        "runtime_state_sha256" => nil, "review_required" => false, "requests" => [], "error" => nil,
        "deadline_exceeded" => false, "cleanup_errors" => []
      }
    end

    def run_case
      @started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      validate_inputs!
      load_runtime!
      @row["ruby"] = { "description" => RUBY_DESCRIPTION, "executable" => File.realpath(RbConfig.ruby) }
      @row["ferrum"] = { "version" => Gem.loaded_specs.fetch("ferrum").version.to_s,
                         "gem_path" => Gem.loaded_specs.fetch("ferrum").full_gem_path }
      browser = create_browser
      @row["browser"] = browser.command("Browser.getVersion")
      browser_path = Support.resolve(@base, @manifest.fetch("browser").fetch("path"))
      @row["browser_binary"] = { "path" => browser_path, "sha256" => Support.file_sha(browser_path) }
      execute(browser)
    ensure
      begin
        browser&.quit
      rescue StandardError => e
        record_cleanup_error("browser.quit", e)
      end
    end

    def validate_inputs!
      raise "unsupported manifest schema" unless @manifest.fetch("schema_version") == 1
      raise "case deadline must be finite and positive" unless @manifest.fetch("case_deadline_seconds").is_a?(Numeric) &&
                                                               @manifest.fetch("case_deadline_seconds").finite? &&
                                                               @manifest.fetch("case_deadline_seconds").positive?
      %w[frozen_html runtime_state source_snapshot].each do |key|
        Support.verify_file!(@base, @entry.fetch(key), key)
      end
      runtime = Support.read_json(Support.resolve(@base, @entry.fetch("runtime_state").fetch("path")))
      raise "runtime state must be an object" unless runtime.is_a?(Hash)
      @row["runtime_state_sha256"] = Support.value_sha(runtime)
      raise "runtime_omissions must be an array of strings" unless string_array?(@entry.fetch("runtime_omissions"))
      raise "source_state_differences must be an array of strings" unless string_array?(@entry.fetch("source_state_differences"))
      raise "open_shadow_roots must be a non-negative integer" unless @entry.fetch("open_shadow_roots").is_a?(Integer) && @entry.fetch("open_shadow_roots") >= 0
      @row["review_required"] = !@entry.fetch("runtime_omissions").empty? || @entry.fetch("open_shadow_roots").positive? ||
                                !@entry.fetch("source_state_differences").empty?
    end

    def load_runtime!
      require "ferrum"
      library_root = Support.resolve(@base, @variant.fetch("library_root"))
      $LOAD_PATH.unshift(library_root)
      verify_variant!(library_root)
      require "fetch_util"
      loaded = $LOADED_FEATURES.map { |feature| File.realpath(feature) if File.file?(feature) }.compact
      expected_main = File.realpath(File.join(library_root, "fetch_util.rb"))
      expected_version = File.realpath(Support.resolve(@base, @variant.fetch("version_source").fetch("path")))
      raise "loaded fetch_util feature differs from selected library root" unless loaded.include?(expected_main)
      raise "loaded version feature differs from manifest" unless loaded.include?(expected_version)
      extractor_path = File.realpath(FetchUtil::Extractor.instance_method(:extract).source_location.fetch(0))
      expected_extractor = File.realpath(Support.resolve(@base, @variant.fetch("extractor_source").fetch("path")))
      raise "loaded extractor differs from selected variant" unless extractor_path == expected_extractor
      raise "loaded package version differs from manifest" unless @variant.fetch("version") == FetchUtil::VERSION

      @row["variant"] = variant_identity
    end

    def verify_loaded_sources!
      library_root = Support.resolve(@base, @variant.fetch("library_root"))
      loaded = $LOADED_FEATURES.map { |feature| File.realpath(feature) if File.file?(feature) }.compact
      expected_main = File.realpath(File.join(library_root, "fetch_util.rb"))
      expected_version = File.realpath(Support.resolve(@base, @variant.fetch("version_source").fetch("path")))
      expected_extractor = File.realpath(Support.resolve(@base, @variant.fetch("extractor_source").fetch("path")))
      raise "loaded fetch_util feature differs from selected library root" unless loaded.include?(expected_main)
      raise "loaded version feature differs from manifest" unless loaded.include?(expected_version)
      raise "loaded extractor differs from selected variant" unless
        File.realpath(FetchUtil::Extractor.instance_method(:extract).source_location.fetch(0)) == expected_extractor
      raise "loaded package version differs from manifest" unless @variant.fetch("version") == FetchUtil::VERSION
      @row["loaded_source_paths"] = {
        "entrypoint" => expected_main, "version" => expected_version, "extractor" => expected_extractor
      }
    end

    def verify_variant!(library_root)
      spec = @variant
      extractor = Support.verify_file!(@base, spec.fetch("extractor_source"), "extractor source")
      version_source = Support.verify_file!(@base, spec.fetch("version_source"), "version source")
      fetch_util_root = File.join(library_root, "fetch_util")
      raise "extractor source is outside selected library root" unless extractor.start_with?("#{fetch_util_root}/")
      raise "version source is outside selected library root" unless version_source.start_with?("#{fetch_util_root}/")
      assets_root = Support.resolve(@base, spec.fetch("asset_root"))
      actual_assets = Support.asset_fingerprints(assets_root)
      raise "asset fingerprints mismatch" unless actual_assets == spec.fetch("assets")
      raise "assets are outside selected library root" unless File.realpath(assets_root) == File.realpath(File.join(fetch_util_root, "assets"))

      case spec.fetch("identity_mode")
      when "gem"
        verify_gem_members!(Support.verify_file!(@base, spec.fetch("package"), "package"), library_root)
      when "source_tree"
        root = Support.resolve(@base, spec.fetch("source_tree").fetch("path"))
        actual = Support.directory_sha(root)
        raise "source tree SHA-256 mismatch" unless actual == spec.fetch("source_tree").fetch("sha256")
        raise "source tree does not bind selected library" unless File.realpath(root) == File.realpath(library_root)
      else
        raise "unknown variant identity mode"
      end
    end

    def verify_gem_members!(gem_path, library_root)
      require "tmpdir"
      package = Gem::Package.new(gem_path)
      raise "package name mismatch" unless package.spec.name == "fetch_util"
      raise "package version mismatch" unless package.spec.version.to_s == @variant.fetch("version")
      Dir.mktmpdir("native-replay-gem-") do |directory|
        package.extract_files(directory)
        packaged_root = File.join(directory, "lib")
        raise "package does not include fetch_util library" unless File.directory?(File.join(packaged_root, "fetch_util"))
        raise "package members differ from selected library tree" unless Support.directory_fingerprints(packaged_root) == Support.directory_fingerprints(library_root)
      end
    end

    def variant_identity
      identity = {
        "name" => @variant_name, "version" => @variant.fetch("version"), "identity_mode" => @variant.fetch("identity_mode"),
        "extractor_source_sha256" => Support.file_sha(Support.resolve(@base, @variant.fetch("extractor_source").fetch("path"))),
        "version_source_sha256" => Support.file_sha(Support.resolve(@base, @variant.fetch("version_source").fetch("path"))),
        "assets" => Support.asset_fingerprints(Support.resolve(@base, @variant.fetch("asset_root")))
      }
      if @variant.fetch("identity_mode") == "gem"
        identity["package_sha256"] = Support.file_sha(Support.resolve(@base, @variant.fetch("package").fetch("path")))
      else
        identity["source_tree_sha256"] = Support.directory_sha(Support.resolve(@base, @variant.fetch("source_tree").fetch("path")))
      end
      identity
    end

    def create_browser
      require "rbconfig"
      path = Support.verify_file!(@base, @manifest.fetch("browser"), "browser")
      raise "browser binary is not executable" unless File.file?(path) && File.executable?(path)
      browser = Ferrum::Browser.new(headless: true, browser_path: path, timeout: 30, process_timeout: 20,
                                    window_size: @manifest.fetch("browser").fetch("viewport"),
                                    browser_options: { "no-sandbox" => nil })
      @row["browser_process_group"] = ProcessSupervisor.process_group(browser.process.pid)
      browser
    end

    def execute(browser)
      html = File.read(Support.resolve(@base, @entry.fetch("frozen_html").fetch("path")), encoding: "UTF-8")
      runtime = Support.read_json(Support.resolve(@base, @entry.fetch("runtime_state").fetch("path")))
      page, handler = prepare_page(browser, html, runtime)
      before = Support.snapshot(page)
      write_artifact("before_snapshot", before)
      @row["pre_dom_sha256"] = Digest::SHA256.hexdigest(before.fetch("documentHtml"))
      payload = FetchUtil::Extractor.new(reader_mode: @row.fetch("reader_mode"), asset_root: Support.resolve(@base, @variant.fetch("asset_root"))).extract(page)
      verify_loaded_sources!
      raise TypeError, "native extractor returned #{payload.class} rather than a Hash" unless payload.is_a?(Hash)
      write_artifact("payload", payload)
      after = Support.snapshot(page)
      write_artifact("after_snapshot", after)
    ensure
      begin
        page&.off(:request, handler) if page && handler
      rescue StandardError => e
        record_cleanup_error("page.off_request", e)
      end
      begin
        page&.close
      rescue StandardError => e
        record_cleanup_error("page.close", e)
      end
    end

    def record_cleanup_error(phase, error)
      @row.fetch("cleanup_errors") << {
        "phase" => phase, "class" => error.class.name, "message" => error.message,
        "backtrace" => Array(error.backtrace)
      }
    end

    def prepare_page(browser, html, runtime)
      page = browser.create_page
      viewport = @row.fetch("viewport")
      page.command("Emulation.setDeviceMetricsOverride", width: viewport[0], height: viewport[1], deviceScaleFactor: 1, mobile: false)
      page.bypass_csp
      page.command("Network.setCacheDisabled", cacheDisabled: true)
      page.command("Network.setBypassServiceWorker", bypass: true)
      page.network.intercept(pattern: "*")
      served = false
      target = @row.fetch("final_url").sub(/#.*/, "")
      handler = page.on(:request) do |request|
        if !served && request.url == target
          served = true
          @row["requests"] << { "url_sha256" => Digest::SHA256.hexdigest(request.url), "action" => "blank_document" }
          request.respond(body: "<!doctype html><title>Frozen replay</title>", responseHeaders: { "content-type" => "text/html; charset=UTF-8" })
        else
          @row["requests"] << { "url_sha256" => Digest::SHA256.hexdigest(request.url), "action" => "abort" }
          request.abort
        end
      end
      page.go_to(@row.fetch("final_url"))
      raise "frozen document was not intercepted" unless served
      page.main_frame.set_content(html)
      Support.restore_runtime(page, runtime)
      raise "replay URL changed" unless page.current_url == @row.fetch("final_url")
      [page, handler]
    rescue StandardError
      page&.close
      raise
    end

    def write_artifact(name, value)
      path = artifact_path(name)
      raise "refusing to overwrite artifact: #{path}" if File.exist?(path)
      Support.write_json(path, value)
      @row[name] = { "path" => relative_artifact_path(path), "sha256" => Support.file_sha(path), "value_sha256" => Support.value_sha(value) }
    end

    def persist_row
      path = row_path
      raise "refusing to overwrite case row: #{path}" if File.exist?(path)
      @row["row_path"] = relative_artifact_path(path)
      Support.write_json(path, @row)
    end

    def artifact_path(name)
      File.join(Support.artifact_root(@output_path, @manifest.fetch("run_id"), @variant_name), Support.safe_id(@entry.fetch("case_id")), "#{name}.json")
    end

    def row_path
      artifact_path("run_row")
    end

    def relative_artifact_path(path)
      Pathname.new(path).relative_path_from(Pathname.new(File.dirname(@output_path))).to_s
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
  exit NativeReplay::CaseRunner.new(*ARGV).run
end
