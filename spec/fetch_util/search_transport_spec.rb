# frozen_string_literal: true

require "zlib"
require "timeout"

class FixtureSearchClient
  def initialize(responses)
    @responses = responses
  end

  def get(_url, **options)
    @responses.fetch(options.fetch(:allowed_hosts).first)
  end
end

class SequentialSearchClient
  attr_reader :deadlines, :urls

  def initialize(responses, on_get: nil)
    @responses = responses.dup
    @deadlines = []
    @urls = []
    @on_get = on_get
  end

  def get(url, deadline:, **_options)
    deadlines << deadline
    urls << url
    @on_get&.call(urls.length)
    @responses.shift || raise("unexpected search request")
  end
end

class BarrierSearchClient
  attr_reader :deadlines, :started

  def initialize(response)
    @response = response
    @deadlines = []
    @started = Queue.new
    @release = Queue.new
  end

  def get(_url, deadline:, allowed_hosts:)
    deadlines << deadline
    started << allowed_hosts.first
    @release.pop
    @response
  end

  def release
    @release << true
  end
end

class FakeSearchHttp
  attr_accessor :use_ssl, :open_timeout, :read_timeout, :write_timeout
  attr_reader :last_request

  def initialize(response)
    @response = response
  end

  def request(request)
    @last_request = request
    yield @response
    @response
  end
end

class BlockingSearchHttp
  attr_accessor :use_ssl, :open_timeout, :read_timeout, :write_timeout

  def request(_request)
    sleep 0.2
  end
end

RSpec.describe FetchUtil::SearchTransport do
  def fixture(name)
    File.read(File.expand_path("../fixtures/search_transport/#{name}.html", __dir__))
  end

  def response(body, status: 200, url: "https://example.test/search")
    FetchUtil::SearchTransport::HttpResponse.new(status: status, headers: {}, body: body, final_url: url)
  end

  it "preserves every eligible card in source DOM order for each adapter" do
    described_class::SOURCES.each_key do |source|
      responses = described_class::SOURCES.each_with_object({}) do |(_name, config), values|
        values[config[:hosts].first] = response(fixture(source))
      end
      client = FixtureSearchClient.new(responses)
      result = described_class.new(sources: [source], http_client: client).search("ruby").first

      expect(result.status).to eq("ok")
      expect(result.candidates.map(&:title)).to eq(["A", "Second result"])
      first_url = source == "brave" ? "https://one.example/path" : "https://one.example/"
      expect(result.candidates.map(&:url)).to eq([first_url, "https://two.example/"])
      expect(result.candidates.map(&:snippet)).to eq(["First detail", "Second detail"])
      expect(result.candidates.map(&:source_rank)).to eq([1, 2])
    end
  end

  it "reports truthful empty and challenge states" do
    client = FixtureSearchClient.new(
      {
        "www.google.com" => response(fixture("no_results")),
        "html.duckduckgo.com" => response(fixture("challenge"), status: 202)
      }
    )
    responses = described_class.new(sources: %w[google duckduckgo], http_client: client).search("ruby")

    expect(responses.map { |item| [item.status, item.reason] }).to eq([["empty", nil], %w[failed challenge]])
  end

  it "keeps configured response order and preserves peer results when one source fails" do
    client = FixtureSearchClient.new(
      {
        "www.google.com" => FetchUtil::SearchTransport::HttpFailure.new(reason: "timeout", final_url: "https://www.google.com/search"),
        "www.bing.com" => response(fixture("bing"))
      }
    )
    responses = described_class.new(sources: %w[google bing], http_client: client).search("ruby")

    expect(responses.map(&:source)).to eq(%w[google bing])
    expect(responses.map(&:status)).to eq(%w[failed ok])
  end

  it "starts source requests concurrently with one shared deadline" do
    client = BarrierSearchClient.new(response(fixture("bing")))
    transport = described_class.new(sources: %w[google bing], timeout: 5, http_client: client)
    worker = Thread.new { transport.search("ruby") }

    started = Timeout.timeout(1) { [client.started.pop, client.started.pop] }
    2.times { client.release }
    responses = worker.value

    expect(started).to contain_exactly("www.google.com", "www.bing.com")
    expect(client.deadlines.uniq.length).to eq(1)
    expect(responses.map(&:source)).to eq(%w[google bing])
  end

  it "classifies challenge fixtures as failures for every source" do
    described_class::SOURCES.each_key do |source|
      client = FixtureSearchClient.new({ described_class::SOURCES.fetch(source).fetch(:hosts).first => response(fixture("challenge")) })
      result = described_class.new(sources: [source], http_client: client).search("ruby").first

      expect(result).to have_attributes(status: "failed", reason: "challenge")
    end
  end

  it "normalizes unexpected transport failures without exposing exceptions" do
    client = Object.new
    client.define_singleton_method(:get) { |_url, **_options| raise "private transport detail" }

    result = described_class.new(sources: ["brave"], http_client: client).search("ruby").first
    expect(result).to have_attributes(status: "failed", reason: "failed")
  end

  it "rejects degraded cards that only match a question word" do
    client = FixtureSearchClient.new({ "www.bing.com" => response(fixture("bing_degraded_why")) })
    result = described_class.new(sources: ["bing"], http_client: client).search("why do octopuses have three hearts?").first

    expect(result).to have_attributes(status: "failed", candidates: [], reason: "query_mismatch")
  end

  it "accepts relevant multi-term results and bypasses scoped or one meaningful-term searches" do
    relevant_client = FixtureSearchClient.new({ "www.bing.com" => response(fixture("bing_relevant")) })
    one_term_client = FixtureSearchClient.new({ "www.bing.com" => response(fixture("bing_degraded_why")) })

    relevant = described_class.new(sources: ["bing"], http_client: relevant_client).search("why do octopuses have three hearts").first
    site_scoped = described_class.new(sources: ["bing"], http_client: one_term_client).search("site:biology.example octopuses").first
    one_term = described_class.new(sources: ["bing"], http_client: one_term_client).search("why").first

    expect(relevant).to have_attributes(status: "ok", reason: nil)
    expect(site_scoped).to have_attributes(status: "ok", reason: nil)
    expect(one_term).to have_attributes(status: "ok", reason: nil)
  end

  it "rejects a source when only a later candidate is relevant" do
    client = FixtureSearchClient.new({ "www.bing.com" => response(fixture("bing_late_relevant")) })
    result = described_class.new(sources: ["bing"], http_client: client).search("ruby http client documentation").first

    expect(result).to have_attributes(status: "failed", candidates: [], reason: "query_mismatch")
  end

  it "bypasses quoted, identifier, acronym, and code-like queries" do
    client = FixtureSearchClient.new({ "www.bing.com" => response(fixture("bing_degraded_why")) })
    transport = described_class.new(sources: ["bing"], http_client: client)

    ["\"octopuses three hearts\"", "-site:biology.example octopuses three hearts", "C++ language guide", "GPT-4 API guide", "U.S. tax guide"].each do |query|
      expect(transport.search(query).first).to have_attributes(status: "ok", reason: nil)
    end
  end

  it "retries two Yahoo availability responses before succeeding with the exact URL and deadline" do
    client = SequentialSearchClient.new(
      [
        response("", status: 503),
        response("", status: 429),
        response(fixture("yahoo"), url: "https://search.yahoo.com/search?p=ruby+%22http+client%22")
      ]
    )
    query = 'ruby "http client"'

    result = described_class.new(sources: ["yahoo"], timeout: 5, http_client: client).search(query).first

    expect(result).to have_attributes(status: "ok", source: "yahoo")
    expect(client.urls).to eq(["https://search.yahoo.com/search?p=ruby+%22http+client%22"] * 3)
    expect(client.deadlines.uniq.length).to eq(1)
  end

  it "retries a transient Yahoo failed transport before succeeding" do
    client = SequentialSearchClient.new(
      [
        FetchUtil::SearchTransport::HttpFailure.new(reason: "failed", final_url: "https://search.yahoo.com/search"),
        response(fixture("yahoo"))
      ]
    )

    result = described_class.new(sources: ["yahoo"], http_client: client).search("ruby").first

    expect(result).to have_attributes(status: "ok", source: "yahoo")
    expect(client.urls.length).to eq(2)
  end

  it "does not retry a Yahoo 403 challenge-like response" do
    client = SequentialSearchClient.new([response(fixture("challenge"), status: 403)])

    result = described_class.new(sources: ["yahoo"], http_client: client).search("ruby").first

    expect(result).to have_attributes(status: "failed", reason: "challenge")
    expect(client.urls.length).to eq(1)
  end

  it "bounds Yahoo availability recovery at two attempts after the initial request" do
    client = SequentialSearchClient.new([response("", status: 503)] * 3)

    result = described_class.new(sources: ["yahoo"], http_client: client).search("ruby").first

    expect(result).to have_attributes(status: "failed", reason: "http_status")
    expect(client.urls.length).to eq(3)
  end

  it "does not retry Yahoo after the shared deadline expires" do
    now = 0.0
    client = SequentialSearchClient.new(
      [response("", status: 503), response(fixture("yahoo"))],
      on_get: ->(_count) { now = 2.0 }
    )

    result = described_class.new(
      sources: ["yahoo"], timeout: 1, clock: -> { now }, http_client: client
    ).search("ruby").first

    expect(result).to have_attributes(status: "failed", reason: "timeout")
    expect(client.urls.length).to eq(1)
  end

  it "matches a relevant title when the candidate has no snippet" do
    candidate = described_class::Candidate.new(
      source: "bing", title: "Octopuses have three hearts", url: "https://biology.example/octopuses", snippet: nil, source_rank: 1
    )

    expect(described_class.new.send(:query_matches_candidates?, "why do octopuses have three hearts", [candidate])).to be(true)
  end

  it "matches Unicode terms through mixed punctuation" do
    client = FixtureSearchClient.new({ "www.bing.com" => response(fixture("bing_unicode")) })
    result = described_class.new(sources: ["bing"], http_client: client).search("cafe\u0301 東京 culture?").first

    expect(result).to have_attributes(status: "ok", reason: nil)
  end

  it "keeps query mismatch in finite failure reason normalization" do
    transport = described_class.new

    expect(transport.send(:failure, "bing", "query_mismatch", 0, nil).reason).to eq("query_mismatch")
  end

  it "decodes DuckDuckGo absolute and protocol-relative wrappers" do
    client = FixtureSearchClient.new({ "html.duckduckgo.com" => response(fixture("duckduckgo_wrappers")) })
    result = described_class.new(sources: ["duckduckgo"], http_client: client).search("ruby").first

    expect(result.candidates.map(&:url)).to eq(["https://one.example/", "https://two.example/"])
  end

  it "does not duplicate nested Google result cards" do
    client = FixtureSearchClient.new({ "www.google.com" => response(fixture("google_nested")) })
    result = described_class.new(sources: ["google"], http_client: client).search("ruby").first

    expect(result.candidates.map(&:title)).to eq(["A", "Second result"])
    expect(result.candidates.map(&:source_rank)).to eq([1, 2])
  end

  it "decodes known Google wrappers without rewriting foreign lookalikes" do
    transport = described_class.new
    expect(transport.send(:destination, "google", "https://google.com/url?q=https%3A%2F%2Fone.example%2F")).to eq("https://one.example/")
    expect(transport.send(:destination, "google", "https://evil.example/url?q=https%3A%2F%2Fone.example%2F")).to eq("https://evil.example/url?q=https%3A%2F%2Fone.example%2F")
  end

  it "does not decode a foreign Bing lookalike" do
    encoded = Base64.strict_encode64("https://one.example/")
    transport = described_class.new

    expect(transport.send(:destination, "bing", "https://evil.example/ck/a?u=a1#{encoded}")).to eq("https://evil.example/ck/a?u=a1#{encoded}")
  end

  it "classifies Google sorry 403 as a challenge but ordinary errors as http status failures" do
    client = FixtureSearchClient.new(
      {
        "www.google.com" => response(fixture("challenge"), status: 403, url: "https://www.google.com/sorry/index"),
        "www.bing.com" => response("<html></html>", status: 403, url: "https://www.bing.com/search")
      }
    )
    results = described_class.new(sources: %w[google bing], http_client: client).search("ruby")

    expect(results.map(&:reason)).to eq(%w[challenge http_status])
  end

  it "does not treat script-only CAPTCHA text as a challenge" do
    client = FixtureSearchClient.new({ "search.brave.com" => response(fixture("brave_script_captcha")) })
    result = described_class.new(sources: ["brave"], http_client: client).search("ruby").first

    expect(result).to have_attributes(status: "ok")
    expect(result.candidates.map(&:title)).to eq(["A", "Second result"])
  end

  it "parses once before challenge inspection" do
    calls = 0
    parser = lambda do |body|
      calls += 1
      Nokogiri::HTML(body)
    end
    client = FixtureSearchClient.new({ "search.brave.com" => response(fixture("challenge")) })
    result = described_class.new(sources: ["brave"], http_client: client, html_parser: parser).search("ruby").first

    expect(result).to have_attributes(status: "failed", reason: "challenge")
    expect(calls).to eq(1)
  end

  it "maps challenge inspection deadline exhaustion to timeout" do
    now = 0.0
    client = FixtureSearchClient.new({ "search.brave.com" => response(fixture("brave")) })
    transport = described_class.new(sources: ["brave"], timeout: 1, clock: -> { now }, http_client: client)
    allow(transport).to receive(:challenge?) do
      now = 2.0
      false
    end

    result = transport.search("ruby").first
    expect(result).to have_attributes(status: "failed", reason: "timeout")
  end

  it "extracts only current Brave organic web cards in DOM order" do
    client = FixtureSearchClient.new({ "search.brave.com" => response(fixture("brave_current")) })
    result = described_class.new(sources: ["brave"], http_client: client).search("ruby").first

    expect(result).to have_attributes(status: "ok")
    expect(result.candidates.map(&:title)).to eq(["First live result", "Second live result"])
    expect(result.candidates.map(&:url)).to eq(["https://one.example/live", "https://two.example/live"])
    expect(result.candidates.map(&:snippet)).to eq(["First live detail", "Second live detail"])
    expect(result.candidates.map(&:source_rank)).to eq([1, 2])
  end

  it "builds Bing URLs with stable English-US locale parameters" do
    url = described_class.new.send(:build_url, "bing", "full query")

    expect(url).to eq("https://www.bing.com/search?q=full+query&setlang=en-US&cc=US")
  end

  it "builds Yahoo URLs with exact query encoding" do
    url = described_class.new.send(:build_url, "yahoo", 'ruby "http client"')

    expect(url).to eq("https://search.yahoo.com/search?p=ruby+%22http+client%22")
  end

  it "decodes only valid Yahoo RU wrappers" do
    transport = described_class.new
    wrapper = "https://r.search.yahoo.com/_ylt=abc/RU=https%3A%2F%2Fone.example%2Fpath%3Fa%3Db/RK=2/RS=x"

    expect(transport.send(:destination, "yahoo", wrapper)).to eq("https://one.example/path?a=b")
    expect(transport.send(:destination, "yahoo", "https://evil.example/RU=https%3A%2F%2Fone.example%2F")).to eq(
      "https://evil.example/RU=https%3A%2F%2Fone.example%2F"
    )
    expect(transport.send(:destination, "yahoo", "https://r.search.yahoo.com/RU=javascript%3Aalert(1)")).to be_nil
    expect(transport.send(:destination, "yahoo", "https://r.search.yahoo.com/RU=%ZZ")).to be_nil
  end

  it "maps parsing deadline exhaustion to timeout" do
    now = 0.0
    client = FixtureSearchClient.new({ "search.brave.com" => response(fixture("brave")) })
    parser = lambda do |body|
      now = 2.0
      Nokogiri::HTML(body)
    end
    result = described_class.new(sources: ["brave"], timeout: 1, clock: -> { now }, http_client: client,
                                 html_parser: parser).search("ruby").first

    expect(result).to have_attributes(status: "failed", reason: "timeout")
  end

  it "includes parsing time in successful and empty response elapsed time" do
    now = 0.0
    parser = lambda do |body|
      now += 0.25
      Nokogiri::HTML(body)
    end
    client = FixtureSearchClient.new(
      {
        "search.brave.com" => response(fixture("brave")),
        "www.google.com" => response(fixture("no_results"))
      }
    )

    success = described_class.new(sources: ["brave"], timeout: 1, clock: -> { now }, http_client: client,
                                  html_parser: parser).search("ruby").first
    now = 0.0
    empty = described_class.new(sources: ["google"], timeout: 1, clock: -> { now }, http_client: client,
                                html_parser: parser).search("ruby").first

    expect(success).to have_attributes(status: "ok", elapsed_ms: 250)
    expect(empty).to have_attributes(status: "empty", elapsed_ms: 250)
  end

  it "maps candidate extraction deadline exhaustion to timeout" do
    now = 0.0
    client = FixtureSearchClient.new({ "search.brave.com" => response(fixture("brave")) })
    transport = described_class.new(sources: ["brave"], timeout: 1, clock: -> { now }, http_client: client)
    allow(transport).to receive(:parse_candidates) do
      now = 2.0
      []
    end

    result = transport.search("ruby").first
    expect(result).to have_attributes(status: "failed", reason: "timeout")
  end

  describe FetchUtil::SearchTransport::HttpClient do
    def http_response(type, code, headers: {}, chunks: [], after_chunk: nil)
      response = type.new("1.1", code.to_s, "Test")
      headers.each { |name, value| response[name] = value }
      response.define_singleton_method(:read_body) do |&block|
        chunks.each do |chunk|
          block.call(chunk)
          after_chunk&.call
        end
      end
      response
    end

    it "decodes compressed bytes and replaces invalid charset bytes" do
      client = described_class.new
      compressed = StringIO.new
      Zlib::GzipWriter.wrap(compressed) { |gzip| gzip.write("caf\xE9".b) }
      text = client.send(:decode, compressed.string, "gzip", "text/html; charset=ISO-8859-1", Float::INFINITY)

      expect(text).to eq(["636166c3a9"].pack("H*").force_encoding("UTF-8"))
    end

    it "falls back safely for malformed declared charsets and detects meta charsets" do
      client = described_class.new
      malformed = client.send(:decode, "plain text".b, "", "text/html; charset=no-such-charset", Float::INFINITY)
      meta = client.send(:decode, "<meta charset=ISO-8859-1>caf\xE9".b, "", "text/html", Float::INFINITY)

      expect(malformed).to eq("plain text")
      expect(meta).to eq(["3c6d65746120636861727365743d49534f2d383835392d313e636166c3a9"].pack("H*").force_encoding("UTF-8"))
    end

    it "detects deadline exhaustion after post-network decode work" do
      now = 0.0
      client = described_class.new(clock: -> { now })
      allow(client).to receive(:inflate) do
        now = 2.0
        +"decoded"
      end

      expect { client.send(:decode, "", "", "text/html", 1.0) }.to raise_error(described_class::DeadlineExceeded)
    end

    it "rejects expired deadlines before issuing a request" do
      client = described_class.new(clock: -> { 10.0 })
      result = client.get("https://www.google.com/search", deadline: 9.0, allowed_hosts: ["www.google.com"])

      expect(result).to eq(FetchUtil::SearchTransport::HttpFailure.new(reason: "timeout", final_url: "https://www.google.com/search"))
    end

    it "bounds a request that never yields a response chunk" do
      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      client = described_class.new(net_http: ->(_uri) { BlockingSearchHttp.new })
      result = client.get("https://www.google.com/search", deadline: started_at + 0.03, allowed_hosts: ["www.google.com"])
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at

      expect(result.reason).to eq("timeout")
      expect(elapsed).to be < 0.15
    end

    it "sends stable search request headers" do
      response = http_response(Net::HTTPOK, 200, chunks: ["<html></html>"])
      http = FakeSearchHttp.new(response)
      client = described_class.new(net_http: ->(_uri) { http })

      client.get("https://www.google.com/search", deadline: Float::INFINITY, allowed_hosts: ["www.google.com"])
      expect(http.last_request["Accept-Language"]).to eq("en-US,en;q=0.9")
      expect(http.last_request["User-Agent"]).to eq("fetch_util")
    end

    it "follows allowed relative redirects and rejects redirected hosts outside the allowlist" do
      redirect = http_response(Net::HTTPFound, 302, headers: { "location" => "/next" })
      success = http_response(Net::HTTPOK, 200, chunks: ["<html></html>"])
      connections = [FakeSearchHttp.new(redirect), FakeSearchHttp.new(success)]
      client = described_class.new(net_http: ->(_uri) { connections.shift })

      result = client.get("https://www.google.com/search", deadline: Float::INFINITY, allowed_hosts: ["www.google.com"])
      expect(result.final_url).to eq("https://www.google.com/next")

      blocked = http_response(Net::HTTPFound, 302, headers: { "location" => "https://outside.example/" })
      client = described_class.new(net_http: ->(_uri) { FakeSearchHttp.new(blocked) })
      result = client.get("https://www.google.com/search", deadline: Float::INFINITY, allowed_hosts: ["www.google.com"])
      expect(result.reason).to eq("host")
    end

    it "reports malformed redirect locations as redirect failures" do
      redirect = http_response(Net::HTTPFound, 302, headers: { "location" => "http://[invalid" })
      client = described_class.new(net_http: ->(_uri) { FakeSearchHttp.new(redirect) })

      result = client.get("https://www.google.com/search", deadline: Float::INFINITY, allowed_hosts: ["www.google.com"])
      expect(result.reason).to eq("redirect")
    end

    it "enforces compressed and decoded response size ceilings" do
      compressed = StringIO.new
      Zlib::GzipWriter.wrap(compressed) { |gzip| gzip.write("abcdefgh") }
      response = http_response(Net::HTTPOK, 200,
                               headers: { "content-encoding" => "gzip", "content-type" => "text/html; charset=utf-8" },
                               chunks: [compressed.string])
      client = described_class.new(max_response_bytes: 4, net_http: ->(_uri) { FakeSearchHttp.new(response) })

      result = client.get("https://www.google.com/search", deadline: Float::INFINITY, allowed_hosts: ["www.google.com"])
      expect(result.reason).to eq("size")
    end

    it "bounds gzip and deflate expansion while decoding" do
      payload = "x" * 512
      gzip = StringIO.new
      Zlib::GzipWriter.wrap(gzip) { |writer| writer.write(payload) }
      deflated = Zlib::Deflate.deflate(payload)

      [["gzip", gzip.string], ["deflate", deflated]].each do |encoding, compressed|
        response = http_response(Net::HTTPOK, 200, headers: { "content-encoding" => encoding }, chunks: [compressed])
        client = described_class.new(max_response_bytes: 64, net_http: ->(_uri) { FakeSearchHttp.new(response) })
        result = client.get("https://www.google.com/search", deadline: Float::INFINITY, allowed_hosts: ["www.google.com"])

        expect(result.reason).to eq("size")
      end
    end

    it "stops a response stream and redirect chain when the shared deadline expires" do
      now = 0.0
      clock = -> { now }
      drip = http_response(Net::HTTPOK, 200, chunks: %w[one two], after_chunk: -> { now = 2.0 })
      client = described_class.new(clock: clock, net_http: ->(_uri) { FakeSearchHttp.new(drip) })
      result = client.get("https://www.google.com/search", deadline: 1.0, allowed_hosts: ["www.google.com"])
      expect(result.reason).to eq("timeout")

      now = 0.0
      redirect = http_response(Net::HTTPFound, 302, headers: { "location" => "/next" }, chunks: [""], after_chunk: -> { now = 2.0 })
      client = described_class.new(clock: clock, net_http: ->(_uri) { FakeSearchHttp.new(redirect) })
      result = client.get("https://www.google.com/search", deadline: 1.0, allowed_hosts: ["www.google.com"])
      expect(result.reason).to eq("timeout")
    end
  end
end
