# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'FetchUtil extractor integration - generic reference docs systems' do
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
      payload = extract(page)
      markdown = payload["markdown"].delete("\\")

      expect(markdown).to include("# json — JSON encoder and decoder")
      expect(markdown).to include("### json.dumps(obj, *, sort_keys=False)")
      expect(markdown).to include("```python")
      expect(markdown).to include(">>> import json")
      expect(markdown).not_to include("Copy")
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
      payload = extract(page)

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
      payload = extract(page)

      expect(payload["title"]).to eq("Function read_to_string")
      expect(payload["markdown"]).to include("# Function read_to_string")
      expect(payload["markdown"]).to include("Reads the entire contents of a file into a string")
      expect(payload["markdown"]).not_to include("Copy item path")
      expect(payload["markdown"]).not_to include("Search")
      expect(payload["markdown"]).not_to include("Settings")
    end
  end
end
