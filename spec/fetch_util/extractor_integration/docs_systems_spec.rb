# frozen_string_literal: true

RSpec.describe 'FetchUtil extractor integration' do
  include_context 'extractor integration helpers'

  it "extracts python docs with title-first output and fenced code blocks" do
    html = <<~HTML
            <html>
              <head>
                <title>json — JSON encoder and decoder — Python 3.14.3 documentation</title>
              </head>
              <body>
                <div class="body" role="main">
                  <section id="module-json">
                    <h1>json — JSON encoder and decoder<a class="headerlink" href="#module-json">¶</a></h1>
                    <p><strong>Source code:</strong> <a href="https://github.com/python/cpython/tree/main/Lib/json/__init__.py">Lib/json/__init__.py</a></p>
                    <dt class="sig sig-object py" id="json.dumps">json.dumps(obj, *, sort_keys=False)<a class="headerlink" href="#json.dumps">¶</a></dt>
                    <dd><p>Serialize <code>obj</code> as a JSON formatted stream.</p></dd>
                    <div class="highlight-python3"><button class="copybutton">Copy</button><pre>>>> import json
      >>> json.dumps({"a": 1}, sort_keys=True)
      '{"a": 1}'</pre></div>
                  </section>
                </div>
              </body>
            </html>
    HTML

    with_page(html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)
      markdown = payload["markdown"].delete("\\")

      expect(markdown).to include("# json — JSON encoder and decoder")
      expect(markdown).to include("### json.dumps(obj, *, sort_keys=False)")
      expect(markdown).to include("```python")
      expect(markdown).to include(">>> import json")
      expect(markdown).not_to include("Copy")
    end
  end

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
      payload = FetchUtil::Extractor.new.extract(page)
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
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("# Messages")
      expect(payload["markdown"]).to include("- Create a Message (POST/v1/messages): Send a structured input to the model.")
      expect(payload["markdown"]).not_to include("API reference for Messages endpoints")
      expect(payload["markdown"]).to include("## Schemas")
    end
  end

  it "extracts mkdocs material pages through generic docs-system detection" do
    html = <<~HTML
      <html>
        <head>
          <title>Path Parameters - FastAPI</title>
          <meta name="generator" content="mkdocs-1.6.1, mkdocs-material-9.7.1">
        </head>
        <body>
          <aside class="md-sidebar">Navigation</aside>
          <main>
            <div class="md-content">
              <div class="md-content__button">Edit this page</div>
              <article class="md-content__inner">
                <h1>Path Parameters</h1>
                <p>You can declare path parameters with the same syntax used by Python format strings.</p>
                <h2>Table of contents</h2>
                <a href="#intro">Intro</a>
              </article>
            </div>
          </main>
        </body>
      </html>
    HTML

    with_page(html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("# Path Parameters")
      expect(payload["markdown"]).to include("same syntax used by Python format strings")
      expect(payload["markdown"]).not_to include("Edit this page")
      expect(payload["markdown"]).not_to include("Table of contents")
    end
  end

  it "extracts docusaurus docs through generic docs-system detection" do
    html = <<~HTML
      <html>
        <head>
          <title>Quick-Start Guide | K3s</title>
          <meta name="generator" content="Docusaurus v3.9.2" />
        </head>
        <body>
          <div id="__docusaurus">
            <a href="#main">Skip to main content</a>
            <nav aria-label="Docs sidebar">Navigation</nav>
            <main>
              <aside>On this page</aside>
              <article>
                <div class="theme-doc-breadcrumbs">Breadcrumbs</div>
                <h1>Quick-Start Guide</h1>
                <div>Copy for LLM</div>
                <div>View as Markdown</div>
                <p>This guide will help you quickly launch a cluster with default options.</p>
                <h2>Install Script​</h2>
                <p>Run the installer script on your server.</p>
                <div class="pagination-nav">Previous Next</div>
              </article>
            </main>
          </div>
        </body>
      </html>
    HTML

    with_url_page("https://docs.k3s.io/quick-start", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["title"]).to eq("Quick-Start Guide")
      expect(payload["markdown"]).to include("# Quick-Start Guide")
      expect(payload["markdown"]).to include("quickly launch a cluster")
      expect(payload["markdown"]).to include("## Install Script")
      expect(payload["markdown"]).not_to include("Skip to main content")
      expect(payload["markdown"]).not_to include("On this page")
      expect(payload["markdown"]).not_to include("Copy for LLM")
      expect(payload["markdown"]).not_to include("View as Markdown")
      expect(payload["markdown"]).not_to include("Previous Next")
    end
  end

  it "extracts mintlify docs through generic docs-system detection" do
    html = <<~HTML
      <html>
        <head>
          <title>Introduction - Dub</title>
          <meta name="generator" content="Mintlify" />
        </head>
        <body>
          <main>
            <article>
              <nav aria-label="Table of contents">On this page</nav>
              <div>Copy for LLM</div>
              <div>View as Markdown</div>
              <div>API Reference Sidebar</div>
              <h1>Introduction</h1>
              <p>Learn how to use Dub's API to programmatically manage resources.</p>
              <h2>Base URL</h2>
              <p><code>https://api.dub.co</code></p>
            </article>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://dub.co/docs/api-reference/introduction", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["title"]).to eq("Introduction")
      expect(payload["markdown"]).to include("# Introduction")
      expect(payload["markdown"]).to include("programmatically manage resources")
      expect(payload["markdown"]).to include("## Base URL")
      expect(payload["markdown"]).not_to include("On this page")
      expect(payload["markdown"]).not_to include("Copy for LLM")
      expect(payload["markdown"]).not_to include("View as Markdown")
      expect(payload["markdown"]).not_to include("API Reference Sidebar")
    end
  end

  it "extracts fern docs through generic docs-system detection" do
    html = <<~HTML
      <html>
        <head>
          <title>Chat | Cohere</title>
          <meta name="generator" content="https://buildwithfern.com" />
        </head>
        <body>
          <main>
            <aside id="fern-sidebar">Sidebar</aside>
            <div class="fern-layout-reference">
              <article>
                <div class="toc-mobile">On this page</div>
                <header>
                  <span class="fern-breadcrumb">Endpoints / v2/chat</span>
                  <div class="fern-page-actions"><button>Copy page</button></div>
                  <h1 class="fern-page-heading">Chat</h1>
                </header>
                <div class="fern-prose">
                  <p>Generates a text response to a user message and streams it down token by token.</p>
                  <h2>Request</h2>
                  <p>Send a list of messages in chronological order.</p>
                </div>
              </article>
            </div>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://docs.cohere.com/reference/chat", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["title"]).to eq("Chat")
      expect(payload["markdown"]).to include("# Chat")
      expect(payload["markdown"]).to include("Generates a text response")
      expect(payload["markdown"]).to include("## Request")
      expect(payload["markdown"]).not_to include("Sidebar")
      expect(payload["markdown"]).not_to include("On this page")
      expect(payload["markdown"]).not_to include("Copy page")
      expect(payload["markdown"]).not_to include("Endpoints / v2/chat")
    end
  end

  it "extracts nextra docs through generic docs-system detection" do
    html = <<~HTML
      <html>
        <head>
          <title>GitHub Provider | Auth.js</title>
        </head>
        <body>
          <article class="nextra-content">
            <main>
              <div class="nextra-breadcrumb">Getting Started / Providers / GitHub</div>
              <button>Copy page</button>
              <h1>GitHub Provider</h1>
              <h2 id="resources">Resources<a href="#resources" class="subheading-anchor"></a></h2>
              <ul>
                <li><a href="https://docs.github.com">GitHub - Creating an OAuth App</a></li>
              </ul>
              <h2 id="setup">Setup<a href="#setup" class="subheading-anchor"></a></h2>
              <p>Use the GitHub provider to authenticate users with GitHub.</p>
            </main>
          </article>
        </body>
      </html>
    HTML

    with_url_page("https://authjs.dev/getting-started/providers/github", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["title"]).to eq("GitHub Provider")
      expect(payload["markdown"]).to include("# GitHub Provider")
      expect(payload["markdown"]).to include("## Resources")
      expect(payload["markdown"]).to include("## Setup")
      expect(payload["markdown"]).not_to include("Copy page")
      expect(payload["markdown"]).not_to include("Getting Started / Providers / GitHub")
    end
  end

  it "extracts vitepress docs through generic docs-system detection" do
    html = <<~HTML
      <html>
        <head>
          <title>Getting Started | Vite</title>
          <meta name="generator" content="VitePress v1.6.4" />
        </head>
        <body>
          <div id="app">
            <a href="#VPContent" class="VPSkipLink">Skip to content</a>
            <nav class="VPNav">Navigation</nav>
            <aside class="VPSidebar">Sidebar</aside>
            <main id="VPContent">
              <article class="VPDoc">
                <div><a href="https://srv.carbonads.net/ads/click/x/demo">ads via Carbon</a></div>
                <p>Are you an LLM? You can read better optimized documentation at /guide.md for this page in Markdown format</p>
                <h1>Getting Started</h1>
                <p>Vite is a build tool that aims to provide a faster development experience.</p>
                <h2>Overview​</h2>
                <p>It consists of a dev server and a build command.</p>
                <div class="VPDocFooter">Previous page Next page</div>
              </article>
            </main>
          </div>
        </body>
      </html>
    HTML

    with_url_page("https://vite.dev/guide/", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["title"]).to eq("Getting Started")
      expect(payload["markdown"]).to include("# Getting Started")
      expect(payload["markdown"]).to include("faster development experience")
      expect(payload["markdown"]).to include("## Overview")
      expect(payload["markdown"]).not_to include("Skip to content")
      expect(payload["markdown"]).not_to include("Navigation")
      expect(payload["markdown"]).not_to include("Sidebar")
      expect(payload["markdown"]).not_to include("ads via Carbon")
      expect(payload["markdown"]).not_to include("Are you an LLM?")
      expect(payload["markdown"]).not_to include("Previous page")
    end
  end

  it "extracts rspress docs through generic docs-system detection" do
    html = <<~HTML
      <html>
        <head>
          <title>Introduction - Rspack</title>
          <meta name="generator" content="Rspress v2.0.0-rc.5" />
        </head>
        <body>
          <div id="__rspress_root">
            <header class="rp-nav">Navigation</header>
            <aside class="rp-sidebar">Sidebar</aside>
            <main>
              <article class="rspress-doc">
                <div class="rp-breadcrumb">Breadcrumb</div>
                <h1><a href="#introduction" class="rp-header-anchor" aria-hidden="true">#</a>Introduction</h1>
                <p>Rspack is a high performance JavaScript bundler written in Rust.</p>
                <div class="rp-toc">On this page</div>
                <h2>Why Rspack</h2>
                <p>It focuses on webpack compatibility and fast build speed.</p>
                <div class="rp-doc-footer">Previous page Next page</div>
              </article>
            </main>
          </div>
        </body>
      </html>
    HTML

    with_url_page("https://rspack.dev/guide/start/introduction", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["title"]).to eq("Introduction")
      expect(payload["markdown"]).to include("# Introduction")
      expect(payload["markdown"]).to include("high performance JavaScript bundler")
      expect(payload["markdown"]).to include("## Why Rspack")
      expect(payload["markdown"]).not_to include("Navigation")
      expect(payload["markdown"]).not_to include("Sidebar")
      expect(payload["markdown"]).not_to include("On this page")
      expect(payload["markdown"]).not_to include("Previous page")
      expect(payload["markdown"]).not_to include("# Introduction\n\n# Introduction")
    end
  end

  it "extracts read the docs pages through generic docs-system detection" do
    html = <<~HTML
      <html>
        <head>
          <title>Introduction to Celery</title>
        </head>
        <body>
          <nav class="wy-nav-side">Sidebar</nav>
          <div class="wy-nav-content">
            <div class="rst-content">
              <div class="wy-breadcrumbs">Breadcrumbs</div>
              <h1>Introduction to Celery<a class="headerlink" href="#intro">¶</a></h1>
              <p>This document describes the current stable version of Celery.</p>
              <h1>Introduction to Celery<a class="headerlink" href="#intro-dup">¶</a></h1>
              <h2>What is a Task Queue?<a class="headerlink" href="#task-queue">¶</a></h2>
              <p>Task queues distribute work across threads or machines.</p>
              <div class="rst-footer-buttons">Previous Next</div>
            </div>
          </div>
        </body>
      </html>
    HTML

    with_url_page("https://docs.celeryq.dev/en/stable/getting-started/introduction.html", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["title"]).to eq("Introduction to Celery")
      expect(payload["markdown"]).to include("# Introduction to Celery")
      expect(payload["markdown"]).to include("## What is a Task Queue?")
      expect(payload["markdown"].scan("# Introduction to Celery").length).to eq(1)
      expect(payload["markdown"]).not_to include("Breadcrumbs")
      expect(payload["markdown"]).not_to include("Previous Next")
      expect(payload["markdown"]).not_to include("¶")
    end
  end

  it "extracts rustdoc pages through docs-system detection" do
    html = <<~HTML
      <html>
        <head>
          <title>Function read_to_string Copy item path</title>
        </head>
        <body>
          <main class="rustdoc">
            <nav class="sidebar">Sidebar</nav>
            <a href="?search=">Search</a>
            <a href="/settings.html">Settings</a>
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
    end
  end

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
