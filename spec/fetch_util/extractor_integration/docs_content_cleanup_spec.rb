# frozen_string_literal: true

RSpec.describe 'FetchUtil extractor integration' do
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
      payload = FetchUtil::Extractor.new.extract(page)

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
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("Page not found")
      expect(payload["warnings"]).to include("not_found_interstitial")
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
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("# route.js")
      expect(payload["markdown"]).to include("Route Handlers allow you to create custom request handlers")
      expect(payload["warnings"]).not_to include("browser_support_interstitial")
      expect(payload["warnings"]).not_to include("consent_interstitial")
    end
  end

  it "cleans react docs toc and copy controls" do
    html = <<~HTML
      <html>
        <head>
          <title>useEffect – React</title>
        </head>
        <body>
          <main>
            <article>
              <h1>useEffect</h1>
              <button>Copy page</button>
              <section>
                <h2>On this page</h2>
                <a href="#reference">Reference</a>
                <a href="#usage">Usage</a>
              </section>
              <p><code>useEffect</code> is a React Hook that lets you synchronize a component with an external system.</p>
              <h2 id="reference">Reference</h2>
              <pre><code>useEffect(setup, dependencies?)</code></pre>
            </article>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://react.dev/reference/react/useEffect", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("# useEffect")
      expect(payload["markdown"]).to include("synchronize a component with an external system")
      expect(payload["markdown"]).not_to include("On this page")
      expect(payload["markdown"]).not_to include("Copy page")
    end
  end

  it "formats stripe api headings and removes utility chrome" do
    html = <<~HTML
      <html>
        <head>
          <title>The Charge object | Stripe API Reference</title>
        </head>
        <body>
          <main>
            <article>
              <h1>The Charge object</h1>
              <div>Ask about this section</div>
              <button>Copy for LLM</button>
              <a href="#markdown">View as Markdown</a>
              <h3>Attributes</h3>
              <h4>idstring</h4>
              <p>Unique identifier for the object.</p>
              <h4>balance_transactionnullable stringExpandable</h4>
              <p>ID of the balance transaction.</p>
              <h2>Create a chargeDeprecated</h2>
            </article>
          </main>
        </body>
      </html>
    HTML

    with_page(html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)
      markdown = payload["markdown"].delete("\\")

      expect(markdown).to include("id - string")
      expect(markdown).to include("balance_transaction - nullable string expandable")
      expect(markdown).to include("Create a charge [Deprecated]")
      expect(markdown).not_to include("Ask about this section")
      expect(markdown).not_to include("Copy for LLM")
      expect(markdown).not_to include("View as Markdown")
    end
  end

  it "removes aws cookie preference and marketing tip chrome" do
    html = <<~HTML
      <html>
        <head>
          <title>What is AWS Lambda? - AWS Lambda</title>
        </head>
        <body>
          <main id="main-content">
            <h2>Select your cookie preferences</h2>
            <p>Customize cookie preferences</p>
            <div>
              <h6>Tip</h6>
              <p>Visit the AWS Builder Center for guided workshops.</p>
            </div>
            <h1>What is AWS Lambda?</h1>
            <p>AWS Lambda is a compute service that lets you run code without provisioning or managing servers.</p>
            <h2>How Lambda works</h2>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://docs.aws.amazon.com/lambda/latest/dg/welcome.html", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("# What is AWS Lambda?")
      expect(payload["markdown"]).to include("AWS Lambda is a compute service")
      expect(payload["markdown"]).not_to include("Select your cookie preferences")
      expect(payload["markdown"]).not_to include("AWS Builder Center")
    end
  end

  it "removes mdn try-it chrome from docs pages" do
    html = <<~HTML
      <html>
        <head>
          <title>&lt;div&gt;: The Content Division element - HTML | MDN</title>
        </head>
        <body>
          <main>
            <article class="main-page-content">
              <h1>&lt;div&gt;: The Content Division element</h1>
              <section>
                <h2>Try it</h2>
              </section>
              <p>The <code>&lt;div&gt;</code> element is the generic container for flow content.</p>
            </article>
          </main>
        </body>
      </html>
    HTML

    with_page(html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("# <div>: The Content Division element")
      expect(payload["markdown"]).to include("generic container for flow content")
      expect(payload["markdown"]).not_to include("Try it")
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
      payload = FetchUtil::Extractor.new.extract(page)

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
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("# json — JSON encoder and decoder")
      expect(payload["warnings"]).not_to include("not_found_interstitial")
    end
  end

  it "focuses docs fragment urls on the requested docker section" do
    html = <<~HTML
      <html>
        <head>
          <title>Dockerfile reference</title>
        </head>
        <body>
          <main>
            <article>
              <h1>Dockerfile reference</h1>
              <section>
                <h2 id="overview">Overview</h2>
                <p>The Dockerfile supports the following instructions.</p>
              </section>
              <section>
                <h2 id="run">RUN</h2>
                <p>The <code>RUN</code> instruction executes build commands.</p>
              </section>
            </article>
            <aside>
              <p>Search index note: page not found results may include old anchors.</p>
            </aside>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://docs.docker.com/reference/dockerfile/#run", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["title"]).to eq("RUN")
      expect(payload["markdown"]).to include("# RUN")
      expect(payload["markdown"]).to include("executes build commands")
      expect(payload["warnings"]).not_to include("not_found_interstitial")
    end
  end

  it "focuses docs fragment urls when the target is an a[name] anchor with selector metacharacters" do
    html = <<~HTML
      <html>
        <head>
          <title>Dockerfile reference</title>
        </head>
        <body>
          <main>
            <article>
              <h1>Dockerfile reference</h1>
              <section>
                <h2 id="overview">Overview</h2>
                <p>The Dockerfile supports the following instructions.</p>
              </section>
              <section>
                <a name='run"quoted'></a>
                <h2>RUN quoted</h2>
                <p>The <code>RUN</code> instruction executes build commands for quoted anchors.</p>
              </section>
            </article>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://docs.docker.com/reference/dockerfile/#run%22quoted", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["title"]).to eq("RUN quoted")
      expect(payload["markdown"]).to include("# RUN quoted")
      expect(payload["markdown"]).to include("quoted anchors")
      expect(payload["markdown"]).not_to include("Overview")
    end
  end

  it "cleans rustdoc utility chrome from docs pages" do
    html = <<~HTML
      <html>
        <head>
          <title>Function read_to_string Copy item path</title>
        </head>
        <body>
          <main>
            <a title="show sidebar" href="/std/all.html"></a>
            <a href="?search=">Search</a>
            <a href="/settings.html">Settings</a>
            <a href="/help.html">Help</a>
            <h1>Function read_to_string Copy item path</h1>
            <p>Expand description</p>
            <p>Reads the entire contents of a file into a string.</p>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://doc.rust-lang.org/std/fs/fn.read_to_string.html", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["title"]).to eq("Function read_to_string")
      expect(payload["markdown"]).to include("# Function read_to_string")
      expect(payload["markdown"]).to include("Reads the entire contents of a file into a string")
      expect(payload["markdown"]).not_to include("Copy item path")
      expect(payload["markdown"]).not_to include("Search")
      expect(payload["markdown"]).not_to include("Settings")
      expect(payload["markdown"]).not_to include("Help")
      expect(payload["markdown"]).not_to include("Expand description")
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
      payload = FetchUtil::Extractor.new.extract(page)

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
      payload = FetchUtil::Extractor.new.extract(page)

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
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("# Quickstart")
      expect(payload["warnings"]).not_to include("bot_or_access_interstitial")
    end
  end

  it "compacts github docs parameter tables and code samples" do
    html = <<~HTML
          <html>
            <head>
              <title>REST API endpoints for issues - GitHub Docs</title>
              <meta property="og:site_name" content="GitHub Docs">
            </head>
            <body>
              <main>
                <div class="markdown-body">
                  <h1>REST API endpoints for issues</h1>
                  <h2>Parameters</h2>
                  <table>
                    <caption>Parameters</caption>
                    <thead>
                      <tr><th>Name, Type, Description</th></tr>
                    </thead>
                    <tbody>
                      <tr>
                        <td>
                          <div>
                            <div><code>accept</code> <span>string</span></div>
                            <div><p>Setting to <code>application/vnd.github+json</code> is recommended.</p></div>
                          </div>
                        </td>
                      </tr>
                    </tbody>
                  </table>
                  <div class="RestCodeSamples_requestCodeBlock__SgBKI">curl -L \
      -H "Accept: application/vnd.github+json" \
      https://api.github.com/issues</div>
                  <button>Copy to clipboard</button>
                </div>
              </main>
            </body>
          </html>
    HTML

    with_page(html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)
      markdown = payload["markdown"].delete("\\")

      expect(markdown).to include("- `accept` (string): Setting to application/vnd.github+json is recommended.")
      expect(markdown).to include("```")
      expect(markdown).to include("curl -L")
      expect(markdown).not_to include("Copy to clipboard")
    end
  end

  it "extracts baselinker method pages from inline examples when the DOM is empty" do
    html = <<~HTML
            <html>
              <head>
                <title>API documentation - baselinker.com</title>
              </head>
              <body>
                <div id="main">
                  <div class="main_text">
                    <a href="/"><div class="grey_button">Method list</div></a>
                    <a href="/?tester&amp;method=shops_api"><div class="grey_button">Test your request</div></a>
                    <a href="/?changelog"><div class="grey_button">Changelog</div></a>
                  </div>
                </div>
                <script>
                  function paste_example() {
                    examples = new Array();
                    examples['shops_api'] = '{\n\\
      "shop_id": 123,\n\\
      "include_inactive": false\n\\
      }';
                  }
                </script>
              </body>
            </html>
    HTML

    with_url_page("https://api.baselinker.com/index.php?method=shops_api", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)
      markdown = payload["markdown"].delete("\\")

      expect(markdown).to include("# shops_api")
      expect(markdown).to include("Baselinker API request example for the `shops_api` method.")
      expect(markdown).to include('```json')
      expect(markdown).to include('"shop_id": 123')
      expect(markdown).to include('"include_inactive": false')
      expect(markdown).not_to include("Method list")
    end
  end

  it "extracts baselinker method pages from visible dom content through shared docs helpers" do
    html = <<~HTML
      <html>
        <head>
          <title>shops_api - API documentation - baselinker.com</title>
        </head>
        <body>
          <div id="main">
            <div class="main_text">
              <a href="/"><div class="grey_button">Method list</div></a>
              <a href="/?tester&amp;method=shops_api"><div class="grey_button">Test your request</div></a>
              <a href="/?changelog"><div class="grey_button">Changelog</div></a>
              <h1>shops_api</h1>
              <p>Returns the list of shops connected to the current Baselinker account.</p>
              <h2>Input parameters</h2>
              <p><code>shop_id</code> identifies the shop to return.</p>
            </div>
          </div>
        </body>
      </html>
    HTML

    with_url_page("https://api.baselinker.com/index.php?method=shops_api", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("# shops_api")
      expect(payload["markdown"]).to include("Returns the list of shops connected")
      expect(payload["markdown"]).to include("## Input parameters")
      expect(payload["markdown"]).not_to include("Method list")
      expect(payload["markdown"]).not_to include("Test your request")
      expect(payload["markdown"]).not_to include("Changelog")
    end
  end
end
