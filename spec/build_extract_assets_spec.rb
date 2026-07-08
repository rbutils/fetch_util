# frozen_string_literal: true

require "open3"
require "fileutils"
require "tmpdir"

RSpec.describe "extract asset bundle" do
  def project_root
    File.expand_path("..", __dir__)
  end

  def run_build_script(*args, root: project_root)
    script = File.join(root, "script", "build_extract_assets.rb")
    Open3.capture3(RbConfig.ruby, script, *args, chdir: root)
  end

  def with_asset_project(manifest:, files:)
    Dir.mktmpdir("fetch_util_assets") do |root|
      script_dir = File.join(root, "script")
      source_root = File.join(root, "lib", "fetch_util", "assets", "src")
      FileUtils.mkdir_p([script_dir, source_root])
      FileUtils.cp(File.join(project_root, "script", "build_extract_assets.rb"), script_dir)
      File.write(File.join(source_root, "manifest.txt"), manifest)

      files.each do |path, contents|
        file = File.join(source_root, path)
        FileUtils.mkdir_p(File.dirname(file))
        File.write(file, contents)
      end

      yield root
    end
  end

  it "verifies the checked-in extract.js is current" do
    stdout, stderr, status = run_build_script("--check")

    expect(status.success?).to be(true), [stdout, stderr].reject(&:empty?).join("\n")
    expect(stdout).to include("Verified")
  end

  it "rebuilds deterministically" do
    with_asset_project(
      manifest: "00_prelude.js\n99_outro.js\n",
      files: {
        "00_prelude.js" => "(function(){\n",
        "99_outro.js" => "window.fetchUtilAssetSmoke = true;\n}());\n"
      }
    ) do |root|
      stdout, stderr, status = run_build_script(root: root)
      expect(status.success?).to be(true), [stdout, stderr].reject(&:empty?).join("\n")

      stdout, stderr, status = run_build_script("--check", root: root)
      expect(status.success?).to be(true), [stdout, stderr].reject(&:empty?).join("\n")
      expect(stdout).to include("Verified")
    end
  end

  it "fails check mode when the manifest lists a source file that does not exist" do
    with_asset_project(manifest: "present.js\nmissing.js\n", files: { "present.js" => "const present = true;\n" }) do |root|
      _stdout, stderr, status = run_build_script("--check", root: root)

      expect(status.success?).to be(false)
      expect(stderr).to include("Manifest entries missing source files: missing.js")
    end
  end

  it "fails check mode when a source file is not listed in the manifest" do
    with_asset_project(
      manifest: "present.js\n",
      files: { "present.js" => "const present = true;\n", "extra.js" => "const extra = true;\n" }
    ) do |root|
      _stdout, stderr, status = run_build_script("--check", root: root)

      expect(status.success?).to be(false)
      expect(stderr).to include("Source files missing from manifest: extra.js")
    end
  end
end
