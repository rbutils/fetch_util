# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'FetchUtil extractor integration - docs content cleanup warnings' do
  include_context 'extractor integration helpers'

  it "does not flag readable docs pages for incidental cookie footer text" do
    html = <<~HTML
      <html>
        <head>
          <title>Vercel Documentation</title>
          <meta name="description" content="Vercel is the AI Cloud - a unified platform for building, deploying, and scaling AI-powered applications and agentic workloads.">
        </head>
        <body>
          <main>
            <h1>Vercel Documentation</h1>
            <p>Build any type of application on Vercel with guides for frameworks, deployments, storage, observability, and AI workloads.</p>
            <p>The platform includes documentation for teams, security, previews, and production rollouts.</p>
          </main>
          <footer>
            <p>Manage cookie preferences</p>
          </footer>
        </body>
      </html>
    HTML

    with_page(html) do |page|
      payload = extract(page)

      expect(payload["warnings"]).not_to include("consent_interstitial")
      expect(payload["markdown"]).to include("Build any type of application on Vercel")
    end
  end

  it "does not suppress not-found warnings for generic docs wrappers without docs extraction" do
    html = <<~HTML
      <html>
        <head>
          <title>Missing post</title>
        </head>
        <body>
          <main>
            <article class="prose">
              <h1>Page not found</h1>
              <p>Sorry, we could not find the page you were looking for.</p>
            </article>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://example.com/posts/missing", html) do |page|
      payload = extract(page)

      expect(payload["markdown"]).to include("Page not found")
      expect(payload["warnings"]).to include("not_found_interstitial")
    end
  end

  it "does not flag a credible documentation index as multi-topic" do
    html = <<~HTML
      <html>
        <head>
          <title>Project Documentation</title>
          <link rel="canonical" href="https://docs.example.test/en/index.html">
          <meta property="og:site_name" content="Project Documentation">
        </head>
        <body>
          <main>
            <h1>Project Documentation</h1>
            <p>Find the reference material, tutorials, and guides for the project.</p>
            <h2>Reference</h2>
            <ul>
              <li><a href="/docs/classes">Classes and Modules</a></li>
              <li><a href="/docs/standard-library">Standard Library</a></li>
              <li><a href="/docs/language">Language Reference</a></li>
              <li><a href="/docs/api">API Reference</a></li>
            </ul>
            <h2>Guides</h2>
            <ul>
              <li><a href="/docs/tutorial">Tutorial</a></li>
            </ul>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://docs.example.test/en/", html) do |page|
      payload = extract(page)

      expect(payload["contentType"]).to eq("list")
      expect(payload["warnings"]).not_to include("multi_topic_page")
    end
  end

  it "keeps generic hubs and docs-word articles multi-topic" do
    generic_html = <<~HTML
      <html><head><title>Daily Briefing</title></head><body><article>
        <h1>Daily Briefing</h1><p>News from around the world.</p>
        <h2>World</h2><a href="/one">One story</a><a href="/two">Two story</a>
        <h2>Business</h2><a href="/three">Three story</a><a href="/four">Four story</a>
        <h2>Science</h2><a href="/five">Five story</a><a href="/six">Six story</a>
        <h2>Culture</h2><a href="/seven">Seven story</a><a href="/eight">Eight story</a>
      </article></body></html>
    HTML
    with_url_page("https://news.example.test/", generic_html) do |page|
      expect(extract(page)["warnings"]).to include("multi_topic_page")
    end

    article_html = <<~HTML
      <html><head><title>Documentation changes in our platform</title>
        <meta name="author" content="Jane Author">
        <meta property="article:published_time" content="2026-07-10T10:00:00Z">
      </head><body><article><h1>Documentation changes in our platform</h1>
        <p>Our documentation team published a detailed update about several unrelated releases and services.</p>
        <h2>Release one</h2><time datetime="2026-07-10T10:00:00Z">10:00</time><p>Details for the first release and its users.</p>
        <h2>Release two</h2><time datetime="2026-07-10T10:05:00Z">10:05</time><p>Details for the second release and its users.</p>
        <h2>Release three</h2><time datetime="2026-07-10T10:10:00Z">10:10</time><p>Details for the third release and its users.</p>
        <h2>Release four</h2><time datetime="2026-07-10T10:15:00Z">10:15</time><p>Details for the fourth release and its users.</p>
        <h2>Release five</h2><time datetime="2026-07-10T10:20:00Z">10:20</time><p>Details for the fifth release and its users.</p>
        <h2>Release six</h2><time datetime="2026-07-10T10:25:00Z">10:25</time><p>Details for the sixth release and its users.</p>
      </article></body></html>
    HTML
    with_url_page("https://blog.example.test/updates/platform", article_html) do |page|
      expect(extract(page)["warnings"]).to include("multi_topic_page")
    end
  end

  it "extracts nextjs docs without false browser-support warnings" do
    html = <<~HTML
      <html>
        <head>
          <title>File-system conventions: route.js | Next.js</title>
        </head>
        <body>
          <nav>
            <a href="/docs/app/getting-started/supported-browsers">Supported Browsers</a>
          </nav>
          <main>
            <article>
              <h1>route.js</h1>
              <p>Route Handlers allow you to create custom request handlers for a given route using the Web Request and Response APIs.</p>
              <h2>Reference</h2>
              <p>You can use Request and Response to handle input and output.</p>
            </article>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://nextjs.org/docs/app/building-your-application/routing/route-handlers", html) do |page|
      payload = extract(page)

      expect(payload["markdown"]).to include("# route.js")
      expect(payload["markdown"]).to include("Route Handlers allow you to create custom request handlers")
      expect(payload["warnings"]).not_to include("browser_support_interstitial")
      expect(payload["warnings"]).not_to include("consent_interstitial")
    end
  end

  it "does not flag short mdn docs pages as truncated when extraction is clean" do
    html = <<~HTML
      <html>
        <head>
          <title>&lt;div&gt;: The Content Division element - HTML | MDN</title>
        </head>
        <body>
          <nav>
            #{'<a href="/docs/Web/HTML">HTML reference</a>' * 120}
          </nav>
          <main>
            <article class="main-page-content">
              <h1>&lt;div&gt;: The Content Division element</h1>
              <p>The <code>&lt;div&gt;</code> element is the generic container for flow content.</p>
            </article>
          </main>
          <footer>
            #{"<p>Reference docs navigation and glossary links.</p>" * 60}
          </footer>
        </body>
      </html>
    HTML

    with_url_page("https://developer.mozilla.org/en-US/docs/Web/HTML/Element/div", html) do |page|
      payload = extract(page)

      expect(payload["markdown"]).to include("# <div>: The Content Division element")
      expect(payload["warnings"]).not_to include("truncated_content")
    end
  end

  it "does not flag python docs as not found when incidental 404 copy exists outside the article" do
    html = <<~HTML
      <html>
        <head>
          <title>json — JSON encoder and decoder — Python 3 documentation</title>
        </head>
        <body>
          <div class="body" role="main">
            <section id="module-json">
              <h1>json — JSON encoder and decoder<a class="headerlink" href="#module-json">¶</a></h1>
              <p>The <code>json</code> module exposes an API familiar to users of the standard library.</p>
              <p>Use <code>json.dumps()</code> to serialize data and <code>json.loads()</code> to parse JSON documents.</p>
            </section>
          </div>
          <aside>
            <p>Search help: page not found results may appear for stale links in the index.</p>
          </aside>
        </body>
      </html>
    HTML

    with_url_page("https://docs.python.org/3/library/json.html", html) do |page|
      payload = extract(page)

      expect(payload["markdown"]).to include("# json — JSON encoder and decoder")
      expect(payload["warnings"]).not_to include("not_found_interstitial")
    end
  end

  it "extracts pkg.go.dev fragment docs without false not-found warnings" do
    html = <<~HTML
      <html>
        <head>
          <title>http package - net/http - Go Packages</title>
        </head>
        <body>
          <div id="main-content">
            <h1>http</h1>
            <section>
              <h2 id="Client">type Client</h2>
              <p>A Client is an HTTP client.</p>
            </section>
          </div>
          <aside>
            <p>Search tips: page not found results may come from stale package indexes.</p>
          </aside>
        </body>
      </html>
    HTML

    with_url_page("https://pkg.go.dev/net/http#Client", html) do |page|
      payload = extract(page)

      expect(payload["title"]).to eq("type Client")
      expect(payload["markdown"]).to include("# type Client")
      expect(payload["markdown"]).to include("A Client is an HTTP client")
      expect(payload["warnings"]).not_to include("not_found_interstitial")
    end
  end

  it "keeps docs pages in article mode even when same-page link rails are dense" do
    html = <<~HTML
      <html>
        <head>
          <title>Array.prototype.map() - JavaScript | MDN</title>
        </head>
        <body>
          <main>
            <article class="main-page-content">
              <h1>Array.prototype.map()#</h1>
              <div>
                <a href="#content">Skip to main content</a>
                <a href="#browser_compatibility">See full compatibility</a>
                <a href="#examples">Examples</a>
                <a href="#description">Description</a>
                <a href="#syntax">Syntax</a>
                <a href="#parameters">Parameters</a>
              </div>
              <p>The <code>map()</code> method of Array instances creates a new array populated with the results of calling a provided function on every element in the calling array.</p>
              <h2 id="description">Description</h2>
              <p>A callback function is invoked once for each element.</p>
            </article>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Array/map", html) do |page|
      payload = extract(page)

      expect(payload["contentType"]).to eq("article")
      expect(payload["markdown"]).to include("# Array.prototype.map()")
      expect(payload["markdown"]).not_to include("Skip to main content")
    end
  end

  it "does not flag substantial docs pages with security wording as bot interstitials" do
    html = <<~HTML
      <html>
        <head>
          <title>Quickstart — Flask Documentation</title>
        </head>
        <body>
          <main>
            <article>
              <h1>Quickstart</h1>
              <p>This page gives a good introduction to Flask.</p>
              <h2>Debug Mode</h2>
              <p>The debugger allows executing arbitrary Python code from the browser and represents a major security risk in production.</p>
              <p>Use the <code>--debug</code> option during development only.</p>
              <pre><code>flask --app hello run --debug</code></pre>
            </article>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://flask.palletsprojects.com/en/stable/quickstart/", html) do |page|
      payload = extract(page)

      expect(payload["markdown"]).to include("# Quickstart")
      expect(payload["warnings"]).not_to include("bot_or_access_interstitial")
    end
  end

  it "removes GitHub clipboard controls without removing copy prose" do
    html = fixture_contents(File.expand_path('../../fixtures/github_rest_clipboard.html', __dir__))

    with_url_page("https://docs.github.com/en/rest/repos/repos?apiVersion=2022-11-28", html) do |page|
      markdown = extract(page).fetch("markdown")

      expect(markdown).to include("Lists repositories for an organization.")
      expect(markdown).to include("Copy a repository before changing it.")
      expect(markdown).to include("Copy configuration")
      expect(markdown).not_to include("Copy to clipboard")
    end
  end

  it "keeps runnable Rust examples as fenced source without widget URLs" do
    html = fixture_contents(File.expand_path('../../fixtures/rustdoc_runnable_example.html', __dir__))

    with_url_page("https://doc.rust-lang.org/std/vec/struct.Vec.html", html) do |page|
      markdown = extract(page).fetch("markdown")

      expect(markdown).to include("```")
      expect(markdown).to include("let values = vec![1, 2, 3];")
      expect(markdown).not_to include("play.rust-lang.org")
      expect(markdown).not_to include("See .")
    end
  end

  it "preserves Docusaurus cards, admonitions, and only the selected tab" do
    html = fixture_contents(File.expand_path('../../fixtures/docusaurus_widgets.html', __dir__))

    with_url_page("https://docusaurus.io/docs/search", html) do |page|
      markdown = extract(page).fetch("markdown")

      expect(markdown).to include("**NOTE:**")
      expect(markdown).to include("Query API")
      expect(markdown).to include("### JavaScript")
      expect(markdown).to include("search(query)")
      expect(markdown).not_to include("search(query, locale)")
    end
  end
end
