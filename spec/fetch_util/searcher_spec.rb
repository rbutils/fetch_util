# frozen_string_literal: true

RSpec.describe FetchUtil::Searcher do
  let(:request_log) { instance_double(FetchUtil::RequestLog, append: nil) }
  let(:transport) { instance_double(FetchUtil::SearchTransport) }

  def candidate(source, rank, title: "Result #{rank}", url: "https://example.test/#{source}/#{rank}", snippet: nil)
    FetchUtil::SearchTransport::Candidate.new(source: source, source_rank: rank, title: title, url: url, snippet: snippet)
  end

  def response(source, status: "ok", candidates: [], elapsed_ms: 12, final_url: nil, reason: nil)
    FetchUtil::SearchTransport::SourceResponse.new(
      source: source,
      status: status,
      candidates: candidates,
      elapsed_ms: elapsed_ms,
      final_url: final_url,
      reason: reason
    )
  end

  def search_candidates(candidates)
    allow(transport).to receive(:search).and_return([response("brave", candidates: candidates)])
    described_class.new(transport: transport, request_log: request_log, sources: ["brave"]).search("ruby")[:results]
  end

  it "uses the reliable direct defaults" do
    expect(described_class::DEFAULT_SOURCES).to eq(%w[brave bing])
  end

  it "deduplicates configured sources before constructing the transport, logging, aggregation, and diagnostics" do
    expect(FetchUtil::SearchTransport).to receive(:new).with(
      sources: ["brave"], timeout: FetchUtil::SearchTransport::DEFAULT_TIMEOUT
    ).and_return(transport)
    expect(request_log).to receive(:append).with("search://brave?q=ruby")
    responses = [response("brave", candidates: [candidate("brave", 1)])]
    expect(transport).to receive(:search).with("ruby").and_return(responses)

    payload = described_class.new(
      request_log: request_log,
      sources: %w[brave brave],
      verbose: true
    ).search("ruby")

    expect(payload[:results]).to eq([{ title: "Result 1", url: "https://example.test/brave/1", sources: ["brave"], ranks: { "brave" => 1 } }])
    expect(payload[:diagnostics].map { |diagnostic| diagnostic[:source] }).to eq(["brave"])
  end

  it "preserves first-occurrence source order while deduplicating" do
    expect(FetchUtil::SearchTransport).to receive(:new).with(
      sources: %w[bing brave], timeout: FetchUtil::SearchTransport::DEFAULT_TIMEOUT
    ).and_return(transport)

    described_class.new(request_log: request_log, sources: %w[bing brave bing])
  end

  it "logs a synthetic request and normalizes typed candidates without changing the normal payload" do
    responses = [
      response("brave", candidates: [
                 candidate("brave", 4, title: "example.test Ruby Guides", url: "https://EXAMPLE.test/guides/", snippet: "Ruby Guides Learn Ruby well."),
                 candidate("brave", 5, title: "PDF", url: "https://example.test/guide.pdf", snippet: "Document")
               ]),
      response("bing", candidates: [candidate("bing", 2, title: "Ruby API", url: "https://rubyapi.org/", snippet: "Complete reference.")])
    ]
    expect(request_log).to receive(:append).with("search://brave,bing?q=ruby+guides")
    expect(transport).to receive(:search).with("ruby guides").and_return(responses)

    payload = described_class.new(transport: transport, request_log: request_log).search(" ruby guides ")

    expect(payload).to eq(
      query: "ruby guides",
      results: [
        { title: "Ruby Guides", url: "https://example.test/guides", snippet: "Learn Ruby well." },
        { title: "Ruby API", url: "https://rubyapi.org/", snippet: "Complete reference." }
      ]
    )
  end

  it "round-robins configured sources while retaining transport ranks and deduplicating provenance" do
    shared = "https://example.test/shared/"
    responses = [
      response("bing", candidates: [
                 candidate("bing", 3, title: "Bing first", url: shared, snippet: "Preferred configured snippet."),
                 candidate("bing", 8, title: "Bing second")
               ]),
      response("brave", candidates: [
                 candidate("brave", 1, title: "Brave first"),
                 candidate("brave", 2, title: "Brave duplicate", url: shared, snippet: "A much longer later snippet should not replace the configured source snippet."),
                 candidate("brave", 4, title: "Brave third")
               ])
    ]
    allow(transport).to receive(:search).and_return(responses)

    payload = described_class.new(
      transport: transport,
      request_log: request_log,
      sources: %w[bing brave],
      verbose: true
    ).search("ruby")

    expected_results = [
      { title: "Bing first", url: "https://example.test/shared", snippet: "Preferred configured snippet.",
        sources: %w[bing brave], ranks: { "bing" => 3, "brave" => 2 } },
      { title: "Brave first", url: "https://example.test/brave/1", sources: ["brave"], ranks: { "brave" => 1 } },
      { title: "Bing second", url: "https://example.test/bing/8", sources: ["bing"], ranks: { "bing" => 8 } },
      { title: "Brave third", url: "https://example.test/brave/4", sources: ["brave"], ranks: { "brave" => 4 } }
    ]
    expect(payload[:results]).to eq(expected_results)
  end

  it "reports finite source diagnostics in configured order for ok, empty, and failed responses" do
    responses = [
      response("brave", candidates: [candidate("brave", 1)], elapsed_ms: 10,
                        final_url: "https://search.brave.com/search?q=ruby"),
      response("bing", status: "empty", elapsed_ms: 20, final_url: "https://www.bing.com/search?q=ruby"),
      response("google", status: "failed", elapsed_ms: 30, final_url: "https://www.google.com/sorry",
                         reason: "challenge")
    ]
    allow(transport).to receive(:search).and_return(responses)

    payload = described_class.new(
      transport: transport,
      request_log: request_log,
      sources: %w[brave bing google],
      verbose: true
    ).search("ruby")

    expected_diagnostics = [
      { source: "brave", transport: "http", status: "ok", result_count: 1, elapsed_ms: 10,
        final_url: "https://search.brave.com/search?q=ruby" },
      { source: "bing", transport: "http", status: "empty", result_count: 0, elapsed_ms: 20,
        final_url: "https://www.bing.com/search?q=ruby" },
      { source: "google", transport: "http", status: "failed", result_count: 0, elapsed_ms: 30,
        final_url: "https://www.google.com/sorry", reason: "challenge" }
    ]
    expect(payload[:diagnostics]).to eq(expected_diagnostics)
  end

  it "keeps successful peers on partial failure and returns an empty verbose payload when all sources fail" do
    partial_responses = [
      response("brave", status: "failed", reason: "timeout"),
      response("bing", candidates: [candidate("bing", 1)])
    ]
    all_failure_responses = [
      response("brave", status: "failed", reason: "challenge"),
      response("bing", status: "failed", reason: "timeout")
    ]
    allow(transport).to receive(:search).with("partial").and_return(partial_responses)
    allow(transport).to receive(:search).with("all fail").and_return(all_failure_responses)
    searcher = described_class.new(transport: transport, request_log: request_log, verbose: true)

    partial_results = [
      { title: "Result 1", url: "https://example.test/bing/1", sources: ["bing"], ranks: { "bing" => 1 } }
    ]
    expect(searcher.search("partial")[:results]).to eq(partial_results)
    expect(searcher.search("all fail")).to include(query: "all fail", results: [])
    diagnostics = searcher.search("all fail")[:diagnostics].map { |item| item.slice(:source, :status, :reason) }
    expected_diagnostics = [
      { source: "brave", status: "failed", reason: "challenge" },
      { source: "bing", status: "failed", reason: "timeout" }
    ]
    expect(diagnostics).to eq(expected_diagnostics)
  end

  it "drops metadata-only community snippets and jammed navigation snippets" do
    results = search_candidates([
                                  candidate("brave", 1, title: "Proc versus lambda", url: "https://stackoverflow.com/questions/1", 
                                                        snippet: "Stack Overflow7 answers - 16 years ago"),
                                  candidate("brave", 2, title: "Ruby lambdas", url: "https://reddit.com/r/ruby/1", snippet: "Reddit - r/ruby80+ comments - 3 years ago"),
                                  candidate("brave", 3, title: "Ruby history", url: "https://example.test/history", snippet: "HistoryFeaturesSyntaxImplementations")
                                ])

    expect(results).to eq([
                            { title: "Proc versus lambda", url: "https://stackoverflow.com/questions/1" },
                            { title: "Ruby lambdas", url: "https://reddit.com/r/ruby/1" },
                            { title: "Ruby history", url: "https://example.test/history" }
                          ])
  end

  it "filters low-value destinations and search-engine shells" do
    results = search_candidates([
                                  candidate("brave", 1, title: "Redo search without this site", url: "https://duckduckgo.com/html/?q=ruby"),
                                  candidate("brave", 2, title: "Ad redirect", url: "https://duckduckgo.com/y.js?ad_domain=example.test"),
                                  candidate("brave", 3, title: "Google Search", url: "https://www.google.com/search?q=ruby"),
                                  candidate("brave", 4, title: "Before you continue to Google", url: "https://www.google.com/webhp"),
                                  candidate("brave", 5, title: "Translated", url: "https://translate.google.com/translate?u=https://example.test"),
                                  candidate("brave", 6, title: "Ruby developers", url: "https://www.facebook.com/groups/ruby", snippet: "12K members"),
                                  candidate("brave", 7, title: "Ruby ideas - Pinterest", url: "https://www.pinterest.com/pin/1"),
                                  candidate("brave", 8, title: "Ruby shop", url: "https://shop.tiktok.com/view/product/1", snippet: "All Categories"),
                                  candidate("brave", 9, title: "Ruby books", url: "https://www.walmart.com/search?q=ruby"),
                                  candidate("brave", 10, title: "Ruby", url: "https://www.ruby-lang.org/", snippet: "Official site")
                                ])

    expect(results).to eq([{ title: "Ruby", url: "https://www.ruby-lang.org/", snippet: "Official site" }])
  end

  it "preserves meaningful documentation fragments and deduplicates noise fragments with their base URL" do
    results = search_candidates([
                                  candidate("brave", 1, title: "type Client", url: "https://pkg.go.dev/net/http#Client"),
                                  candidate("brave", 2, title: "terraform_data arguments reference", url: "https://developer.hashicorp.com/terraform/data#arguments-reference"),
                                  candidate("brave", 3, title: "terraform_data import", url: "https://developer.hashicorp.com/terraform/data#import"),
                                  candidate("brave", 4, title: "HTTP package", url: "https://pkg.go.dev/net/http#top"),
                                  candidate("brave", 5, title: "HTTP package", url: "https://pkg.go.dev/net/http")
                                ])

    expect(results.map { |result| result[:url] }).to eq([
                                                          "https://pkg.go.dev/net/http#Client",
                                                          "https://developer.hashicorp.com/terraform/data#arguments-reference",
                                                          "https://developer.hashicorp.com/terraform/data#import",
                                                          "https://pkg.go.dev/net/http"
                                                        ])
  end

  it "keeps lowercase brand prefixes in titles" do
    results = search_candidates([
                                  candidate("brave", 1, title: "rails Routing from the Outside In", url: "https://guides.rubyonrails.org/routing.html")
                                ])

    expect(results.first[:title]).to eq("rails Routing from the Outside In")
  end

  it "normalizes non-breaking whitespace in titles and snippets" do
    nbsp = "\u00A0"
    results = search_candidates([
                                  candidate("brave", 1, title: "Ruby#{nbsp}Guides", url: "https://guides.rubyonrails.org/", 
                                                        snippet: "Learn#{nbsp}Rails the productive way.")
                                ])

    expect(results).to eq([{ title: "Ruby Guides", url: "https://guides.rubyonrails.org/", snippet: "Learn Rails the productive way." }])
  end

  it "retains snippets longer than 180 characters" do
    snippet = [
      "This complete search snippet contains material context that remains useful to callers,",
      "including the late portion that was previously removed by the fixed presentation limit.",
      "It also preserves the final sentence and its additional details for downstream readers."
    ].join(" ")
    results = search_candidates([
                                  candidate("brave", 1, title: "Long result", url: "https://example.test/long-result", snippet: snippet)
                                ])

    expect(results.first[:snippet]).to eq(snippet)
    expect(results.first[:snippet].length).to be > 180
  end

  it "returns every aggregate result by default and applies an explicit limit after dedupe" do
    candidates = (1..11).map { |rank| candidate("brave", rank) }
    allow(transport).to receive(:search).and_return([response("brave", candidates: candidates)])

    expect(described_class.new(transport: transport, request_log: request_log, sources: ["brave"]).search("all")[:results].length).to eq(11)
    expect(described_class.new(transport: transport, request_log: request_log, sources: ["brave"], limit: 0).search("none")[:results]).to eq([])
    results = described_class.new(
      transport: transport, request_log: request_log, sources: ["brave"], limit: 3
    ).search("three")[:results]
    expect(results.map { |item| item[:title] }).to eq(["Result 1", "Result 2", "Result 3"])
  end

  it "rejects invalid limits before invoking the transport" do
    [-1, 1.5, true, "2"].each do |limit|
      expect { described_class.new(transport: transport, request_log: request_log, limit: limit) }.to raise_error(ArgumentError, "limit must be a nonnegative integer")
    end
    expect(transport).not_to receive(:search)
  end

  it "supports every configured source name through the transport seam" do
    %w[brave bing duckduckgo google ecosia].each do |source|
      expect { described_class.new(transport: transport, request_log: request_log, sources: [source]) }.not_to raise_error
    end
  end
end
