# frozen_string_literal: true

require "fileutils"
require "tmpdir"

RSpec.describe FetchUtil::RequestLog do
  it "appends timestamped entries" do
    dir = Dir.mktmpdir
    path = File.join(dir, "requests.log")

    described_class.new(path: path).append("https://example.com")

    content = File.read(path)
    expect(content).to include("https://example.com")
    expect(content).to match(/^\d{4}-\d{2}-\d{2}T/)
  ensure
    FileUtils.remove_entry(dir) if dir && File.exist?(dir)
  end

  it "includes duration when provided" do
    dir = Dir.mktmpdir
    path = File.join(dir, "requests.log")

    described_class.new(path: path).append("https://example.com", duration: 3.456)

    content = File.read(path)
    expect(content).to match(%r{https://example\.com\t3\.46s$})
  ensure
    FileUtils.remove_entry(dir) if dir && File.exist?(dir)
  end

  it "omits duration column when not provided" do
    dir = Dir.mktmpdir
    path = File.join(dir, "requests.log")

    described_class.new(path: path).append("https://example.com")

    line = File.read(path).strip
    expect(line.split("\t").length).to eq(2)
  ensure
    FileUtils.remove_entry(dir) if dir && File.exist?(dir)
  end
end
