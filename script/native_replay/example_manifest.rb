# frozen_string_literal: true

require "fileutils"
require "pathname"
require_relative "../native_replay_support"

module NativeReplay
  class ExampleManifest
    def initialize(output_directory)
      @source_root = File.expand_path("../..", __dir__)
      @output_directory = File.expand_path(output_directory)
      @browser_path = File.realpath(ENV.fetch("BROWSER_PATH"))
    end

    def write
      FileUtils.mkdir_p(@output_directory)
      html = File.join(@source_root, "spec/fixtures/native_replay/article.html")
      frozen_html = copy_fixture(html, "article.html")
      runtime_state = write_json_fixture("runtime-state.json", {})
      source_snapshot = write_json_fixture(
        "source-snapshot.json",
        {
          "documentHtml" => File.read(html, encoding: "UTF-8"), "viewport" => [1280, 900],
          "provenance" => "synthetic documentation fixture; replace with immutable acquisition diagnostics"
        }
      )
      reference = variant_reference
      manifest = {
        "schema_version" => 1, "run_id" => "native-article-example",
        "entrypoint" => "FetchUtil::Extractor#extract", "reader_mode" => true,
        "case_deadline_seconds" => 60,
        "browser" => file_reference(@browser_path).merge("viewport" => [1280, 900]),
        "variants" => {
          "baseline" => reference.merge("name" => "baseline"),
          "candidate" => reference.merge("name" => "candidate")
        },
        "cases" => [{
          "case_id" => "native-article-example", "final_url" => "https://native-replay.invalid/article",
          "viewport" => [1280, 900], "frozen_html" => frozen_html, "runtime_state" => runtime_state,
          "source_snapshot" => source_snapshot, "runtime_omissions" => [],
          "source_state_differences" => ["documentation example source snapshot is synthetic"],
          "open_shadow_roots" => 0
        }]
      }
      Support.write_json(File.join(@output_directory, "manifest.json"), manifest)
      puts File.join(@output_directory, "manifest.json")
      true
    end

    private

    def variant_reference
      library = File.join(@source_root, "lib")
      fetch_util = File.join(library, "fetch_util")
      {
        "name" => "source-tree-example", "version" => FetchUtil::VERSION,
        "identity_mode" => "source_tree", "library_root" => relative_path(library),
        "asset_root" => relative_path(File.join(fetch_util, "assets")),
        "assets" => Support.asset_fingerprints(File.join(fetch_util, "assets")),
        "extractor_source" => file_reference(File.join(fetch_util, "extractor.rb")),
        "version_source" => file_reference(File.join(fetch_util, "version.rb")),
        "source_tree" => { "path" => relative_path(library), "sha256" => Support.directory_sha(library) }
      }
    end

    def copy_fixture(source, name)
      destination = File.join(@output_directory, name)
      FileUtils.cp(source, destination)
      file_reference(destination)
    end

    def write_json_fixture(name, value)
      path = File.join(@output_directory, name)
      Support.write_json(path, value)
      file_reference(path)
    end

    def file_reference(path)
      { "path" => relative_path(path), "sha256" => Support.file_sha(path) }
    end

    def relative_path(path)
      Pathname.new(path).relative_path_from(Pathname.new(@output_directory)).to_s
    end
  end
end

if $PROGRAM_NAME == __FILE__
  if ARGV.length != 1 || !ENV.key?("BROWSER_PATH")
    warn "Usage: BROWSER_PATH=/path/to/chromium ruby script/native_replay/example_manifest.rb OUTPUT_DIRECTORY"
    exit 64
  end

  begin
    require File.expand_path("../../lib/fetch_util", __dir__)
    NativeReplay::ExampleManifest.new(ARGV.fetch(0)).write
    exit 0
  rescue StandardError => e
    warn "example manifest failed: #{e.class}: #{e.message}"
    exit 1
  end
end
