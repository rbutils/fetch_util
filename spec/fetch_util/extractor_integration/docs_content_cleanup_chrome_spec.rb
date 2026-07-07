# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'FetchUtil extractor integration - docs content cleanup chrome' do
  include_context 'extractor integration helpers'

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
      payload = extract(page)

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
      payload = extract(page)
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
      payload = extract(page)

      expect(payload["markdown"]).to include("# What is AWS Lambda?")
      expect(payload["markdown"]).to include("AWS Lambda is a compute service")
      expect(payload["markdown"]).not_to include("Select your cookie preferences")
      expect(payload["markdown"]).not_to include("AWS Builder Center")
    end
  end

  it "removes inline consent text that now lives in shared noise patterns" do
    html = <<~HTML
      <html>
        <head>
          <title>Docs sample</title>
        </head>
        <body>
          <main>
            <article>
              <h1>Docs sample</h1>
              <p>Useful documentation content stays here.</p>
            </article>
            <footer>
              <p>Cookie manager</p>
              <p>Got it!</p>
              <p>Your cookie preferences</p>
            </footer>
          </main>
        </body>
      </html>
    HTML

    with_page(html) do |page|
      payload = extract(page)

      expect(payload["markdown"]).to include("Useful documentation content stays here.")
      expect(payload["markdown"]).not_to include("Cookie manager")
      expect(payload["markdown"]).not_to include("Got it!")
      expect(payload["markdown"]).not_to include("Your cookie preferences")
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
      payload = extract(page)

      expect(payload["markdown"]).to include("# <div>: The Content Division element")
      expect(payload["markdown"]).to include("generic container for flow content")
      expect(payload["markdown"]).not_to include("Try it")
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
      payload = extract(page)

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
      payload = extract(page)
      markdown = payload["markdown"].delete("\\")

      expect(markdown).to include("- `accept` (string): Setting to application/vnd.github+json is recommended.")
      expect(markdown).to include("```")
      expect(markdown).to include("curl -L")
      expect(markdown).not_to include("Copy to clipboard")
    end
  end

  it "extracts all operations from GitHub REST reference pages" do
    html = <<~HTML
      <html>
        <head>
          <title>REST API endpoints for repositories - GitHub Docs</title>
          <meta property="og:site_name" content="GitHub Docs">
        </head>
        <body>
          <main id="main-content">
            <nav data-testid="breadcrumbs-in-article">REST API / Repositories</nav>
            <h1>REST API endpoints for repositories</h1>
            <p>Use the REST API to manage repositories on GitHub.</p>
            <div class="MarkdownContent_markdownBody__v5MYy markdown-body pt-3 pb-4"></div>
            <div class="MarkdownContent_markdownBody__v5MYy markdown-body pt-3 pb-4">
              <section>
                <h2>List organization repositories</h2>
                <p>Lists repositories for the specified organization.</p>
                <h3>Parameters for "List organization repositories"</h3>
                <table><tbody><tr><td><code>org</code> <span>string</span><p>The organization name.</p></td></tr></tbody></table>
              </section>
              <section>
                <h2>Create an organization repository</h2>
                <p>Creates a new repository in the specified organization.</p>
                <h3>Code samples for "Create an organization repository"</h3>
                <div class="RestCodeSamples_requestCodeBlock__SgBKI">POST /orgs/{org}/repos</div>
              </section>
              <section>
                <h2>Get a repository</h2>
                <p>Gets a repository using the owner and repository name.</p>
              </section>
            </div>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://docs.github.com/en/rest/repos/repos", html) do |page|
      payload = extract(page)
      markdown = payload["markdown"].delete("\\")

      expect(markdown).to include("# REST API endpoints for repositories")
      expect(markdown).to include("## List organization repositories")
      expect(markdown).to include("## Create an organization repository")
      expect(markdown).to include("Creates a new repository in the specified organization")
      expect(markdown).to include("## Get a repository")
      expect(markdown).to include("POST /orgs/{org}/repos")
      expect(markdown).not_to include("REST API / Repositories")
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
      payload = extract(page)
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
      payload = extract(page)

      expect(payload["markdown"]).to include("# shops_api")
      expect(payload["markdown"]).to include("Returns the list of shops connected")
      expect(payload["markdown"]).to include("## Input parameters")
      expect(payload["markdown"]).not_to include("Method list")
      expect(payload["markdown"]).not_to include("Test your request")
      expect(payload["markdown"]).not_to include("Changelog")
    end
  end
end
