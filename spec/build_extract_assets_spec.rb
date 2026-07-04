# frozen_string_literal: true

require "open3"

RSpec.describe "extract asset bundle" do
  it "rebuilds deterministically and verifies the built extract.js" do
    root = File.expand_path("..", __dir__)
    script = File.join(root, "script", "build_extract_assets.rb")

    stdout, stderr, status = Open3.capture3(RbConfig.ruby, script, chdir: root)
    expect(status.success?).to be(true), [stdout, stderr].reject(&:empty?).join("\n")

    stdout, stderr, status = Open3.capture3(RbConfig.ruby, script, "--check", chdir: root)

    expect(status.success?).to be(true), [stdout, stderr].reject(&:empty?).join("\n")
    expect(stdout).to include("Verified")
  end
end
