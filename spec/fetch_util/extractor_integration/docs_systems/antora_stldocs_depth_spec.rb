# frozen_string_literal: true

RSpec.describe 'FetchUtil extractor integration' do
  include_context 'extractor integration helpers'

  it "keeps antora landing card details attached to distinct card links" do
    html = <<~HTML
      <html>
        <head>
          <title>Fedora Documentation :: Fedora Docs</title>
          <meta name="generator" content="Antora 3.1.14">
        </head>
        <body>
          <main class="main">
            <article class="doc">
              <h2>User Documentation</h2>
              <div class="homepage-card-grid">
                <div class="homepage-card">
                  <h3><a class="homepage-link homepage-link-primary" href="../fedora/latest/">Fedora Linux</a></h3>
                  <p>The Fedora Linux documentation hub.</p>
                  <ul><li>Installation and administration guides.</li></ul>
                </div>
                <div class="homepage-card">
                  <h3><a class="homepage-link homepage-link-secondary" href="../quick-docs/">Quick Docs</a></h3>
                  <p>Short how-to and FAQ-style documentation.</p>
                </div>
                <div class="homepage-card">
                  <h3><a class="homepage-link homepage-link-secondary" href="../epel/">EPEL</a></h3>
                  <p>Extra Packages for Enterprise Linux.</p>
                </div>
              </div>
            </article>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://docs.fedoraproject.org/en-US/docs/", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)
      markdown = payload["markdown"]

      expect(payload["contentType"]).to eq("list")
      expect(markdown).to include("- [Fedora Linux](../fedora/latest/) - The Fedora Linux documentation hub.")
      expect(markdown).to include("- [Quick Docs](../quick-docs/) - Short how-to and FAQ-style documentation.")
      expect(markdown).to include("- [EPEL](../epel/) - Extra Packages for Enterprise Linux.")
      expect(markdown).not_to include("Fedora Linux](../fedora/latest/) - The Fedora Linux documentation hub. Installation and administration guides. Quick Docs")
    end
  end

  it "does not regress antora landing pages with a single card" do
    html = <<~HTML
      <html>
        <head>
          <title>Project Docs</title>
          <meta name="generator" content="Antora 3.1.14">
        </head>
        <body>
          <main class="main">
            <article class="doc">
              <h2>Start Here</h2>
              <div class="homepage-card">
                <a class="homepage-link homepage-link-primary" href="./guide/">User Guide</a>
                <p>Read the main user guide.</p>
              </div>
            </article>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://docs.example.test/", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["contentType"]).to eq("list")
      expect(payload["markdown"]).to include("# Project Docs")
      expect(payload["markdown"]).to include("- [User Guide](./guide/) - Read the main user guide.")
    end
  end

  it "surfaces nested stldocs schema and method property groups compactly" do
    html = <<~HTML
      <html>
        <head>
          <title>Messages - API Reference</title>
          <meta name="generator" content="Astro v5.0.0">
        </head>
        <body>
          <div class="stldocs-root">
            <main>
              <article>
                <h1>Messages</h1>
                <div class="stldocs-resource-description">Create and manage messages in the API.</div>
                <div class="stldocs-method-summary">
                  <h2>Create a Message</h2>
                  <div class="stldocs-method-route">POST /v1/messages</div>
                  <p>Send a structured input to the model.</p>
                  <section class="stldocs-parameters">
                    <h3>Request parameters</h3>
                    <details class="stldocs-property">
                      <summary>
                        <div class="stldocs-property-declaration">metadata: object</div>
                        <div class="stldocs-property-description">Custom metadata attached to the request.</div>
                      </summary>
                      <details class="stldocs-property">
                        <summary>
                          <div class="stldocs-property-declaration">trace_id: string</div>
                          <div class="stldocs-property-description">Trace identifier for debugging.</div>
                        </summary>
                      </details>
                    </details>
                  </section>
                </div>
                <div class="stldocs-resource-content-group">
                  <h2>Models</h2>
                  <details class="stldocs-property">
                    <summary>
                      <div class="stldocs-property-declaration">Message = object { id, content }</div>
                      <div class="stldocs-property-description">Represents a message in the API.</div>
                    </summary>
                    <details class="stldocs-property">
                      <summary>
                        <div class="stldocs-property-declaration">content: array of blocks</div>
                        <div class="stldocs-property-description">Ordered content blocks for the message.</div>
                      </summary>
                      <details class="stldocs-property">
                        <summary>
                          <div class="stldocs-property-declaration">text: string</div>
                          <div class="stldocs-property-description">Text displayed to the user.</div>
                        </summary>
                      </details>
                    </details>
                  </details>
                </div>
              </article>
            </main>
          </div>
        </body>
      </html>
    HTML

    with_url_page("https://docs.example.test/reference/messages", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)
      markdown = payload["markdown"].delete("\\")

      expect(markdown).to include("- Create a Message (POST/v1/messages): Send a structured input to the model.")
      expect(markdown).to include("  - Request parameters")
      expect(markdown).to include("    - `metadata: object`: Custom metadata attached to the request.")
      expect(markdown).to include("      - `trace_id: string`: Trace identifier for debugging.")
      expect(markdown).to include("- `content: array of blocks`: Ordered content blocks for the message.")
      expect(markdown).to include("  - `text: string`: Text displayed to the user.")
    end
  end

  it "does not fabricate nested stldocs depth for shallow schemas" do
    html = <<~HTML
      <html>
        <head>
          <title>Messages - API Reference</title>
          <meta name="generator" content="Astro v5.0.0">
        </head>
        <body>
          <main>
            <article>
              <h1>Messages</h1>
              <div class="stldocs-method-summary">
                <h2>List Messages</h2>
                <div class="stldocs-method-route">GET /v1/messages</div>
                <p>List message records.</p>
              </div>
              <details class="stldocs-property">
                <summary>
                  <div class="stldocs-property-declaration">Message = object { id }</div>
                  <div class="stldocs-property-description">Represents a shallow message.</div>
                </summary>
                <details class="stldocs-property">
                  <summary>
                    <div class="stldocs-property-declaration">id: string</div>
                    <div class="stldocs-property-description">Unique message identifier.</div>
                  </summary>
                </details>
              </details>
            </article>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://docs.example.test/reference/messages-shallow", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)
      markdown = payload["markdown"].delete("\\")

      expect(markdown).to include("- `id: string`: Unique message identifier.")
      expect(markdown).not_to include("  - `trace_id")
      expect(markdown).not_to include("Request parameters")
    end
  end
end
