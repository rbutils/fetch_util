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

  it "adds a log suffix to an explicitly configured suffixless filename" do
    dir = Dir.mktmpdir
    path = File.join(dir, "requests")
    request_log = described_class.new(path: path)

    request_log.append("https://example.com")

    expect(request_log.path).to eq("#{path}.log")
    expect(File.read("#{path}.log")).to include("https://example.com")
  ensure
    FileUtils.remove_entry(dir) if dir && File.exist?(dir)
  end

  it "preserves explicit log and custom filename suffixes" do
    dir = Dir.mktmpdir

    expect(described_class.new(path: File.join(dir, "requests.LOG")).path).to eq(File.join(dir, "requests.LOG"))
    expect(described_class.new(path: File.join(dir, "requests.jsonl")).path).to eq(File.join(dir, "requests.jsonl"))
    expect(described_class.new(path: File.join(dir, "requests.")).path).to eq(File.join(dir, "requests."))
    expect(described_class.new(path: File.join(dir, ".requests")).path).to eq(File.join(dir, ".requests"))
  ensure
    FileUtils.remove_entry(dir) if dir && File.exist?(dir)
  end

  it "expands an explicitly configured home-relative filename before adding the suffix" do
    request_log = described_class.new(path: "~/fetch-util-requests")

    expect(request_log.path).to eq("#{File.expand_path("~/fetch-util-requests")}.log")
    expect(request_log.path).to be_frozen
  end

  it "preserves the request-log environment path without inferring a filename suffix" do
    path = "~/environment-requests"
    allow(ENV).to receive(:fetch).with("FETCH_UTIL_REQUEST_LOG", described_class::DEFAULT_PATH).and_return(path)

    request_log = described_class.new

    expect(request_log.path).to eq(path)
    expect(request_log.path).to be_frozen
  end

  it "preserves explicit paths without a filename component" do
    ["", "logs/", "logs/.", "logs/.."].each do |path|
      expect(described_class.new(path: path).path).to eq(path)
    end
  end

  it "owns an explicit directory-like path without freezing its caller" do
    path = +"logs/"
    request_log = described_class.new(path: path)

    path.replace("changed/")

    expect(request_log.path).to eq("logs/")
    expect(request_log.path).to be_frozen
    expect(path).not_to be_frozen
  end
end
