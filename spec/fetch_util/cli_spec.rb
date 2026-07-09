# frozen_string_literal: true

require "json"
require "stringio"
require "yaml"

RSpec.describe FetchUtil::CLI do
  include_context 'cli spec helpers'

  it "fetches multiple urls in parallel and prints jsonl without urls by default" do
    first = result_double
    second = result_double(
      url: "https://b.test",
      final_url: "https://b.test/final",
      canonical_url: "https://b.test/canonical",
      title: "B",
      excerpt: "about b",
      language: "es",
      social_kind: "post",
      platform: "mastodon",
      handle: "@fetcher@ruby.social",
      reply_count: 7,
      community: "Ruby",
      score: 42,
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

    expected = [
      {
        title: "A",
        language: nil,
        markdown: "body a",
        content_type: "article",
        suspect: false,
        warnings: []
      },
      {
        title: "B",
        language: "es",
        social_kind: "post",
        platform: "mastodon",
        handle: "@fetcher@ruby.social",
        reply_count: 7,
        community: "Ruby",
        score: 42,
        markdown: "body b",
        content_type: "article",
        suspect: true,
        warnings: ["warning"]
      }
    ]
    expect(output.lines.map { |line| JSON.parse(line, symbolize_names: true) }).to eq(expected)
  end

  it "outputs YAML front matter followed by markdown by default for fetch" do
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

    front_matter, body = output.split("---\n", 3).values_at(1, 2)
    expect(YAML.safe_load(front_matter)).to eq(
      "title" => "A", "language" => nil, "content_type" => "article",
      "suspect" => false, "warnings" => []
    )
    expect(body).to eq("# A\n\nbody a\n")
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
        title: "A",
        language: nil,
        markdown: "body a",
        content_type: "article",
        suspect: false,
        warnings: [],
        html: "<p>A</p>"
      }
    )
  end

  it "includes urls when explicitly requested" do
    result = result_double
    request_log = instance_double(FetchUtil::RequestLog, append: nil)
    allow(FetchUtil::RequestLog).to receive(:new).and_return(request_log)
    allow(FetchUtil).to receive(:fetch).and_return(result)

    output = run_cli("fetch", "https://a.test", "--include-urls", "--format", "json")

    expect(JSON.parse(output, symbolize_names: true)).to include(
      url: "https://a.test", final_url: "https://a.test/final", canonical_url: "https://a.test/canonical"
    )
  end

  it "keeps JSON and front matter fields in parity" do
    result = result_double(warnings: ["warning"], suspect: false)
    request_log = instance_double(FetchUtil::RequestLog, append: nil)
    allow(FetchUtil::RequestLog).to receive(:new).and_return(request_log)
    allow(FetchUtil).to receive(:fetch).and_return(result)

    json = JSON.parse(run_cli("fetch", "https://a.test", "--format", "json"))
    front_matter = run_cli("fetch", "https://a.test").split("---\n", 3)[1]
    yaml = YAML.safe_load(front_matter)

    expect(yaml.keys).to contain_exactly(*(json.keys - ["markdown"]))
  end

  it "emits html in front matter when requested" do
    result = result_double
    request_log = instance_double(FetchUtil::RequestLog, append: nil)
    allow(FetchUtil::RequestLog).to receive(:new).and_return(request_log)
    allow(FetchUtil).to receive(:fetch).and_return(result)

    output = run_cli("fetch", "https://a.test", "--include-html")
    front_matter = output.split("---\n", 3)[1]

    expect(YAML.safe_load(front_matter)).to include("html" => "<p>A</p>")
  end

  it "emits separate front-matter documents for multiple results" do
    first = result_double(markdown: "first")
    second = result_double(markdown: "second", title: "B")
    request_log = instance_double(FetchUtil::RequestLog, append: nil)
    allow(FetchUtil::RequestLog).to receive(:new).and_return(request_log)
    allow(FetchUtil).to receive(:fetch_many).and_return([first, second])

    output = run_cli("fetch", "https://a.test", "https://b.test")
    expect(output.scan(/^---$/).length).to eq(4)
    expect(output).to include("---\nfirst\n\n---\n")
    expect(output).to end_with("---\nsecond\n")
  end

  it "prints product price in json fetch output" do
    result = result_double(content_type: "product", price: "$199.99")
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

    output = run_cli("fetch", "https://a.test", "--format", "json")

    expect(JSON.parse(output, symbolize_names: true)).to include(
      content_type: "product",
      price: "$199.99"
    )
  end

  it "prints social fields in json fetch output" do
    result = result_double(
      content_type: "social",
      social_kind: "post",
      platform: "mastodon",
      handle: "@fetcher@ruby.social",
      reply_count: 7,
      community: "Ruby",
      score: 42
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

    output = run_cli("fetch", "https://a.test", "--format", "json")

    expect(JSON.parse(output, symbolize_names: true)).to include(
      social_kind: "post",
      platform: "mastodon",
      handle: "@fetcher@ruby.social",
      reply_count: 7,
      community: "Ruby",
      score: 42
    )
  end

  it "prints property fields in json fetch output" do
    result = result_double(
      content_type: "property",
      price: "£450,000",
      location: "Cedar Lane, Bristol, BS1",
      bedrooms: 3,
      bathrooms: 2,
      area_sqft: 1210
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

    output = run_cli("fetch", "https://a.test", "--format", "json")

    expect(JSON.parse(output, symbolize_names: true)).to include(
      content_type: "property",
      price: "£450,000",
      location: "Cedar Lane, Bristol, BS1",
      bedrooms: 3,
      bathrooms: 2,
      area_sqft: 1210
    )
  end

  it "prints lodging structured fields in json fetch output" do
    result = result_double(
      content_type: "hotel",
      name: "Harbor Lantern Hotel",
      price: "£189",
      rating: "Rating: 4.6/5 from 842 reviews",
      address: "8 Cedar Quay, Brighton, East Sussex, BN1 1AA, GB"
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

    output = run_cli("fetch", "https://a.test", "--format", "json")

    expect(JSON.parse(output, symbolize_names: true)).to include(
      content_type: "hotel",
      name: "Harbor Lantern Hotel",
      price: "£189",
      rating: "Rating: 4.6/5 from 842 reviews",
      address: "8 Cedar Quay, Brighton, East Sussex, BN1 1AA, GB"
    )
  end

  it "prints structured json for network error results" do
    result = result_double(
      url: "https://missing.example.test/",
      final_url: "https://missing.example.test/",
      canonical_url: nil,
      title: nil,
      byline: nil,
      language: nil,
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
        language: nil,
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
      limit: nil,
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
      limit: nil,
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
