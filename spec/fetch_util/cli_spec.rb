# frozen_string_literal: true

require "json"
require "stringio"

RSpec.describe FetchUtil::CLI do
  include_context 'cli spec helpers'

  it "fetches multiple urls in parallel and prints jsonl" do
    first = result_double
    second = result_double(
      url: "https://b.test",
      final_url: "https://b.test/final",
      canonical_url: "https://b.test/canonical",
      title: "B",
      excerpt: "about b",
      markdown: "body b",
      suspect: true,
      warnings: ["warning"],
      html: "<p>B</p>"
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

    output = run_cli("fetch", "https://a.test", "https://b.test", "--format", "jsonl")

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

  it "outputs pure markdown by default for fetch" do
    result = result_double(markdown: "# A\n\nbody a")
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

    output = run_cli("fetch", "https://a.test")

    expect(output).to eq("# A\n\nbody a\n")
  end

  it "includes html only when requested" do
    result = result_double
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

    output = run_cli("fetch", "https://a.test", "--include-html", "--format", "json")

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

  it "prints structured json for network error results" do
    result = result_double(
      url: "https://missing.example.test/",
      final_url: "https://missing.example.test/",
      canonical_url: nil,
      title: nil,
      byline: nil,
      markdown: "",
      content_type: "error",
      suspect: true,
      warnings: ["dns_resolution_failed"],
      error_message: "Request failed (net::ERR_NAME_NOT_RESOLVED)",
      html: nil
    )
    request_log = instance_double(FetchUtil::RequestLog, append: nil)

    expect(FetchUtil).to receive(:fetch).with(
      "https://missing.example.test/",
      timeout: 20,
      wait: 0.75,
      wait_for_idle: true,
      reader_mode: true,
      request_log: request_log
    ).and_return(result)

    allow(FetchUtil::RequestLog).to receive(:new).and_return(request_log)

    output = run_cli("fetch", "https://missing.example.test/", "--format", "json")

    expect(JSON.parse(output, symbolize_names: true)).to eq(
      {
        url: "https://missing.example.test/",
        final_url: "https://missing.example.test/",
        content_type: "error",
        suspect: true,
        warnings: ["dns_resolution_failed"],
        error_message: "Request failed (net::ERR_NAME_NOT_RESOLVED)"
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

    output = run_cli("search", "ruby language")

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

    output = run_cli("search", "ruby language", "--verbose-search")

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

    output = run_cli(
      "regulatory",
      "https://example.com",
      "--sources",
      "machine,-robotstxt",
      "--cache-path",
      "/tmp/regulatory-cache"
    )

    expect(JSON.parse(output)).to eq(payload)
  end
end
