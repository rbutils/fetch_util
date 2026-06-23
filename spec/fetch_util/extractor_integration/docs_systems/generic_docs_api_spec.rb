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

  it "extracts redoc api docs into readable parameters and json samples" do
    html = <<~HTML
            <html>
              <head>
                <title>Redocly Museum API (1.0.0)</title>
                <meta name="generator" content="Redocly" />
              </head>
              <body>
                <div class="redoc-wrap">
                  <aside class="menu-content">Sidebar navigation</aside>
                  <div class="api-content" role="main">
                    <h1>Redocly Museum API (1.0.0)</h1>
                    <p>Download OpenAPI specification:</p>
                    <p>An imaginary, but delightful Museum API for interacting with museum services and information.</p>
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
      expect(markdown).to include("# Redocly Museum API (1.0.0)")
      expect(markdown).to include("## Get museum hours")
      expect(markdown).to include("- `startDate` (string; Example: startDate=2023-02-23): The starting date to retrieve future operating hours from.")
      expect(markdown).to include("```json")
      expect(markdown).to include('"date": "2023-09-11"')
      expect(markdown).not_to include("Download OpenAPI specification")
      expect(markdown).not_to include("Payload")
      expect(markdown).not_to include("Museum opening hoursMuseum opening hours")
    end
  end
end
