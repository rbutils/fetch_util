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

  it "does not cache transport-failure fallbacks" do
    attempts = 0
    client = fake_client(
      "https://example.com/robots.txt" => lambda do
        attempts += 1
        raise SocketError, "temporary failure" if attempts == 1

        response(
          "https://example.com/robots.txt",
          body: "User-agent: *\nDisallow: /\n"
        )
      end
    )
    dir = Dir.mktmpdir
    regulatory = described_class.new(client: client, cache_path: dir, sources: "robotstxt")

    expect(regulatory.call("https://example.com")).to eq({})
    expect(regulatory.call("https://example.com")).to eq(
      "robotstxt" => [{ "disallow" => "*", "path" => "/*" }]
    )
    expect(client.requests).to eq(["https://example.com/robots.txt"] * 2)
  ensure
    FileUtils.remove_entry(dir) if dir && File.exist?(dir)
  end

  it "does not cache transport failures for TDM policies" do
    attempts = 0
    policy_url = "https://example.com/policies/tdm.json"
    client = fake_client(
      policy_url => lambda do
        attempts += 1
        raise Timeout::Error, "temporary failure" if attempts == 1

        response(
          policy_url,
          headers: { "content-type" => ["application/json"] },
          body: JSON.generate("permission" => [{ "action" => "tdm:mine" }])
        )
      end
    )
    dir = Dir.mktmpdir
    regulatory = described_class.new(client: client, cache_path: dir)
    target_origin = URI.parse("https://example.com")

    expect(regulatory.send(:tdm_policy_record, policy_url, target_origin: target_origin)).to eq("signals" => [])
    expect(regulatory.send(:tdm_policy_record, policy_url, target_origin: target_origin)).to eq(
      "signals" => [{ "allow" => "text-and-data-mining" }]
    )
    expect(client.requests).to eq([policy_url] * 2)
  ensure
    FileUtils.remove_entry(dir) if dir && File.exist?(dir)
  end

  it "does not cache transient page responses but caches stable misses" do
    transient_url = "https://example.com/transient"
    missing_url = "https://example.com/missing"
    attempts = 0
    client = fake_client(
      transient_url => lambda do
        attempts += 1
        next response(transient_url, status: 503) if attempts == 1

        response(transient_url, headers: { "x-robots-tag" => ["noindex"] })
      end,
      missing_url => response(missing_url, status: 404)
    )
    dir = Dir.mktmpdir
    regulatory = described_class.new(client: client, cache_path: dir, sources: "xrobotstag")

    expect(regulatory.call(transient_url)).to eq({})
    expect(regulatory.call(transient_url)).to eq("xrobotstag" => [{ "disallow" => "index" }])
    expect(regulatory.call(missing_url)).to eq({})
    expect(regulatory.call(missing_url)).to eq({})
    expect(client.requests.tally).to eq(transient_url => 2, missing_url => 1)
  ensure
    FileUtils.remove_entry(dir) if dir && File.exist?(dir)
  end

  it "does not cache request timeout responses" do
    url = "https://example.com/timed-out"
    attempts = 0
    client = fake_client(
      url => lambda do
        attempts += 1
        next response(url, status: 408) if attempts == 1

        response(url, headers: { "x-robots-tag" => ["noindex"] })
      end
    )
    dir = Dir.mktmpdir
    regulatory = described_class.new(client: client, cache_path: dir, sources: "xrobotstag")

    expect(regulatory.call(url)).to eq({})
    expect(regulatory.call(url)).to eq("xrobotstag" => [{ "disallow" => "index" }])
    expect(client.requests).to eq([url, url])
  ensure
    FileUtils.remove_entry(dir) if dir && File.exist?(dir)
  end

  it "does not cache rate-limited TDM policy responses" do
    policy_url = "https://example.com/policies/tdm.json"
    attempts = 0
    client = fake_client(
      policy_url => lambda do
        attempts += 1
        next response(policy_url, status: 429) if attempts == 1

        response(
          policy_url,
          headers: { "content-type" => ["application/json"] },
          body: JSON.generate("permission" => [{ "action" => "tdm:mine" }])
        )
      end
    )
    dir = Dir.mktmpdir
    regulatory = described_class.new(client: client, cache_path: dir)
    target_origin = URI.parse("https://example.com")

    expect(regulatory.send(:tdm_policy_record, policy_url, target_origin: target_origin)).to eq("signals" => [])
    expect(regulatory.send(:tdm_policy_record, policy_url, target_origin: target_origin)).to eq(
      "signals" => [{ "allow" => "text-and-data-mining" }]
    )
    expect(client.requests).to eq([policy_url] * 2)
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

  it "returns independent source selections in declared order" do
    regulatory = described_class.new(client: Object.new)
    expected_sources = %w[
      robotstxt contentsignal contentusagerobots contentusageheader trusttxt
      xrobotstag metarobots tdmrep tdmheaders tdmmeta tdmpolicy human
    ]

    first_selection = regulatory.send(:resolve_sources, "machine,human")
    second_selection = regulatory.send(:resolve_sources, "machine,human")

    expect(first_selection).to eq(expected_sources)
    expect(second_selection).to eq(expected_sources)
    expect(first_selection).not_to equal(second_selection)
  end

  it "owns source selections at initialization" do
    tdmrep_url = "https://example.test/.well-known/tdmrep.json"
    payload = JSON.generate([{ "location" => "/", "tdm-reservation" => "0" }])
    clients = Array.new(2) do
      fake_client(tdmrep_url => response(tdmrep_url, body: payload))
    end
    dirs = Array.new(2) { Dir.mktmpdir }
    source = +"tdmrep"
    sources = [source]
    regulatory = clients.zip(dirs).map do |client, dir|
      described_class.new(client: client, cache_path: dir, sources: sources)
    end

    source.replace("trusttxt")
    sources << "robotstxt"

    expected = { "tdmrep" => [{ "allow" => "text-and-data-mining" }] }
    regulatory.each { |instance| expect(instance.call("https://example.test/article")).to eq(expected) }
    clients.each { |client| expect(client.requests).to eq([tdmrep_url]) }
    regulatory.each do |instance|
      owned_sources = instance.instance_variable_get(:@source_tokens)
      expect(owned_sources).to eq(["tdmrep"])
      expect(owned_sources).to be_frozen
      expect(owned_sources.first).to be_frozen
    end
    expect(sources).not_to be_frozen
    expect(source).not_to be_frozen
  ensure
    dirs&.each { |dir| FileUtils.remove_entry(dir) if File.exist?(dir) }
  end

  it "owns the cache path at initialization" do
    tdmrep_url = "https://example.test/.well-known/tdmrep.json"
    payload = JSON.generate([{ "location" => "/", "tdm-reservation" => "0" }])
    client = fake_client(tdmrep_url => response(tdmrep_url, body: payload))
    root = Dir.mktmpdir
    original_path = File.join(root, "original")
    changed_path = File.join(root, "changed")
    cache_path = original_path.dup
    regulatory = described_class.new(client: client, cache_path: cache_path, sources: "tdmrep")

    cache_path.replace(changed_path)

    expect(regulatory.call("https://example.test/article")).to eq(
      "tdmrep" => [{ "allow" => "text-and-data-mining" }]
    )
    expect(regulatory.instance_variable_get(:@cache_path)).to eq(original_path).and be_frozen
    expect(File).to be_directory(original_path)
    expect(File).not_to be_directory(changed_path)
    expect(cache_path).not_to be_frozen
  ensure
    FileUtils.remove_entry(root) if root && File.exist?(root)
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

  it "extracts expanded slash-form ODRL terms" do
    policy = {
      "permission" => [
        {
          "action" => "https://www.w3.org/ns/odrl/2/mine",
          "duty" => [{ "action" => "https://www.w3.org/ns/odrl/2/obtainConsent" }],
          "constraint" => [
            {
              "leftOperand" => "https://www.w3.org/ns/odrl/2/purpose",
              "operator" => "https://www.w3.org/ns/odrl/2/eq",
              "rightOperand" => "https://example.com/vocabulary/research"
            }
          ]
        },
        { "action" => "https://www.w3.org/ns/odrl/2/distribute" }
      ]
    }
    regulatory = described_class.new(client: Object.new)

    expect(regulatory.send(:extract_tdm_policy_signals, JSON.generate(policy))).to eq(
      [
        {
          "allow" => "text-and-data-mining",
          "conditions" => {
            "duty" => ["obtain-consent"],
            "purpose" => "research"
          }
        }
      ]
    )
  end

  it "ignores absolute ODRL targets from another origin" do
    policy_url = "https://policies.example.test/tdm.json"
    permission = lambda do |target, purpose|
      {
        "action" => "https://www.w3.org/ns/odrl/2/mine",
        "target" => target,
        "constraint" => {
          "leftOperand" => "purpose",
          "operator" => "eq",
          "rightOperand" => purpose
        }
      }
    end
    policy = {
      "permission" => [
        permission.call("https://foreign.example.test/article", "research"),
        permission.call("https://CURRENT.EXAMPLE.TEST/article", "research"),
        permission.call("/article", "non-research")
      ]
    }
    client = fake_client(
      "https://current.example.test/.well-known/tdmrep.json" => response(
        "https://current.example.test/.well-known/tdmrep.json",
        status: 404
      ),
      "https://current.example.test/article" => response(
        "https://current.example.test/article",
        headers: {
          "content-type" => ["text/html"],
          "tdm-reservation" => ["1"],
          "tdm-policy" => [policy_url]
        },
        body: "<html><body>Article body.</body></html>"
      ),
      policy_url => response(policy_url, headers: { "content-type" => ["application/json"] }, body: JSON.generate(policy))
    )
    dir = Dir.mktmpdir
    regulatory = described_class.new(client: client, cache_path: dir, sources: "tdmheaders,tdmpolicy")

    expect(regulatory.call("https://current.example.test/article")["tdmpolicy"]).to eq(
      [
        {
          "allow" => "text-and-data-mining",
          "conditions" => { "purpose" => "research", "policy" => policy_url }
        },
        {
          "allow" => "text-and-data-mining",
          "conditions" => { "purpose" => "non-research", "policy" => policy_url }
        }
      ]
    )
  ensure
    FileUtils.remove_entry(dir) if dir && File.exist?(dir)
  end

  it "recognizes bounded crawler meta names" do
    meta_tags = %w[
      robots googlebot bingbot GPTBot archive-bot googlebot-news
      robotics robot bottom mybotrules
    ].map { |name| { "name" => name, "content" => "noindex" } }
    regulatory = described_class.new(client: Object.new)

    expect(regulatory.send(:extract_meta_robot_signals, meta_tags, path: "/article")).to eq(
      [
        { "disallow" => "index", "path" => "/article" },
        { "disallow" => "index", "path" => "/article", "conditions" => { "user-agent" => "googlebot*" } },
        { "disallow" => "index", "path" => "/article", "conditions" => { "user-agent" => "bingbot*" } },
        { "disallow" => "index", "path" => "/article", "conditions" => { "user-agent" => "GPTBot*" } },
        { "disallow" => "index", "path" => "/article", "conditions" => { "user-agent" => "archive-bot*" } },
        { "disallow" => "index", "path" => "/article", "conditions" => { "user-agent" => "googlebot-news*" } }
      ]
    )
  end

  it "extracts directives only from active DOM meta elements" do
    policy_url = "https://example.com/policy?a=1&b=2"
    client = fake_client(
      "https://example.com/article" => response(
        "https://example.com/article",
        headers: { "content-type" => ["text/html"] },
        body: <<~HTML
          <html>
            <head>
              <!-- <meta name="robots" content="noindex"> -->
              <script>const fake = '<meta name="robots" content="noarchive">';</script>
              <template>
                <meta name="robots" content="nofollow">
                <meta name="tdm-reservation" content="0">
              </template>
              <meta NAME="ROBOTS" CONTENT="noindex">
              <meta name=robots content=nofollow>
              <meta name="tdm-reservation" content="1">
              <meta name="tdm-policy" content="https://example.com/policy?a=1&amp;b=2">
            </head>
            <body>Article body.</body>
          </html>
        HTML
      )
    )
    dir = Dir.mktmpdir
    regulatory = described_class.new(client: client, cache_path: dir, sources: "metarobots,tdmmeta")

    expect(regulatory.call("https://example.com/article")).to eq(
      "metarobots" => [
        { "disallow" => "follow" },
        { "disallow" => "index" }
      ],
      "tdmmeta" => [
        {
          "disallow" => "text-and-data-mining",
          "conditions" => { "policy" => policy_url }
        }
      ]
    )
  ensure
    FileUtils.remove_entry(dir) if dir && File.exist?(dir)
  end

  it "ignores TDM policy documents with non-object JSON roots" do
    policy_url = "https://example.com/policies/tdm.json"
    client = fake_client(
      "https://example.com/.well-known/tdmrep.json" => response(
        "https://example.com/.well-known/tdmrep.json",
        status: 404
      ),
      "https://example.com/article" => response(
        "https://example.com/article",
        headers: {
          "content-type" => ["text/html"],
          "tdm-reservation" => ["1"],
          "tdm-policy" => [policy_url]
        },
        body: "<html><body>Article body.</body></html>"
      ),
      policy_url => response(
        policy_url,
        headers: { "content-type" => ["application/json"] },
        body: "[]"
      )
    )
    dir = Dir.mktmpdir
    regulatory = described_class.new(client: client, cache_path: dir, sources: "tdmheaders,tdmpolicy")

    expect(regulatory.call("https://example.com/article")).to eq(
      "tdmheaders" => [
        {
          "disallow" => "text-and-data-mining",
          "conditions" => { "policy" => policy_url }
        }
      ]
    )
    expect(["null", '"text"', "1"].map { |body| regulatory.send(:extract_tdm_policy_signals, body) }).to eq([[], [], []])
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
