# frozen_string_literal: true

require "spec_helper"
require "fetch_util/regulatory"
require "fetch_util/regulatory/http_client"

RSpec.describe FetchUtil::HttpRedirectClient do
  def response
    double("response", code: "200", to_hash: { "content-type" => ["text/plain"] }, body: "ok")
  end

  def redirect_response(location)
    Net::HTTPFound.new("1.1", "302", "Found").tap do |response|
      response["location"] = location
      allow(response).to receive(:body).and_return("")
    end
  end

  def success_response
    Net::HTTPOK.new("1.1", "200", "OK").tap do |response|
      allow(response).to receive(:body).and_return("ok")
    end
  end

  it "preserves a successful response when connection cleanup fails" do
    http = instance_double(Net::HTTP, request: response, started?: true)
    allow(http).to receive(:finish).and_raise(SocketError, "close failed")
    allow(Net::HTTP).to receive(:start).and_return(http)
    client = described_class.new(timeout: 1)

    result = client.get("https://example.com/resource")

    expect(result).to have_attributes(status: 200, body: "ok")
    expect(client.instance_variable_get(:@connections)).to be_nil
  end

  it "retries a request when closing its failed connection also fails" do
    failed_http = instance_double(Net::HTTP, started?: true)
    successful_http = instance_double(Net::HTTP, request: response, started?: true)
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
    expect(client.instance_variable_get(:@connections)).to be_nil
  end

  it "follows relative and cross-host HTTP redirects" do
    client = described_class.new(timeout: 1)
    allow(client).to receive(:request).and_return(
      redirect_response("/next"),
      redirect_response("https://cdn.example.test/final"),
      success_response
    )

    result = client.get("https://example.com/start")

    expect(result).to have_attributes(url: "https://cdn.example.test/final", status: 200, body: "ok")
    expect(result.redirects.map(&:url)).to eq(["https://example.com/start", "https://example.com/next"])
    expect(client).to have_received(:request).with(URI("https://example.com/start")).ordered
    expect(client).to have_received(:request).with(URI("https://example.com/next")).ordered
    expect(client).to have_received(:request).with(URI("https://cdn.example.test/final")).ordered
  end

  it "rejects redirects to unsupported or hostless URLs" do
    ["ftp://example.test/file", "file:///etc/passwd", "https:///missing-host"].each do |location|
      client = described_class.new(timeout: 1)
      allow(client).to receive(:request).and_return(redirect_response(location))

      expect do
        client.get("https://example.com/start")
      end.to raise_error(URI::InvalidURIError, "unsupported url: #{location}")
      expect(client).to have_received(:request).once
    end
  end
end
