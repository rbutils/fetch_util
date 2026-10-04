# frozen_string_literal: true

require "fileutils"
require "open3"
require "rbconfig"
require "tmpdir"
require "rubygems/package"
require_relative "../../script/native_replay_support"

RSpec.shared_context "native replay runs" do
  before(:all) do
    @project_root = File.expand_path("../..", __dir__)
    @browser_path = ENV["BROWSER_PATH"] || FetchUtil::Browser::BROWSER_CANDIDATES.find { |path| File.executable?(path) }
    unless @browser_path
      skip "Chromium unavailable by explicit opt-in" if ENV["FETCH_UTIL_ALLOW_MISSING_CHROMIUM"] == "1"

      raise "Chromium is required; set FETCH_UTIL_ALLOW_MISSING_CHROMIUM=1 only for explicitly limited environments"
    end
    @temporary_root = Dir.mktmpdir("native-replay-spec-")
    @manifest_path = File.join(@temporary_root, "manifest.json")
    @run_paths = {}
    build_manifest
    %w[baseline candidate].each do |variant|
      output = File.join(@temporary_root, "#{variant}-run.json")
      stdout, stderr, status = Open3.capture3(
        RbConfig.ruby, File.join(@project_root, "script/native_replay.rb"), @manifest_path, variant, output,
        chdir: @project_root
      )
      run = NativeReplay::Support.read_json(output) if File.file?(output)
      expect(status.success?).to be(true), "#{stdout}\n#{stderr}\n#{run&.dig("rows", 0, "error")}"
      @run_paths[variant] = output
    end
  end

  after(:all) do
    FileUtils.remove_entry(@temporary_root) if @temporary_root && File.directory?(@temporary_root)
  end

  def build_manifest
    input = File.join(@project_root, "spec/fixtures/native_replay/article.html")
    runtime = File.join(@temporary_root, "runtime.json")
    snapshot = File.join(@temporary_root, "source-snapshot.json")
    NativeReplay::Support.write_json(runtime, {})
    NativeReplay::Support.write_json(snapshot, { "documentHtml" => "<html></html>", "viewport" => [1280, 900] })

    baseline_root = File.join(@temporary_root, "baseline-package")
    baseline_library = File.join(baseline_root, "lib")
    FileUtils.mkdir_p(baseline_library)
    FileUtils.cp_r(File.join(@project_root, "lib/fetch_util"), baseline_library)
    FileUtils.cp(File.join(@project_root, "lib/fetch_util.rb"), baseline_library)
    baseline_gem = File.join(@temporary_root, "baseline.gem")
    build_fixture_package(baseline_root, baseline_gem)

    variants = %w[baseline candidate].to_h do |name|
      library = name == "baseline" ? baseline_library : File.join(@project_root, "lib")
      fetch_util = File.join(library, "fetch_util")
      identity = if name == "baseline"
                   { "identity_mode" => "gem", "package" => file_reference(baseline_gem) }
                 else
                   { "identity_mode" => "source_tree",
                     "source_tree" => { "path" => library, "sha256" => NativeReplay::Support.directory_sha(library) } }
                 end
      [name, {
        "name" => name, "version" => FetchUtil::VERSION, "library_root" => library,
        "asset_root" => File.join(fetch_util, "assets"),
        "assets" => NativeReplay::Support.asset_fingerprints(File.join(fetch_util, "assets")),
        **identity, "extractor_source" => file_reference(File.join(fetch_util, "extractor.rb")),
        "version_source" => file_reference(File.join(fetch_util, "version.rb"))
      }]
    end
    NativeReplay::Support.write_json(
      @manifest_path,
      {
        "schema_version" => 1, "run_id" => "native-replay-spec",
        "entrypoint" => "FetchUtil::Extractor#extract", "reader_mode" => true,
        "case_deadline_seconds" => 90,
        "browser" => file_reference(@browser_path).merge("viewport" => [1280, 900]), "variants" => variants,
        "cases" => [{
          "case_id" => "local-article", "final_url" => "https://native-replay.invalid/article",
          "viewport" => [1280, 900], "frozen_html" => file_reference(input), "runtime_state" => file_reference(runtime),
          "source_snapshot" => file_reference(snapshot), "runtime_omissions" => [],
          "source_state_differences" => [], "open_shadow_roots" => 0
        }]
      }
    )
  end

  def build_fixture_package(root, destination)
    specification = Gem::Specification.new do |gem_spec|
      gem_spec.name = "fetch_util"
      gem_spec.version = FetchUtil::VERSION
      gem_spec.summary = "Native replay fixture package"
      gem_spec.authors = ["test"]
      gem_spec.files = Dir.chdir(root) { Dir.glob("lib/**/*").select { |path| File.file?(path) } }
    end
    Dir.chdir(root) { Gem::Package.build(specification, true, false, destination) }
  end

  def file_reference(path)
    { "path" => path, "sha256" => NativeReplay::Support.file_sha(path) }
  end

  def process_state(pid)
    stat = File.read("/proc/#{pid}/stat")
    stat[(stat.rindex(")") + 2)..].split.fetch(0)
  rescue Errno::ENOENT
    nil
  end
end
