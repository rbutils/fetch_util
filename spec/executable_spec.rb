# frozen_string_literal: true

require "open3"

RSpec.describe "fetch_util executable" do
  def run_executable(*args)
    root = File.expand_path("..", __dir__)
    executable = File.join(root, "exe", "fetch_util")

    Open3.capture3(RbConfig.ruby, "-I#{File.join(root, "lib")}", executable, *args, chdir: root)
  end

  it "loads the source tree and reports its version" do
    stdout, stderr, status = run_executable("version")

    expect(status).to be_success
    expect(stdout).to eq("#{FetchUtil::VERSION}\n")
    expect(stderr).to be_empty
  end

  it "dispatches help through the executable" do
    stdout, stderr, status = run_executable("--help")

    expect(status).to be_success
    expect(stdout).to include("fetch_util fetch URL [URL...]")
    expect(stdout).to include("fetch_util version")
    expect(stderr).to be_empty
  end

  it "returns a failure status for invalid command options" do
    stdout, stderr, status = run_executable("version", "--format", "invalid")

    expect(status).not_to be_success
    expect(stdout).to be_empty
    expect(stderr).to include("Expected '--format' to be one of markdown, json, jsonl; got invalid")
    expect(stderr).not_to include("Deprecation warning")
  end
end
