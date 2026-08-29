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

  it "escapes entry delimiters before writing one record" do
    dir = Dir.mktmpdir
    path = File.join(dir, "requests.log")
    allow(Time).to receive(:now).and_return(Time.utc(2026, 8, 29, 12, 34, 56))

    described_class.new(path: path).append("https://example.com/a\tb\r\nforged", duration: 1.2)

    expect(File.read(path)).to eq("2026-08-29T12:34:56Z\thttps://example.com/a\\tb\\r\\nforged\t1.20s\n")
  ensure
    FileUtils.remove_entry(dir) if dir && File.exist?(dir)
  end

  it "owns the output path supplied by the caller" do
    dir = Dir.mktmpdir
    path = File.join(dir, "requests.log")
    original_path = path.dup
    request_log = described_class.new(path: path)

    path.replace(File.join(dir, "mutated.log"))
    request_log.append("https://example.com")

    expect(request_log.path).to eq(original_path)
    expect(request_log.path).to be_frozen
    expect(path).not_to be_frozen
    expect(File.read(original_path)).to include("https://example.com")
    expect(File).not_to exist(path)
  ensure
    FileUtils.remove_entry(dir) if dir && File.exist?(dir)
  end
end
