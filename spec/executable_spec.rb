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
end
