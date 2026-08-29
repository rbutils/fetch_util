# frozen_string_literal: true

require "spec_helper"
require "open3"
require "rbconfig"
require "fetch_util/http_redirect_client"

RSpec.describe FetchUtil::HttpRedirectClient do
  it "loads without materializing the regulatory subsystem" do
    root = File.expand_path("../..", __dir__)
    script = <<~RUBY
      require "fetch_util"
      require "fetch_util/http_redirect_client"
      abort "regulatory subsystem loaded" unless FetchUtil.autoload?(:Regulatory)
    RUBY

    _stdout, stderr, status = Open3.capture3(RbConfig.ruby, "-I#{File.join(root, "lib")}", "-e", script, chdir: root)

    expect(stderr).to be_empty
    expect(status).to be_success
  end

  def response(*chunks)
    double("response", code: "200", to_hash: { "content-type" => ["text/plain"] }).tap do |response|
      allow(response).to receive(:read_body) do |&block|
        chunks.each(&block)
      end
    end
  end

  def streaming_http(incoming)
    instance_double(Net::HTTP, started?: true).tap do |http|
      allow(http).to receive(:request) do |_request, &block|
        block.call(incoming)
        incoming
      end
    end
  end

  def redirect_response(location)
    Net::HTTPFound.new("1.1", "302", "Found").tap do |response|
      response["location"] = location
    end
  end

  def success_response
    Net::HTTPOK.new("1.1", "200", "OK")
  end

  it "requires a finite positive timeout" do
    [nil, "", "invalid", 0, -1, Float::INFINITY, Float::NAN].each do |timeout|
      expect do
        described_class.new(timeout: timeout)
      end.to raise_error(ArgumentError, "timeout must be positive")
    end
  end

  it "preserves fractional timeout budgets" do
    client = described_class.new(timeout: 0.25)

    expect(client.send(:timeout)).to eq(0.25)
  end

  it "owns immutable request headers" do
    key = +"X-Client-Name"
    value = +"initial"
    client = described_class.new(timeout: 1, headers: { key => value })
    incoming = response("ok")
    http = streaming_http(incoming)
    request = nil
    allow(http).to receive(:request) do |sent_request, &block|
      request = sent_request
      block.call(incoming)
      incoming
    end
    allow(http).to receive(:finish)
    allow(Net::HTTP).to receive(:start).and_return(http)

    key.replace("X-Changed")
    value.replace("changed")
    client.get("https://example.com/resource")

    expect(request["X-Client-Name"]).to eq("initial")
    expect(request["X-Changed"]).to be_nil
    expect(client.send(:headers)).to be_frozen
    expect(client.send(:headers).keys + client.send(:headers).values).to all(be_frozen)
  end

  it "preserves a successful response when connection cleanup fails" do
    http = streaming_http(response("ok"))
    allow(http).to receive(:finish).and_raise(SocketError, "close failed")
    allow(Net::HTTP).to receive(:start).and_return(http)
    client = described_class.new(timeout: 1)

    result = client.get("https://example.com/resource")

    expect(result).to have_attributes(status: 200, body: "ok")
  end

  it "retries a request when closing its failed connection also fails" do
    failed_http = instance_double(Net::HTTP, started?: true)
    successful_http = streaming_http(response("ok"))
    allow(failed_http).to receive(:request).and_raise(SocketError, "request failed")
    allow(failed_http).to receive(:finish).and_raise(Timeout::Error, "close failed")
    allow(successful_http).to receive(:finish)
    allow(Net::HTTP).to receive(:start).and_return(failed_http, successful_http)
    client = described_class.new(timeout: 1)

    result = client.get("https://example.com/resource")

    expect(result).to have_attributes(status: 200, body: "ok")
    expect(Net::HTTP).to have_received(:start).twice
  end

  it "preserves a request error when connection cleanup also fails" do
    http = instance_double(Net::HTTP, started?: true)
    allow(http).to receive(:request).and_raise(FetchUtil::Error, "request failed")
    allow(http).to receive(:finish).and_raise(SocketError, "close failed")
    allow(Net::HTTP).to receive(:start).and_return(http)
    client = described_class.new(timeout: 1)

    expect do
      client.get("https://example.com/resource")
    end.to raise_error(FetchUtil::Error, "request failed")
    expect(http).to have_received(:finish)
  end

  it "keeps overlapping request connections independent" do
    first_started = Queue.new
    release_first = Queue.new
    first_response = response("first")
    first_http = instance_double(Net::HTTP, started?: true)
    allow(first_http).to receive(:request) do |_request, &block|
      first_started << true
      release_first.pop
      block.call(first_response)
      first_response
    end
    allow(first_http).to receive(:finish)

    second_http = streaming_http(response("second"))
    allow(second_http).to receive(:finish)
    allow(Net::HTTP).to receive(:start).and_return(first_http, second_http)
    client = described_class.new(timeout: 1)

    first_thread = Thread.new { client.get("https://example.com/first") }
    first_started.pop
    begin
      second_result = client.get("https://example.com/second")
    ensure
      release_first << true
      first_thread.join
    end
    first_result = first_thread.value

    expect(first_result).to have_attributes(status: 200, body: "first")
    expect(second_result).to have_attributes(status: 200, body: "second")
    expect(first_http).to have_received(:finish).once
    expect(second_http).to have_received(:finish).once
  end

  it "follows relative and cross-host HTTP redirects" do
    client = described_class.new(timeout: 1)
    allow(client).to receive(:request).and_return(
      [redirect_response("/next"), ""],
      [redirect_response("https://cdn.example.test/final"), ""],
      [success_response, "ok"]
    )

    result = client.get("https://example.com/start")

    expect(result).to have_attributes(url: "https://cdn.example.test/final", status: 200, body: "ok")
    expect(result.redirects.map(&:url)).to eq(["https://example.com/start", "https://example.com/next"])
    expect(client).to have_received(:request).with(URI("https://example.com/start"), kind_of(Hash)).ordered
    expect(client).to have_received(:request).with(URI("https://example.com/next"), kind_of(Hash)).ordered
    expect(client).to have_received(:request).with(URI("https://cdn.example.test/final"), kind_of(Hash)).ordered
  end

  it "rejects redirects to unsupported or hostless URLs" do
    ["ftp://example.test/file", "file:///etc/passwd", "https:///missing-host"].each do |location|
      client = described_class.new(timeout: 1)
      allow(client).to receive(:request).and_return([redirect_response(location), ""])

      expect do
        client.get("https://example.com/start")
      end.to raise_error(URI::InvalidURIError, "unsupported url: #{location}")
      expect(client).to have_received(:request).once
    end
  end

  it "accepts response bodies at the configured byte limit" do
    http = streaming_http(response("ab", "cd"))
    allow(http).to receive(:finish)
    allow(Net::HTTP).to receive(:start).and_return(http)

    result = described_class.new(timeout: 1, max_response_bytes: 4).get("https://example.com/resource")

    expect(result.body).to eq("abcd")
  end

  it "rejects response bodies above the configured byte limit" do
    http = streaming_http(response("abcd", "e"))
    allow(http).to receive(:finish)
    allow(Net::HTTP).to receive(:start).and_return(http)
    client = described_class.new(timeout: 1, max_response_bytes: 4)

    expect do
      client.get("https://example.com/resource")
    end.to raise_error(FetchUtil::Error, "response body exceeds 4 bytes for https://example.com/resource")
  end

  it "rejects an overflowing chunk before buffering it" do
    overflowing_chunk = Class.new do
      attr_reader :buffered

      def bytesize
        1
      end

      def to_str
        @buffered = true
        "e"
      end
    end.new
    http = streaming_http(response("abcd", overflowing_chunk))
    allow(http).to receive(:finish)
    allow(Net::HTTP).to receive(:start).and_return(http)
    client = described_class.new(timeout: 1, max_response_bytes: 4)

    expect do
      client.get("https://example.com/resource")
    end.to raise_error(FetchUtil::Error, "response body exceeds 4 bytes for https://example.com/resource")
    expect(overflowing_chunk.buffered).to be_nil
  end

  it "requires a positive response byte limit" do
    [nil, 0, -1, Float::INFINITY, Float::NAN].each do |limit|
      expect do
        described_class.new(timeout: 1, max_response_bytes: limit)
      end.to raise_error(ArgumentError, "max_response_bytes must be positive")
    end
  end
end
