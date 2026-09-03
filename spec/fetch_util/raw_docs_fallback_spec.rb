# frozen_string_literal: true

RSpec.describe FetchUtil::RawDocsFallback do
  def http_response(url:, status: 200, body: "")
    FetchUtil::HttpRedirectClient::Response.new(url: url, status: status, headers: {}, body: body, redirects: [])
  end

  it "preserves fractional timeout budgets for the shared redirect client" do
    expect(FetchUtil::HttpRedirectClient).to receive(:new).with(
      timeout: 0.25,
      headers: described_class::DEFAULT_HEADERS
    )

    described_class.new(timeout: 0.25)
  end

  it "reports only declared document languages" do
    [[nil, nil], ["", nil], ["de", "de"]].each do |declared, expected|
      language_attribute = %( lang="#{declared}") if declared
      html = <<~HTML
        <html#{language_attribute}>
          <head><title>Sprachreferenz</title></head>
          <body><main><p>Diese Dokumentation enthaelt ausreichend Inhalt fuer eine verlaessliche Extraktion.</p></main></body>
        </html>
      HTML

      payload = described_class.new.payload_from_html(html, requested_url: "https://example.test/docs")

      expect(payload["language"]).to eq(expected)
    end
  end

  it "uses the shared redirect client final response" do
    html = <<~HTML
      <html>
        <head><title>Redirected docs</title></head>
        <body>
          <main>
            <h1>Redirected docs</h1>
            <p>This redirected documentation page has enough text to be extracted by the fallback.</p>
          </main>
        </body>
      </html>
    HTML
    http_client = instance_double(
      FetchUtil::HttpRedirectClient,
      get: http_response(url: "https://docs.example.com/final", body: html)
    )

    result = described_class.new(http_client: http_client).fetch("https://example.com/start")

    expect(result.first).to eq("https://docs.example.com/final")
    expect(result.last["title"]).to eq("Redirected docs")
    expect(http_client).to have_received(:get).with("https://example.com/start")
  end

  it "returns nil for shared redirect client non-success responses" do
    http_client = instance_double(
      FetchUtil::HttpRedirectClient,
      get: http_response(url: "https://example.com/missing", status: 404, body: "missing")
    )

    expect(described_class.new(http_client: http_client).fetch("https://example.com/missing")).to be_nil
  end

  it "returns nil when the shared redirect client raises an IO error" do
    http_client = instance_double(FetchUtil::HttpRedirectClient)
    allow(http_client).to receive(:get).and_raise(IOError, "stream closed")

    expect(described_class.new(http_client: http_client).fetch("https://example.com/docs")).to be_nil
  end

  it "returns nil when the shared redirect client raises a TLS error" do
    http_client = instance_double(FetchUtil::HttpRedirectClient)
    allow(http_client).to receive(:get).and_raise(OpenSSL::SSL::SSLError, "certificate verify failed")

    expect(described_class.new(http_client: http_client).fetch("https://example.com/docs")).to be_nil
  end

  it "extracts fragment-scoped docs content from raw html" do
    html = <<~HTML
            <html lang="en">
              <head>
                <title>Kubernetes API Reference</title>
                <link rel="canonical" href="https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.31/" />
              </head>
              <body>
                <main>
                  <div class="resource-container" id="pod-v1-core">
                    <h1>Pod v1 core</h1>
                    <p>Pod is a collection of containers that can run on a host.</p>
                    <pre><code>apiVersion: v1
      kind: Pod</code></pre>
                    <table>
                      <tr><th>Field</th><th>Description</th></tr>
                      <tr><td>metadata</td><td>Standard object metadata.</td></tr>
                    </table>
                  </div>
                </main>
              </body>
            </html>
    HTML

    payload = described_class.new.payload_from_html(html, requested_url: "https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.31/#pod-v1-core")

    expect(payload["title"]).to eq("Pod v1 core")
    expect(payload["canonicalUrl"]).to eq("https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.31/")
    expect(payload["markdown"]).to include("# Pod v1 core")
    expect(payload["markdown"]).to include("collection of containers")
    expect(payload["markdown"]).to include("```")
    expect(payload["markdown"]).to include("metadata: Standard object metadata.")
  end

  it "uses code fences longer than embedded backtick runs" do
    html = <<~HTML
      <html>
        <head><title>Fence reference</title></head>
        <body>
          <main>
            <h1>Fence reference</h1>
            <p>This reference explains how to preserve literal Markdown fence examples.</p>
            <pre>before
      ```ruby
      puts "literal fence"
      ```
      after</pre>
          </main>
        </body>
      </html>
    HTML

    payload = described_class.new.payload_from_html(html, requested_url: "https://example.test/fences")

    expect(payload["markdown"]).to include("````\nbefore\n```ruby\nputs \"literal fence\"\n```\nafter\n````")
  end

  it "renders nested lists once with hierarchy and ordered values" do
    html = <<~HTML
      <html lang="en"><head><title>Deployment guide</title></head><body><main>
        <h1>Deployment guide</h1>
        <p>Follow these deployment stages in order before publishing the application.</p>
        <ul>
          <li>Prepare the release
            <div class="nested-list-wrapper"><ol start="3">
              <li>Build the package</li>
              <li value="5">Verify the package
                <ul><li>Check the signed checksum</li></ul>
              </li>
            </ol></div>
          </li>
          <li>Publish the release</li>
        </ul>
        <p>Keep the release record after publishing for future audits.</p>
        <ol start="8"><li>Notify maintainers</li><li value="10">Close the release</li></ol>
      </main></body></html>
    HTML

    payload = described_class.new.payload_from_html(html, requested_url: "https://docs.example.com/deployment")
    markdown = payload.fetch("markdown")

    expect(markdown.scan("Prepare the release").length).to eq(1)
    expect(markdown.scan("Build the package").length).to eq(1)
    expect(markdown.scan("Verify the package").length).to eq(1)
    expect(markdown.scan("Check the signed checksum").length).to eq(1)
    expect(markdown).to include(
      "- Prepare the release\n  3. Build the package\n  5. Verify the package\n    - Check the signed checksum",
      "- Publish the release",
      "8. Notify maintainers\n10. Close the release"
    )
    expect(markdown.index("Publish the release")).to be < markdown.index("Keep the release record")
    expect(markdown.index("Keep the release record")).to be < markdown.index("Notify maintainers")
  end

  it "renders a list itself when it is the requested fragment root" do
    html = <<~HTML
      <html lang="en"><head><title>Choice reference</title></head><body><main>
        <h1>Choice reference</h1>
        <ul id="choices">
          <div class="choice-row">
            <li>First choice includes enough substantive reference detail for extraction.</li>
          </div>
          <li>Second choice preserves the remaining documented behavior in order.</li>
        </ul>
      </main></body></html>
    HTML

    payload = described_class.new.payload_from_html(html, requested_url: "https://docs.example.com/reference#choices")

    expect(payload.fetch("markdown")).to include(
      "- First choice includes enough substantive reference detail for extraction.",
      "- Second choice preserves the remaining documented behavior in order."
    )
  end

  it "falls back to the final http url for unsafe canonical metadata" do
    html = <<~HTML
      <html>
        <head>
          <title>Canonical boundary</title>
          <link rel="canonical" href="javascript:alert(1)" />
        </head>
        <body>
          <main>
            <h1>Canonical boundary</h1>
            <p>This documentation page has enough substantive text for raw fallback extraction.</p>
          </main>
        </body>
      </html>
    HTML

    payload = described_class.new.payload_from_html(
      html,
      requested_url: "https://docs.example.test/guide#section"
    )

    expect(payload["canonicalUrl"]).to eq("https://docs.example.test/guide")
  end

  it "removes credentials from raw documentation output" do
    html = <<~HTML
      <html>
        <head>
          <title>Credential boundary</title>
          <link rel="canonical" href="https://reader:secret@docs.example.test/private" />
          <link rel="canonical" href="/safe-canonical" />
          <meta name="author" content="https://reader:sec'ret@docs.example.test/author" />
          <meta property="og:site_name" content="https://reader:secret@docs.example.test/site" />
          <meta property="article:published_time" content="https://reader:secret@docs.example.test/time" />
        </head>
        <body>
          <main href="https://reader:secret@assets.example.test/root">
            <h1>Credential boundary</h1>
            <p>Read https://reader:secret@assets.example.test/reference for complete documentation details.</p>
            <a href="https://reader:secret@assets.example.test/archive">Visible archive label</a>
            <img srcset="https://reader:secret@assets.example.test/one.png 1x, /two.png 2x" alt="Visible diagram">
            <link imagesrcset="https://reader:secret@assets.example.test/three.png 1x" title="Visible preload">
            <img data-lazy-src="https://reader:secret@assets.example.test/lazy.png" alt="Visible lazy image">
            <object data="https://reader:secret@assets.example.test/object"><span>Visible object</span></object>
            <div background="https://reader:secret@assets.example.test/background" style="background: url(https://reader:secret@assets.example.test/style)">Visible panel</div>
            <iframe srcdoc="&lt;a href='https://reader:secret@assets.example.test/frame'&gt;Frame&lt;/a&gt;"></iframe>
            <svg><a xlink:href="https://reader:secret@assets.example.test/vector"><text>Visible vector</text></a></svg>
          </main>
        </body>
      </html>
    HTML

    payload = described_class.new.payload_from_html(
      html,
      requested_url: "https://docs.example.test/guide#section"
    )

    expect(payload["canonicalUrl"]).to eq("https://docs.example.test/safe-canonical")
    expect(payload["markdown"]).to include("https://assets.example.test/reference")
    expect(payload["html"]).to include(
      "Visible archive label", "Visible diagram", "Visible preload", "Visible lazy image", "Visible object", "Visible panel",
      "Visible vector", "/two.png 2x"
    )
    expect(payload.values_at("byline", "siteName", "publishedTime")).to eq(
      ["https://docs.example.test/author", "https://docs.example.test/site", "https://docs.example.test/time"]
    )
    expect(payload.values.join).not_to include("reader", "secret", "sec'ret", "assets.example.test/archive")
  end

  it "extracts named-anchor directive sections from raw html" do
    html = <<~HTML
      <html>
        <head><title>Module ngx_http_proxy_module</title></head>
        <body>
          <a name="proxy_pass"></a>
          <div class="directive"><strong>proxy_pass</strong></div>
          <p>Sets the protocol and address of a proxied server.</p>
          <pre>proxy_pass http://localhost:8000/uri/;</pre>
        </body>
      </html>
    HTML

    payload = described_class.new.payload_from_html(html, requested_url: "https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_pass")

    expect(payload["title"]).to eq("proxy_pass")
    expect(payload["markdown"]).to include("# proxy_pass")
    expect(payload["markdown"]).to include("protocol and address of a proxied server")
  end

  it "extracts empty id-anchor sections without including the next section" do
    html = <<~HTML
      <html>
        <head><title>Module ngx_http_proxy_module</title></head>
        <body>
          <a id="proxy_pass"></a>
          <h2>proxy_pass</h2>
          <p>Sets the protocol and address of a proxied server for this location.</p>
          <a id="proxy_pass_source" href="/source">Source details</a>
          <p>Content after the source link remains part of this directive.</p>
          <pre>proxy_pass http://localhost:8000/uri/;</pre>
          <a id="proxy_redirect"></a>
          <h2>proxy_redirect</h2>
          <p>This belongs to the following directive and must not be included.</p>
        </body>
      </html>
    HTML

    payload = described_class.new.payload_from_html(html, requested_url: "https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_pass")

    expect(payload["title"]).to eq("proxy_pass")
    expect(payload["markdown"]).to include("protocol and address of a proxied server")
    expect(payload["markdown"]).to include("Content after the source link")
    expect(payload["markdown"]).not_to include("following directive")
  end

  it "extracts sections whose fragment id is on the heading" do
    html = <<~HTML
      <html>
        <head><title>Reference guide</title></head>
        <body>
          <main>
            <h2 id="configuration">Configuration</h2>
            <p>The configuration section explains every supported option and its runtime behavior.</p>
            <h3>Advanced options</h3>
            <p>Advanced option details remain part of the requested configuration section.</p>
            <a id="configuration_source" href="/source">Configuration source</a>
            <p>A nonempty inline anchor does not end the requested section.</p>
            <a name="legacy_source" href="/legacy-source">Legacy configuration source</a>
            <p>A visible named anchor also remains part of the requested section.</p>
            <h2 id="deployment">Deployment</h2>
            <p>Deployment belongs to the following same-level section and must not be included.</p>
          </main>
        </body>
      </html>
    HTML

    payload = described_class.new.payload_from_html(html, requested_url: "https://example.test/docs#configuration")

    expect(payload["title"]).to eq("Configuration")
    expect(payload["markdown"]).to include(
      "every supported option", "Advanced option details", "does not end", "visible named anchor"
    )
    expect(payload["markdown"]).not_to include("Deployment", "following same-level section")
  end

  it "stops heading-owned fragments at explicit empty anchor boundaries" do
    html = <<~HTML
      <html>
        <head><title>Reference guide</title></head>
        <body>
          <main>
            <h3 id="selected">Selected topic</h3>
            <p>The selected topic has enough substantive reference content to produce a useful result.</p>
            <h4>Nested detail</h4>
            <p>A lower-level heading remains inside the selected topic.</p>
            <a id="next_topic"></a>
            <h4>Next topic</h4>
            <p>Content after an explicit fragment boundary must not be included.</p>
          </main>
        </body>
      </html>
    HTML

    payload = described_class.new.payload_from_html(html, requested_url: "https://example.test/docs#selected")

    expect(payload["markdown"]).to include("selected topic has enough", "lower-level heading remains")
    expect(payload["markdown"]).not_to include("Next topic", "explicit fragment boundary")
  end

  it "retains content wrapped by a matching nonempty id anchor" do
    html = <<~HTML
      <html>
        <head><title>Wrapped section</title></head>
        <body>
          <a id="wrapped_section">
            <h2>Wrapped section</h2>
            <p>This substantive fragment content is wrapped by its matching anchor rather than following an empty marker.</p>
          </a>
        </body>
      </html>
    HTML

    payload = described_class.new.payload_from_html(html, requested_url: "https://example.test/docs#wrapped_section")

    expect(payload["title"]).to eq("Wrapped section")
    expect(payload["markdown"]).to include("substantive fragment content")
  end

  it "extracts fragment ids that contain selector metacharacters" do
    html = <<~HTML
      <html>
        <head><title>Quoted section</title></head>
        <body>
          <main>
            <section id='section"1'>
              <h2>Quoted section</h2>
              <p>This fragment id contains a quote and should still be matched safely.</p>
            </section>
          </main>
        </body>
      </html>
    HTML

    payload = described_class.new.payload_from_html(html, requested_url: "https://example.com/docs#section%221")

    expect(payload["title"]).to eq("Quoted section")
    expect(payload["markdown"]).to include("should still be matched safely")
  end

  it "preserves literal plus signs in fragment ids" do
    html = <<~HTML
      <html>
        <head><title>Operator reference</title></head>
        <body>
          <main>
            <section id="operator+">
              <h2>Operator plus</h2>
              <p>This fragment documents the literal plus operator and its complete reference behavior.</p>
            </section>
          </main>
        </body>
      </html>
    HTML

    ["operator+", "operator%2B"].each do |fragment|
      payload = described_class.new.payload_from_html(html, requested_url: "https://example.com/docs##{fragment}")

      expect(payload["title"]).to eq("Operator plus")
      expect(payload["markdown"]).to include("literal plus operator")
    end
  end

  it "does not swallow unexpected extraction bugs in payload_from_html" do
    fallback = described_class.new
    html = <<~HTML
      <html>
        <body>
          <main>
            <h1>Example docs</h1>
            <p>This paragraph is long enough to reach the extraction path safely.</p>
          </main>
        </body>
      </html>
    HTML

    allow(fallback).to receive(:markdown_from_root).and_raise(NoMethodError, "boom")

    expect do
      fallback.payload_from_html(html, requested_url: "https://example.com/docs")
    end.to raise_error(NoMethodError, "boom")
  end
end
