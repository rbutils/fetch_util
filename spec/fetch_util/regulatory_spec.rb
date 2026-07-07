# frozen_string_literal: true

require "fileutils"
require "tmpdir"

RSpec.describe FetchUtil::Regulatory do
  def fake_client(responses)
    requests = []
    client = Object.new
    client.define_singleton_method(:requests) { requests }
    client.define_singleton_method(:get) do |url|
      requests << url
      response = responses.fetch(url) do
        raise "unexpected request: #{url}"
      end
      response.respond_to?(:call) ? response.call : response
    end
    client
  end

  def response(url, status: 200, headers: {}, body: "", redirects: [])
    FetchUtil::Regulatory::Response.new(url: url, status: status, headers: headers, body: body, redirects: redirects)
  end

  it "normalizes binary whitespace safely" do
    value = "hello\xA0world\n".b

    expect(FetchUtil.normalize_whitespace(value)).to eq("hello world")
  end

  it "returns ordered robotstxt signals and strips paths for specific resource queries" do
    client = fake_client(
      "https://example.com/robots.txt" => response(
        "https://example.com/robots.txt",
        body: <<~ROBOTS
          User-agent: Googlebot
          Allow: /articles/

          User-agent: *
          Disallow: /

          User-agent: GPTBot
          Disallow: /
        ROBOTS
      )
    )
    dir = Dir.mktmpdir
    regulatory = described_class.new(client: client, cache_path: dir, sources: "robotstxt")

    expect(regulatory.call("https://example.com")).to eq(
      {
        "robotstxt" => [
          { "allow" => "*", "path" => "/articles/", "conditions" => { "user-agent" => "Googlebot*" } },
          { "disallow" => "*", "path" => "/*", "conditions" => { "user-agent" => "GPTBot*" } },
          { "disallow" => "*", "path" => "/*" }
        ]
      }
    )

    expect(regulatory.call("https://example.com/articles/123")).to eq(
      {
        "robotstxt" => [
          { "allow" => "*", "conditions" => { "user-agent" => "Googlebot*" } },
          { "disallow" => "*", "conditions" => { "user-agent" => "GPTBot*" } },
          { "disallow" => "*" }
        ]
      }
    )

    expect(client.requests).to eq(["https://example.com/robots.txt"])
  ensure
    FileUtils.remove_entry(dir) if dir && File.exist?(dir)
  end

  it "extracts content signals and content usage rules from robots.txt" do
    client = fake_client(
      "https://example.com/robots.txt" => response(
        "https://example.com/robots.txt",
        body: <<~ROBOTS
          User-agent: *
          Allow: /
          Content-Signal: search=yes, ai-train=no
          Content-Usage: train-ai=n
          Content-Usage: /ai-ok/ train-ai=y, search=y
        ROBOTS
      )
    )
    dir = Dir.mktmpdir
    regulatory = described_class.new(client: client, cache_path: dir, sources: "contentsignal,contentusagerobots")

    expect(regulatory.call("https://example.com")).to eq(
      {
        "contentsignal" => [
          { "disallow" => "ai-training", "path" => "/*", "conditions" => { "label" => "ai-train" } },
          { "allow" => "search", "path" => "/*" }
        ],
        "contentusagerobots" => [
          { "allow" => "ai-training", "path" => "/ai-ok/", "conditions" => { "label" => "train-ai" } },
          { "allow" => "search", "path" => "/ai-ok/" },
          { "disallow" => "ai-training", "path" => "/*", "conditions" => { "label" => "train-ai" } }
        ]
      }
    )

    expect(regulatory.call("https://example.com/ai-ok/page")).to eq(
      {
        "contentsignal" => [
          { "disallow" => "ai-training", "conditions" => { "label" => "ai-train" } },
          { "allow" => "search" }
        ],
        "contentusagerobots" => [
          { "allow" => "ai-training", "conditions" => { "label" => "train-ai" } },
          { "allow" => "search" },
          { "disallow" => "ai-training", "conditions" => { "label" => "train-ai" } }
        ]
      }
    )
  ensure
    FileUtils.remove_entry(dir) if dir && File.exist?(dir)
  end

  it "extracts site-wide trust.txt AI training preferences" do
    client = fake_client(
      "https://example.com/trust.txt" => response(
        "https://example.com/trust.txt",
        body: <<~TRUST
          # AI disclosure
          datatrainingallowed=no
        TRUST
      )
    )
    dir = Dir.mktmpdir
    regulatory = described_class.new(client: client, cache_path: dir, sources: "trusttxt")

    expect(regulatory.call("https://example.com")).to eq(
      {
        "trusttxt" => [
          { "disallow" => "ai-training", "path" => "/*", "conditions" => { "label" => "datatrainingallowed" } }
        ]
      }
    )

    expect(regulatory.call("https://example.com/article")).to eq(
      {
        "trusttxt" => [
          { "disallow" => "ai-training", "conditions" => { "label" => "datatrainingallowed" } }
        ]
      }
    )
    expect(client.requests).to eq(["https://example.com/trust.txt"])
  ensure
    FileUtils.remove_entry(dir) if dir && File.exist?(dir)
  end

  it "falls back to well-known trust.txt" do
    client = fake_client(
      "https://example.com/trust.txt" => response("https://example.com/trust.txt", status: 404),
      "https://example.com/.well-known/trust.txt" => response(
        "https://example.com/.well-known/trust.txt",
        body: "datatrainingallowed=yes\n"
      )
    )
    dir = Dir.mktmpdir
    regulatory = described_class.new(client: client, cache_path: dir, sources: "trusttxt")

    expect(regulatory.call("https://example.com")).to eq(
      {
        "trusttxt" => [
          { "allow" => "ai-training", "path" => "/*", "conditions" => { "label" => "datatrainingallowed" } }
        ]
      }
    )
    expect(client.requests).to eq([
                                    "https://example.com/trust.txt",
                                    "https://example.com/.well-known/trust.txt"
                                  ])
  ensure
    FileUtils.remove_entry(dir) if dir && File.exist?(dir)
  end

  it "supports source class expansion with exclusions" do
    client = fake_client(
      "https://example.com/.well-known/tdmrep.json" => response("https://example.com/.well-known/tdmrep.json", status: 404),
      "https://example.com/article" => response(
        "https://example.com/article",
        headers: { "content-type" => ["text/html"] },
        body: <<~HTML
          <html>
            <body>We do not permit text and data mining without prior consent.</body>
          </html>
        HTML
      )
    )
    dir = Dir.mktmpdir
    regulatory = described_class.new(
      client: client,
      cache_path: dir,
      sources: "human,machine,-robotstxt,-contentsignal,-contentusagerobots,-trusttxt"
    )

    expect(regulatory.call("https://example.com/article")).to eq(
      {
        "human" => [
          {
            "disallow" => "text-and-data-mining",
            "conditions" => { "evidence" => "We do not permit text and data mining without prior consent." }
          }
        ]
      }
    )
    expect(client.requests).not_to include("https://example.com/robots.txt")
  ensure
    FileUtils.remove_entry(dir) if dir && File.exist?(dir)
  end

  it "extracts page signals, follows TDM policy urls, and caches structured results" do
    client = fake_client(
      "https://example.com/robots.txt" => response("https://example.com/robots.txt", status: 404),
      "https://example.com/trust.txt" => response("https://example.com/trust.txt", status: 404),
      "https://example.com/.well-known/trust.txt" => response("https://example.com/.well-known/trust.txt", status: 404),
      "https://example.com/.well-known/tdmrep.json" => response("https://example.com/.well-known/tdmrep.json", status: 404),
      "https://example.com/article" => response(
        "https://example.com/article",
        headers: {
          "content-type" => ["text/html; charset=utf-8"],
          "x-robots-tag" => ["googlebot: noindex, nofollow", "noai", "max-snippet: 50"],
          "content-usage" => ["train-ai=n, search=y"],
          "tdm-reservation" => ["1"],
          "tdm-policy" => ["https://example.com/policies/tdm.json"]
        },
        body: <<~HTML
          <html>
            <head>
              <meta name="robots" content="noarchive, noimageindex">
              <meta name="googlebot" content="indexifembedded">
              <meta name="tdm-reservation" content="1">
              <meta name="tdm-policy" content="https://example.com/policies/tdm.json">
            </head>
            <body>We do not permit text and data mining without prior consent.</body>
          </html>
        HTML
      ),
      "https://example.com/policies/tdm.json" => response(
        "https://example.com/policies/tdm.json",
        headers: { "content-type" => ["application/json"] },
        body: <<~JSON
          {
            "permission": [
              {
                "action": "tdm:mine",
                "duty": [{"action": "obtainConsent"}],
                "constraint": [{"leftOperand": "purpose", "operator": "eq", "rightOperand": "tdm:research"}]
              }
            ]
          }
        JSON
      )
    )
    dir = Dir.mktmpdir
    regulatory = described_class.new(client: client, cache_path: dir, sources: "machine,human")

    payload = regulatory.call("https://example.com/article")

    expect(payload["xrobotstag"]).to include(
      { "disallow" => "follow", "conditions" => { "user-agent" => "googlebot*" } },
      { "disallow" => "index", "conditions" => { "user-agent" => "googlebot*" } },
      { "disallow" => "ai-training" },
      { "allow" => "snippet", "conditions" => { "max-chars" => 50 } }
    )
    expect(payload["metarobots"]).to include(
      { "disallow" => "archive" },
      { "disallow" => "image-index" },
      { "allow" => "index", "conditions" => { "user-agent" => "googlebot*", "if-embedded" => true } }
    )
    expect(payload["tdmheaders"]).to eq(
      [{ "disallow" => "text-and-data-mining", "conditions" => { "policy" => "https://example.com/policies/tdm.json" } }]
    )
    expect(payload["tdmmeta"]).to eq(
      [{ "disallow" => "text-and-data-mining", "conditions" => { "policy" => "https://example.com/policies/tdm.json" } }]
    )
    expect(payload["contentusageheader"]).to eq(
      [
        { "disallow" => "ai-training", "conditions" => { "label" => "train-ai" } },
        { "allow" => "search" }
      ]
    )
    expect(payload["human"]).to eq(
      [
        {
          "disallow" => "text-and-data-mining",
          "conditions" => { "evidence" => "We do not permit text and data mining without prior consent." }
        }
      ]
    )
    expect(payload["tdmpolicy"]).to eq(
      [
        {
          "allow" => "text-and-data-mining",
          "conditions" => {
            "duty" => ["obtain-consent"],
            "purpose" => "research",
            "policy" => "https://example.com/policies/tdm.json"
          }
        }
      ]
    )
    expect(client.requests).to eq([
                                    "https://example.com/.well-known/tdmrep.json",
                                    "https://example.com/trust.txt",
                                    "https://example.com/.well-known/trust.txt",
                                    "https://example.com/robots.txt",
                                    "https://example.com/article",
                                    "https://example.com/policies/tdm.json"
                                  ])

    second_payload = regulatory.call("https://example.com/article")
    expect(second_payload).to eq(payload)
    expect(client.requests).to eq([
                                    "https://example.com/.well-known/tdmrep.json",
                                    "https://example.com/trust.txt",
                                    "https://example.com/.well-known/trust.txt",
                                    "https://example.com/robots.txt",
                                    "https://example.com/article",
                                    "https://example.com/policies/tdm.json"
                                  ])
  ensure
    FileUtils.remove_entry(dir) if dir && File.exist?(dir)
  end

  it "preserves regulatory headers from redirect hops" do
    redirect = response(
      "https://www.theguardian.com/",
      status: 302,
      headers: {
        "location" => ["/europe"],
        "x-robots-tag" => ["bingbot: noarchive"]
      }
    )
    client = fake_client(
      "https://www.theguardian.com/.well-known/tdmrep.json" => response("https://www.theguardian.com/.well-known/tdmrep.json", status: 404),
      "https://www.theguardian.com/trust.txt" => response("https://www.theguardian.com/trust.txt", status: 404),
      "https://www.theguardian.com/.well-known/trust.txt" => response("https://www.theguardian.com/.well-known/trust.txt", status: 404),
      "https://www.theguardian.com/robots.txt" => response("https://www.theguardian.com/robots.txt", status: 404),
      "https://www.theguardian.com/" => response(
        "https://www.theguardian.com/europe",
        headers: { "content-type" => ["text/html; charset=utf-8"] },
        body: <<~HTML,
          <html>
            <head>
              <meta name="robots" content="noindex">
            </head>
            <body>ok</body>
          </html>
        HTML
        redirects: [redirect]
      )
    )
    dir = Dir.mktmpdir
    regulatory = described_class.new(client: client, cache_path: dir, sources: "machine")

    expect(regulatory.call("https://www.theguardian.com/")).to eq(
      {
        "xrobotstag" => [
          { "disallow" => "archive", "conditions" => { "user-agent" => "bingbot*" } }
        ],
        "metarobots" => [
          { "disallow" => "index" }
        ]
      }
    )
  ensure
    FileUtils.remove_entry(dir) if dir && File.exist?(dir)
  end

  it "scopes page-derived signals against the redirected final url" do
    client = fake_client(
      "https://example.com/trust.txt" => response("https://example.com/trust.txt", status: 404),
      "https://example.com/.well-known/trust.txt" => response("https://example.com/.well-known/trust.txt", status: 404),
      "https://example.com/.well-known/tdmrep.json" => response("https://example.com/.well-known/tdmrep.json", status: 404),
      "https://example.com/robots.txt" => response("https://example.com/robots.txt", status: 404),
      "https://example.com/start" => response(
        "https://example.com/final/",
        headers: {
          "content-type" => ["text/html; charset=utf-8"],
          "x-robots-tag" => ["noindex"]
        },
        body: <<~HTML
          <html>
            <head>
              <meta name="robots" content="nofollow">
            </head>
            <body>ok</body>
          </html>
        HTML
      )
    )
    dir = Dir.mktmpdir
    regulatory = described_class.new(client: client, cache_path: dir, sources: "machine")

    expect(regulatory.call("https://example.com/start")).to eq(
      {
        "xrobotstag" => [
          { "disallow" => "index" }
        ],
        "metarobots" => [
          { "disallow" => "follow" }
        ]
      }
    )
  ensure
    FileUtils.remove_entry(dir) if dir && File.exist?(dir)
  end
end

RSpec.describe FetchUtil::Regulatory::HttpClient do
  it "maps shared redirect client responses to regulatory response chains" do
    redirect = FetchUtil::HttpRedirectClient::Response.new(
      url: "https://example.com/start",
      status: 302,
      headers: { "location" => ["https://example.com/final"], "x-robots-tag" => ["noai"] },
      body: "",
      redirects: []
    )
    final = FetchUtil::HttpRedirectClient::Response.new(
      url: "https://example.com/final",
      status: 200,
      headers: { "content-type" => ["text/html"] },
      body: "<html>ok</html>",
      redirects: [redirect]
    )
    redirect_client = instance_double(FetchUtil::HttpRedirectClient, get: final)

    response = described_class.new(timeout: 3, user_agent: "Spec Agent", redirect_client: redirect_client).get("https://example.com/start")

    expect(response).to have_attributes(
      url: "https://example.com/final",
      status: 200,
      headers: { "content-type" => ["text/html"] },
      body: "<html>ok</html>"
    )
    expect(response.redirects.first).to have_attributes(
      url: "https://example.com/start",
      status: 302,
      headers: { "location" => ["https://example.com/final"], "x-robots-tag" => ["noai"] }
    )
    expect(redirect_client).to have_received(:get).with("https://example.com/start", limit: FetchUtil::HttpRedirectClient::REDIRECT_LIMIT)
  end
end
