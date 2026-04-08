# frozen_string_literal: true

require "json"
require "stringio"

RSpec.describe FetchUtil::CLI do
  def capture_stdout
    original = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original
  end

  it "fetches multiple urls in parallel and prints jsonl" do
    first = instance_double(
      FetchUtil::Result,
      to_h: {
        url: "https://a.test",
        final_url: "https://a.test/final",
        canonical_url: "https://a.test/canonical",
        title: "A",
        excerpt: "about a",
        byline: nil,
        markdown: "body a",
        content_type: "article",
        suspect: false,
        warnings: [],
        metadata: { noisy: true },
        reader_mode: true,
        html: "<p>A</p>"
      }
    )
    second = instance_double(
      FetchUtil::Result,
      to_h: {
        url: "https://b.test",
        final_url: "https://b.test/final",
        canonical_url: "https://b.test/canonical",
        title: "B",
        excerpt: "about b",
        byline: nil,
        markdown: "body b",
        content_type: "article",
        suspect: true,
        warnings: ["warning"],
        metadata: { noisy: true },
        reader_mode: true,
        html: "<p>B</p>"
      }
    )
    request_log = instance_double(FetchUtil::RequestLog, append: nil)

    expect(FetchUtil).to receive(:fetch_many).with(
      ["https://a.test", "https://b.test"],
      timeout: 20,
      wait: 0.75,
      wait_for_idle: true,
      reader_mode: true,
      request_log: request_log,
      concurrency: 4
    ).and_return([first, second])

    allow(FetchUtil::RequestLog).to receive(:new).and_return(request_log)

    output = capture_stdout do
      described_class.start(["fetch", "https://a.test", "https://b.test", "--format", "jsonl"])
    end

    expect(output.lines.map { |line| JSON.parse(line, symbolize_names: true) }).to eq([
                                                                                        {
                                                                                          url: "https://a.test",
                                                                                          final_url: "https://a.test/final",
                                                                                          canonical_url: "https://a.test/canonical",
                                                                                          title: "A",
                                                                                          markdown: "body a",
                                                                                          content_type: "article",
                                                                                          suspect: false,
                                                                                          warnings: []
                                                                                        },
                                                                                        {
                                                                                          url: "https://b.test",
                                                                                          final_url: "https://b.test/final",
                                                                                          canonical_url: "https://b.test/canonical",
                                                                                          title: "B",
                                                                                          markdown: "body b",
                                                                                          content_type: "article",
                                                                                          suspect: true,
                                                                                          warnings: ["warning"]
                                                                                        }
                                                                                      ])
  end

  it "includes html only when requested" do
    result = instance_double(
      FetchUtil::Result,
      to_h: {
        url: "https://a.test",
        final_url: "https://a.test/final",
        canonical_url: "https://a.test/canonical",
        title: "A",
        excerpt: "about a",
        byline: nil,
        markdown: "body a",
        content_type: "article",
        suspect: false,
        warnings: [],
        html: "<p>A</p>"
      },
      html: "<p>A</p>"
    )
    request_log = instance_double(FetchUtil::RequestLog, append: nil)

    expect(FetchUtil).to receive(:fetch).with(
      "https://a.test",
      timeout: 20,
      wait: 0.75,
      wait_for_idle: true,
      reader_mode: true,
      request_log: request_log
    ).and_return(result)

    allow(FetchUtil::RequestLog).to receive(:new).and_return(request_log)

    output = capture_stdout do
      described_class.start(["fetch", "https://a.test", "--include-html"])
    end

    expect(JSON.parse(output, symbolize_names: true)).to eq(
      {
        url: "https://a.test",
        final_url: "https://a.test/final",
        canonical_url: "https://a.test/canonical",
        title: "A",
        markdown: "body a",
        content_type: "article",
        suspect: false,
        warnings: [],
        html: "<p>A</p>"
      }
    )
  end

  it "aggregates search results and prints json" do
    request_log = instance_double(FetchUtil::RequestLog)
    searcher = instance_double(FetchUtil::Searcher)
    payload = {
      query: "ruby language",
      results: [{ title: "Ruby", url: "https://www.ruby-lang.org/" }]
    }

    allow(FetchUtil::RequestLog).to receive(:new).and_return(request_log)
    expect(FetchUtil::Searcher).to receive(:new).with(
      request_log: request_log,
      sources: %w[duckduckgo google],
      limit: 10,
      concurrency: 2,
      verbose: false,
      timeout: 20,
      wait: 0.75,
      wait_for_idle: true,
      reader_mode: true
    ).and_return(searcher)
    expect(searcher).to receive(:search).with("ruby language").and_return(payload)

    output = capture_stdout do
      described_class.start(["search", "ruby language"])
    end

    expect(JSON.parse(output, symbolize_names: true)).to eq(payload)
  end

  it "passes verbose search mode through to the searcher" do
    request_log = instance_double(FetchUtil::RequestLog)
    searcher = instance_double(FetchUtil::Searcher)
    payload = {
      query: "ruby language",
      results: [{ title: "Ruby", url: "https://www.ruby-lang.org/", sources: %w[duckduckgo google], ranks: { duckduckgo: 1, google: 1 } }]
    }

    allow(FetchUtil::RequestLog).to receive(:new).and_return(request_log)
    expect(FetchUtil::Searcher).to receive(:new).with(
      request_log: request_log,
      sources: %w[duckduckgo google],
      limit: 10,
      concurrency: 2,
      verbose: true,
      timeout: 20,
      wait: 0.75,
      wait_for_idle: true,
      reader_mode: true
    ).and_return(searcher)
    expect(searcher).to receive(:search).with("ruby language").and_return(payload)

    output = capture_stdout do
      described_class.start(["search", "ruby language", "--verbose-search"])
    end

    expect(JSON.parse(output, symbolize_names: true)).to eq(payload)
  end

  it "runs regulatory lookup and prints json" do
    request_log = instance_double(FetchUtil::RequestLog, append: nil)
    payload = {
      "robotstxt" => [{ "disallow" => "fetch", "path" => "/*" }]
    }

    allow(FetchUtil::RequestLog).to receive(:new).and_return(request_log)
    expect(request_log).to receive(:append).with("regulatory://https://example.com?sources=machine,-robotstxt")
    expect(FetchUtil).to receive(:regulatory).with(
      "https://example.com",
      cache_path: "/tmp/regulatory-cache",
      sources: "machine,-robotstxt",
      timeout: 20
    ).and_return(payload)

    output = capture_stdout do
      described_class.start([
                              "regulatory",
                              "https://example.com",
                              "--sources",
                              "machine,-robotstxt",
                              "--cache-path",
                              "/tmp/regulatory-cache"
                            ])
    end

    expect(JSON.parse(output)).to eq(payload)
  end
end
