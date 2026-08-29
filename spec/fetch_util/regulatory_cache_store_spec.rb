# frozen_string_literal: true

require "spec_helper"
require "fetch_util/regulatory"
require "tmpdir"

RSpec.describe FetchUtil::Regulatory::CacheStore do
  let(:store) { Class.new { include FetchUtil::Regulatory::CacheStore }.new }
  let(:directory) { Dir.mktmpdir }
  let(:path) { File.join(directory, "cache.json") }

  after do
    FileUtils.remove_entry(directory) if File.exist?(directory)
  end

  it "publishes a complete cache entry with one atomic rename" do
    payload = { "items" => %w[one two] }
    allow(File).to receive(:rename).and_wrap_original do |rename, temporary_path, final_path|
      expect(final_path).to eq(path)
      expect(File).not_to exist(final_path)
      expect(JSON.parse(File.read(temporary_path))).to include("payload" => payload)
      rename.call(temporary_path, final_path)
    end

    store.send(:write_cache, path, payload)

    expect(JSON.parse(File.read(path))).to include("payload" => payload)
    expect(File).to have_received(:rename).once
    expect(Dir.children(directory)).to eq(["cache.json"])
  end

  it "preserves an existing cache file when publication fails" do
    File.write(path, "existing cache")
    allow(File).to receive(:rename).and_raise(Errno::EACCES, path)

    expect do
      store.send(:write_cache, path, { "replacement" => true })
    end.to raise_error(Errno::EACCES)

    expect(File.read(path)).to eq("existing cache")
    expect(Dir.children(directory)).to eq(["cache.json"])
  end

  it "preserves the mode of an existing cache file" do
    File.write(path, "existing cache")
    File.chmod(0o640, path)

    store.send(:write_cache, path, { "replacement" => true })

    expect(File.stat(path).mode & 0o777).to eq(0o640)
  end

  it "ignores JSON cache roots that are not objects" do
    [[], "cache", 1, false, nil].each do |value|
      File.write(path, JSON.generate(value))

      expect(store.send(:read_cache, path)).to be_nil
    end
  end
end
