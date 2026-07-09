# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'FetchUtil extractor integration - generic API docs systems' do
  include_context 'extractor integration helpers'

  it "extracts starlight or stldocs api pages through generic docs-system detection" do
    html = <<~HTML
      <html>
        <head>
          <title>Messages - API Reference</title>
          <meta name="generator" content="Astro v5.0.0">
        </head>
        <body>
          <div class="stldocs-root">
            <aside class="stldocs-sidebar">API Reference Messages Models</aside>
            <main>
              <section class="stldocs-expander-summary">On this page</section>
              <article>
                <h1>Messages</h1>
                <p>Create and manage messages in the API.</p>
                <div class="stldocs-resource-description">Create and manage messages in the API.</div>
                <div class="stldocs-method-summary">
                  <h2>Create a Message</h2>
                  <div class="stldocs-method-route">POST /v1/messages</div>
                  <p>Send a structured input to the model.</p>
                </div>
                <div class="stldocs-method-summary">
                  <h2>Count tokens in a Message</h2>
                  <div class="stldocs-method-route">POST /v1/messages/count_tokens</div>
                  <p>Estimate token usage before sending the full request.</p>
                </div>
                <div class="stldocs-resource-content-group">
                  <h2>Models</h2>
                  <details class="stldocs-property">
                    <summary>
                      <div class="stldocs-property-info">
                        <div class="stldocs-property-declaration">Message = object { id, role, content }</div>
                        <div class="stldocs-property-description">Represents a message in the API.</div>
                      </div>
                    </summary>
                    <div class="stldocs-expander-content">
                      <div class="stldocs-property-children">
                        <div class="stldocs-properties">
                          <details class="stldocs-property">
                            <summary>
                              <div class="stldocs-property-info">
                                <div class="stldocs-property-declaration">id: string</div>
                                <div class="stldocs-property-description">Unique message identifier.</div>
                              </div>
                            </summary>
                          </details>
                          <details class="stldocs-property">
                            <summary>
                              <div class="stldocs-property-info">
                                <div class="stldocs-property-declaration">role: string</div>
                                <div class="stldocs-property-description">The speaker role.</div>
                              </div>
                            </summary>
                          </details>
                          <details class="stldocs-property">
                            <summary>
                              <div class="stldocs-property-info">
                                <div class="stldocs-property-declaration">content: array of blocks</div>
                                <div class="stldocs-property-description">Ordered content blocks for the message.</div>
                              </div>
                            </summary>
                          </details>
                          <details class="stldocs-property">
                            <summary>
                              <div class="stldocs-property-info">
                                <div class="stldocs-property-declaration">"assistant"</div>
                                <div class="stldocs-property-description">Literal enum entry.</div>
                              </div>
                            </summary>
                          </details>
                        </div>
                      </div>
                    </div>
                  </details>
                </div>
              </article>
            </main>
          </div>
        </body>
      </html>
    HTML

    with_page(html) do |page|
      payload = extract(page)
      markdown = payload["markdown"].delete("\\")

      expect(markdown).to include("# Messages")
      expect(markdown).to include("Create and manage messages in the API")
      expect(markdown).to include("- Create a Message (POST/v1/messages): Send a structured input to the model.")
      expect(markdown).to include("- Count tokens in a Message (POST/v1/messages/count_tokens): Estimate token usage before sending the full request.")
      expect(markdown).to include("## Schemas")
      expect(markdown).to include("### Message = object { id, role, content }")
      expect(markdown).to include("Represents a message in the API.")
      expect(markdown).to include("- `id: string`: Unique message identifier.")
      expect(markdown).to include("- `role: string`: The speaker role.")
      expect(markdown).not_to include("Literal enum entry")
      expect(markdown).not_to include("API Reference Messages Models")
      expect(markdown).not_to include("On this page")
    end
  end

  it "omits boilerplate stldocs metadata descriptions when no real resource summary exists" do
    html = <<~HTML
      <html>
        <head>
          <title>Messages - API Reference</title>
          <meta name="generator" content="Astro v5.0.0">
          <meta name="description" content="API reference for Messages endpoints">
        </head>
        <body>
          <div class="stldocs-root">
            <main>
              <article>
                <h1>Messages</h1>
                <div class="stldocs-method-summary">
                  <h2>Create a Message</h2>
                  <div class="stldocs-method-route">POST /v1/messages</div>
                  <p>Send a structured input to the model.</p>
                </div>
                <div class="stldocs-resource-content-group">
                  <details class="stldocs-property">
                    <summary>
                      <div class="stldocs-property-info">
                        <div class="stldocs-property-declaration">Message = object { id }</div>
                        <div class="stldocs-property-description">Nested property description should not become the page summary.</div>
                      </div>
                    </summary>
                    <div class="stldocs-expander-content">
                      <div class="stldocs-property-children">
                        <div class="stldocs-properties">
                          <details class="stldocs-property">
                            <summary>
                              <div class="stldocs-property-info">
                                <div class="stldocs-property-declaration">id: string</div>
                                <div class="stldocs-property-description">Unique message identifier.</div>
                              </div>
                            </summary>
                          </details>
                        </div>
                      </div>
                    </div>
                  </details>
                </div>
              </article>
            </main>
          </div>
        </body>
      </html>
    HTML

    with_page(html) do |page|
      payload = extract(page)

      expect(payload["markdown"]).to include("# Messages")
      expect(payload["markdown"]).to include("- Create a Message (POST/v1/messages): Send a structured input to the model.")
      expect(payload["markdown"]).not_to include("API reference for Messages endpoints")
      expect(payload["markdown"]).to include("## Schemas")
    end
  end

  it "keeps stldocs api reference content instead of downgrading to chrome links" do
    html = <<~HTML
      <html>
        <head>
          <title>Chat | Sample API Reference</title>
          <meta name="generator" content="Astro v6.0.4">
          <meta property="og:site_name" content="Sample API Reference">
        </head>
        <body>
          <nav>
            <a href="/api/docs/guides/production-best-practices">Production best practices</a>
            <a href="/api/docs/actions/production">Production</a>
            <a href="/commerce/specs/api/products">Products</a>
            <a href="/ads/product-feeds">Product feeds</a>
          </nav>
          <main class="astro-jftc2ajk">
            <div class="stl-ui-prose stl-content-panel astro-efu33vlz">
              <div class="sl-markdown-content">
                <div class="not-content">
                  <div class="stldocs-root stl-ui-not-prose">
                    <div class="stldocs-overview">
                      <h1>Chat</h1>
                      <div class="stldocs-resource">
                        <div class="stldocs-resource-content">
                          <h2>ChatCompletions</h2>
                           <div class="stldocs-resource-description">Given a sequence of messages, the service returns a response.</div>
                          <div class="stldocs-resource-content-group">
                            <div class="stldocs-method-summary">
                              <div class="stldocs-method-header">
                                <h5 class="stldocs-method-title"><a href="#create-chat-completion">Create chat completion</a></h5>
                                <div class="stldocs-method-route">POST /chat/completions</div>
                              </div>
                            </div>
                            <div class="stldocs-method-summary">
                              <div class="stldocs-method-header">
                                <h5 class="stldocs-method-title"><a href="#list-chat-completions">List Chat Completions</a></h5>
                                <div class="stldocs-method-route">GET /chat/completions</div>
                              </div>
                            </div>
                          </div>
                          <div class="stldocs-resource-content-group">
                            <h3>Models</h3>
                            <details class="stldocs-property">
                              <summary class="stldocs-expander-summary">
                                <div class="stldocs-property-info">
                                  <div class="stldocs-property-declaration">ChatCompletion = object { id, choices, created }</div>
                                  <div class="stldocs-property-description">Represents a chat completion response returned by model, based on the provided input.</div>
                                </div>
                              </summary>
                              <div class="stldocs-expander-content">
                                <div class="stldocs-properties">
                                  <details class="stldocs-property">
                                    <summary><div class="stldocs-property-declaration">id: string</div><div class="stldocs-property-description">A unique identifier for the chat completion.</div></summary>
                                  </details>
                                </div>
                              </div>
                            </details>
                          </div>
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </main>
        </body>
      </html>
    HTML

    with_url_page('https://developers.openai.com/api/reference/resources/chat', html) do |page|
      payload = extract(page)
      markdown = payload['markdown'].delete('\\')

      expect(payload['contentType']).to eq('article')
      expect(markdown).to include('# Chat')
      expect(markdown).to include('Given a sequence of messages')
      expect(markdown).to include('- Create chat completion (POST/chat/completions)')
      expect(markdown).to include('- List Chat Completions (GET/chat/completions)')
      expect(markdown).to include('### ChatCompletion = object { id, choices, created }')
      expect(markdown).not_to include('Production best practices')
    end
  end

  it "extracts redoc api docs into readable parameters and json samples" do
    html = <<~HTML
            <html>
              <head>
                <title>Sample Gallery API (1.0.0)</title>
                <meta name="generator" content="Redocly" />
              </head>
              <body>
                <div class="redoc-wrap">
                  <aside class="menu-content">Sidebar navigation</aside>
                  <div class="api-content" role="main">
                    <h1>Sample Gallery API (1.0.0)</h1>
                    <p>Download OpenAPI specification:</p>
                    <p>An invented Gallery API for browsing exhibits and opening hours.</p>
                    <section>
                      <h2>Get museum hours</h2>
                      <p>Get upcoming museum operating hours</p>
                      <h5>query Parameters</h5>
                      <table>
                        <tbody>
                          <tr>
                            <td kind="field" title="startDate"><span class="property-name">startDate</span><div>required</div></td>
                            <td>
                              <span>string</span>
                              <span>Example: startDate=2023-02-23</span>
                              <div><p>The starting date to retrieve future operating hours from.</p></div>
                            </td>
                          </tr>
                        </tbody>
                      </table>
                      <h3>Response samples</h3>
                      <div data-rttabs="true">
                        <ul class="react-tabs__tab-list" role="tablist">
                          <li role="tab">200</li>
                        </ul>
                      </div>
                      <select class="dropdown-select">
                        <option selected>Museum opening hours</option>
                        <option>The museum is closed</option>
                      </select>
                      <label>Museum opening hours</label>
                      <div class="redoc-json"><code>{
        "date": "2023-09-11",
        "timeOpen": "09:00"
      }</code></div>
                    </section>
                  </div>
                </div>
              </body>
            </html>
    HTML

    with_url_page("https://example.test/redoc", html) do |page|
      payload = extract(page)
      markdown = payload["markdown"].delete("\\")

      expect(payload["contentType"]).to eq("article")
      expect(markdown).to include("# Sample Gallery API (1.0.0)")
      expect(markdown).to include("## Get museum hours")
      expect(markdown).to include("- `startDate` (string; Example: startDate=2023-02-23): The starting date to retrieve future operating hours from.")
      expect(markdown).to include("```json")
      expect(markdown).to include('"date": "2023-09-11"')
      expect(markdown).not_to include("Download OpenAPI specification")
      expect(markdown).not_to include("Payload")
      expect(markdown).not_to include("Museum opening hoursMuseum opening hours")
    end
  end

  it "keeps every substantive Redoc response panel in DOM order" do
    panels = (1..4).map do |index|
      "<div role=\"tabpanel\"><pre>{\"response\": #{index}}</pre></div>"
    end.join
    html = <<~HTML
      <html><head><title>Panel API</title><meta name="generator" content="Redocly"></head><body><main class="api-content"><h1>Panel API</h1><p>A response panel fixture.</p><section><h2>Responses</h2><div data-rttabs="true"><div role="tablist"><button role="tab">JSON</button></div>#{panels}</div></section></main></body></html>
    HTML

    with_url_page("https://example.test/panels", html) do |page|
      markdown = extract(page)["markdown"].delete("\\")
      expect(markdown).to include('"response": 4')
      expect(markdown.index('"response": 1')).to be < markdown.index('"response": 4')
    end
  end
end
