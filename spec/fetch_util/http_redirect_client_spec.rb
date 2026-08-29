# frozen_string_literal: true

require "spec_helper"
require "fetch_util/regulatory"
require "fetch_util/regulatory/http_client"

RSpec.describe FetchUtil::HttpRedirectClient do
  def response
    double("response", code: "200", to_hash: { "content-type" => ["text/plain"] }, body: "ok")
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
end
