# frozen_string_literal: true

RSpec.describe 'FetchUtil extractor integration' do
  include_context 'extractor integration helpers'

  it "extracts hashicorp developer docs through host-aware docs handling" do
    html = <<~HTML
      <html>
        <head>
          <title>KV secrets engine | Vault | HashiCorp Developer</title>
          <meta property="og:site_name" content="HashiCorp Developer" />
        </head>
        <body>
          <nav data-testid="breadcrumbs">Vault Docs</nav>
          <aside data-testid="side-nav">Side navigation</aside>
          <main>
            <article>
              <h1>KV secrets engine</h1>
              <p>The kv secrets engine is a generic key-value store.</p>
              <details>
                <summary>Version 2 options</summary>
                <p>Supports versioned secret history.</p>
              </details>
            </article>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://developer.hashicorp.com/robots.txt", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["title"]).to eq("KV secrets engine")
      expect(payload["markdown"]).to include("# KV secrets engine")
      expect(payload["markdown"]).to include("generic key-value store")
      expect(payload["markdown"]).to include("### Version 2 options")
      expect(payload["markdown"]).not_to include("Vault Docs")
      expect(payload["markdown"]).not_to include("Side navigation")
    end
  end

  it "extracts docker docs through host-aware docs handling" do
    html = <<~HTML
      <html>
        <head>
          <title>Dockerfile reference</title>
        </head>
        <body>
          <main>
            <aside class="toc">On this page</aside>
            <article>
              <h1>Dockerfile reference</h1>
              <section>
                <h2 id="run">RUN</h2>
                <p>The <code>RUN</code> instruction executes build commands.</p>
              </section>
            </article>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://docs.docker.com/reference/dockerfile/#run", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["title"]).to eq("RUN")
      expect(payload["markdown"]).to include("# RUN")
      expect(payload["markdown"]).to include("executes build commands")
      expect(payload["markdown"]).not_to include("On this page")
    end
  end

  it "extracts pkg.go.dev pages through docs-system detection" do
    html = <<~HTML
      <html>
        <head>
          <title>http package - net/http - Go Packages</title>
        </head>
        <body>
          <div id="main-content">
            <header class="go-Header">Header</header>
            <section>
              <h2 id="Client">type Client</h2>
              <p>A Client is an HTTP client.</p>
            </section>
          </div>
        </body>
      </html>
    HTML

    with_url_page("https://pkg.go.dev/net/http#Client", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["title"]).to eq("type Client")
      expect(payload["markdown"]).to include("# type Client")
      expect(payload["markdown"]).to include("A Client is an HTTP client")
      expect(payload["markdown"]).not_to include("Header")
    end
  end

  it "extracts grafana docs through host-aware docs handling" do
    html = <<~HTML
      <html>
        <head>
          <title>Query Loki | Grafana Loki documentation</title>
        </head>
        <body>
          <nav>Products Docs Pricing</nav>
          <main>
            <aside>On this page</aside>
            <article>
              <div>Open source</div>
              <h1>Query Loki</h1>
              <p>When you want to look for certain logs stored in Loki, you specify a set of labels.</p>
              <section>
                <h2>LogQL</h2>
                <p>LogQL is the query language for Grafana Loki.</p>
              </section>
              <section>
                <h2>Related resources from Grafana Labs</h2>
                <p>Video links and webinars.</p>
              </section>
              <div>Was this page helpful? Yes No</div>
            </article>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://grafana.com/docs/loki/latest/query/", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["title"]).to eq("Query Loki")
      expect(payload["markdown"]).to include("# Query Loki")
      expect(payload["markdown"]).to include("certain logs stored in Loki")
      expect(payload["markdown"]).to include("## LogQL")
      expect(payload["markdown"]).not_to include("Products Docs Pricing")
      expect(payload["markdown"]).not_to include("Related resources from Grafana Labs")
      expect(payload["markdown"]).not_to include("Was this page helpful")
    end
  end

  it "cleans sphinx heading anchor glyphs through docs-system detection" do
    html = <<~HTML
      <html>
        <head>
          <title>Router — Envoy documentation</title>
          <meta name="generator" content="Sphinx 7.2.0" />
        </head>
        <body>
          <main>
            <div class="body" role="main">
              <h1>Router</h1>
              <p>The router filter implements HTTP forwarding.</p>
              <dt class="sig" id="router.x-envoy-max-retries">x-envoy-max-retries</dt>
              <dd><p>Controls the retry budget.</p></dd>
            </div>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.envoyproxy.io/docs/envoy/latest/configuration/http/http_filters/router_filter", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["title"]).to eq("Router")
      expect(payload["markdown"]).to include("# Router")
      expect(payload["markdown"]).to include("### x-envoy-max-retries")
      expect(payload["markdown"]).not_to include("")
    end
  end

  it "extracts antora landing pages into compact doc lists" do
    html = <<~HTML
      <html>
        <head>
          <title>Fedora Documentation :: Fedora Docs</title>
          <meta name="generator" content="Antora 3.1.14">
        </head>
        <body>
          <div class="toolbar">Toolbar</div>
          <main class="main">
            <article class="doc">
              <h2>User Documentation</h2>
              <h2>Fedora Project & Community</h2>
              <a class="homepage-link homepage-link-primary" href="../fedora/latest/">Fedora Linux</a>
              <p>The Fedora Linux documentation hub.</p>
              <a class="homepage-link homepage-link-secondary" href="../quick-docs/">Quick Docs</a>
              <p>Short how-to and FAQ-style documentation.</p>
              <a class="homepage-link homepage-link-secondary" href="../tools/">Fedora Tools</a>
              <p>Utilities and tooling documentation.</p>
              <a class="homepage-link homepage-link-secondary" href="../epel/">EPEL</a>
              <p>Extra Packages for Enterprise Linux.</p>
            </article>
          </main>
        </body>
      </html>
    HTML

    with_page(html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["contentType"]).to eq("list")
      expect(payload["markdown"]).to include("# Fedora Documentation")
      expect(payload["markdown"]).to include("- User Documentation")
      expect(payload["markdown"]).to include("- [Fedora Linux](../fedora/latest/) - The Fedora Linux documentation hub.")
      expect(payload["markdown"]).to include("- [Quick Docs](../quick-docs/) - Short how-to and FAQ-style documentation.")
    end
  end
end
