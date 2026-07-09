# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'FetchUtil extractor integration - generic framework docs systems' do
  include_context 'extractor integration helpers'

  it "preserves real starlight landing cards inside markdown content" do
    html = <<~HTML
      <html>
        <head>
          <title>Getting Started | Astro Docs</title>
          <meta name="generator" content="Astro v5.0.0" />
          <meta property="og:site_name" content="Starlight" />
        </head>
        <body>
          <starlight-menu-button>Menu</starlight-menu-button>
          <aside id="starlight__sidebar">Sidebar navigation</aside>
          <main>
            <div class="hero">
              <h1>Astro Docs</h1>
              <p>Guides, resources, and API references to help you build with Astro.</p>
            </div>
            <div class="sl-markdown-content">
              <div class="card-grid">
                <div class="landing-card">
                  <article class="card sl-flex">
                    <p class="title sl-flex"><span>What will you build with Astro?</span></p>
                    <div class="body">
                      <p>Explore <a href="https://astro.build/themes/">Astro starter themes</a> for journals, portfolios, manuals, landing pages, stores, and more!</p>
                    </div>
                  </article>
                </div>
                <div class="card--fullwidth">
                  <article class="card sl-flex">
                    <p class="title sl-flex"><span>Start a new project</span></p>
                    <div class="body">
                      <div class="split">
                        <pre><code>npm create astro@latest</code></pre>
                        <p>Our <a href="/en/install-and-setup/">installation guide</a> has step-by-step instructions for installing Astro using our CLI wizard.</p>
                      </div>
                    </div>
                  </article>
                </div>
                <div class="landing-card">
                  <article class="card sl-flex">
                    <p class="title sl-flex"><span>Learn</span></p>
                    <div class="body">
                      <ul>
                        <li><a href="/en/concepts/why-astro/">Astro's main features</a></li>
                        <li><a href="/en/basics/astro-components/">Astro components</a></li>
                      </ul>
                    </div>
                  </article>
                </div>
              </div>
            </div>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://docs.example.test/en/getting-started/", html) do |page|
      payload = extract(page)

      expect(payload["title"]).to eq("Astro Docs")
      expect(payload["markdown"]).to include("# Astro Docs")
      expect(payload["markdown"]).to include("What will you build with Astro?")
      expect(payload["markdown"]).to include("Explore [Astro starter themes](https://astro.build/themes/)")
      expect(payload["markdown"]).to include("Start a new project")
      expect(payload["markdown"]).to include("npm create astro@latest")
      expect(payload["markdown"]).to include("Astro's main features")
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
      payload = extract(page)

      expect(payload["markdown"]).to include("# Path Parameters")
      expect(payload["markdown"]).to include("same syntax used by Python format strings")
      expect(payload["markdown"]).not_to include("Edit this page")
      expect(payload["markdown"]).not_to include("Table of contents")
    end
  end

  it "keeps mkdocs reference index navigation links" do
    html = <<~HTML
      <html>
        <head>
          <title>Reference - FastAPI</title>
          <meta name="generator" content="mkdocs-1.6.1, mkdocs-material-9.7.1">
        </head>
        <body>
          <nav class="md-nav">
            <ul class="md-nav__list">
              <li class="md-nav__item md-nav__item--active md-nav__item--section md-nav__item--nested">
                <a href="https://fastapi.example.test/reference/" class="md-nav__link md-nav__link--active">Reference</a>
                <nav class="md-nav"><ul>
                  <li><a href="https://fastapi.example.test/reference/fastapi/" class="md-nav__link">FastAPI class</a></li>
                  <li><a href="https://fastapi.example.test/reference/parameters/" class="md-nav__link">Request Parameters</a></li>
                  <li><a href="https://fastapi.example.test/reference/status/" class="md-nav__link">Status Codes</a></li>
                  <li><a href="https://fastapi.example.test/reference/apirouter/" class="md-nav__link">APIRouter class</a></li>
                </ul></nav>
              </li>
            </ul>
          </nav>
          <main><div class="md-content"><article class="md-content__inner">
            <h1>Reference</h1>
            <p>Here's the reference or code API for the framework.</p>
          </article></div></main>
        </body>
      </html>
    HTML

    with_url_page("https://fastapi.example.test/reference/", html) do |page|
      payload = extract(page)
      markdown = payload["markdown"]

      expect(markdown).to include("# Reference")
      expect(markdown).to include("[FastAPI class](https://fastapi.example.test/reference/fastapi/)")
      expect(markdown).to include("[APIRouter class](https://fastapi.example.test/reference/apirouter/)")
      expect(markdown).not_to include("md-nav")
    end
  end

  it "extracts dartdoc library indexes through generic docs-system detection" do
    html = <<~HTML
      <html>
        <head><title>Dart API docs</title></head>
        <body>
          <header><div class="self-name">Dart</div></header>
          <main><div id="dartdoc-main-content">
            <section class="desc markdown"><h1>Welcome!</h1><p>Dart API docs, for the Dart programming language.</p></section>
            <section class="summary"><h2>Libraries</h2><dl>
              <dt id="dart:async"><span class="name"><a href="dart-async/">dart:async</a></span></dt>
              <dd>Support for asynchronous programming, with Future and Stream.</dd>
              <dt id="dart:collection"><span class="name"><a href="dart-collection/">dart:collection</a></span></dt>
              <dd>Classes and utilities that supplement collection support.</dd>
              <dt id="dart:core"><span class="name"><a href="dart-core/">dart:core</a></span></dt>
              <dd>Built-in types, collections, and other core functionality.</dd>
              <dt id="dart:io"><span class="name"><a href="dart-io/">dart:io</a></span></dt>
              <dd>File, socket, HTTP, and other I/O support.</dd>
            </dl></section>
          </div></main>
        </body>
      </html>
    HTML

    with_url_page("https://api.example.test/stable/", html) do |page|
      payload = extract(page)
      markdown = payload["markdown"]

      expect(payload["contentType"]).to eq("article")
      expect(markdown).to include("# Welcome!")
      expect(markdown).to include("[dart:async](https://api.example.test/stable/dart-async/)")
      expect(markdown).to include("[dart:core](https://api.example.test/stable/dart-core/)")
      expect(markdown).to include("[dart:io](https://api.example.test/stable/dart-io/)")
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
      payload = extract(page)

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

  it "classifies Docusaurus docs homepages as lists without leaked nav text" do
    html = fixture_contents(File.expand_path('../../../fixtures/docusaurus_homepage.html', __dir__))

    with_url_page("https://pptr.dev/", html) do |page|
      payload = extract(page)

      expect(payload["contentType"]).to eq("list")
      expect(payload["title"]).to eq("Orbit Browser")
      expect(payload["markdown"]).to include("# Orbit Browser")
      expect(payload["markdown"]).to include("Orbit Browser offers a compact interface")
      expect(payload["markdown"]).to include("## Setup")
      expect(payload["markdown"]).not_to include("Get started | API | FAQ")
      expect(payload["markdown"]).not_to include("Automation API")
      expect(payload["markdown"]).not_to include("Community Forum")
      expect(payload["markdown"]).not_to include("Skip to main content")
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
      payload = extract(page)

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
      payload = extract(page)

      expect(payload["title"]).to eq("GitHub Provider")
      expect(payload["markdown"]).to include("# GitHub Provider")
      expect(payload["markdown"]).to include("## Resources")
      expect(payload["markdown"]).to include("## Setup")
      expect(payload["markdown"]).not_to include("Copy page")
      expect(payload["markdown"]).not_to include("Getting Started / Providers / GitHub")
    end
  end

  it "preserves nextra category card links from pagefind body content" do
    html = <<~HTML
      <html>
        <head>
          <title>Guide - Nextra</title>
        </head>
        <body>
          <a href="#nextra-skip-nav" class="nextra-skip-nav">Skip to Content</a>
          <nav class="nextra-nav-container">Global nav</nav>
          <article>
            <div class="nextra-breadcrumb">Documentation / Guide</div>
            <main data-pagefind-body="true">
              <h1>Guide</h1>
              <p>The following features are configured via the Next.js configuration and are available in all themes.</p>
              <div class="nextra-cards x:grid not-prose" style="--rows:3">
                <a class="nextra-card x:flex" href="/docs/guide/markdown">
                  <span title="Markdown"><svg><path></path></svg><span class="_truncate">Markdown</span></span>
                </a>
                <a class="nextra-card x:flex" href="/docs/guide/syntax-highlighting">
                  <span title="Syntax Highlighting"><span class="_truncate">Syntax Highlighting</span></span>
                </a>
                <a class="nextra-card x:flex" href="/docs/guide/image">
                  <span title="Image"><span class="_truncate">Image</span></span>
                  <p>Optimize image rendering in Nextra documents.</p>
                </a>
              </div>
            </main>
          </article>
        </body>
      </html>
    HTML

    with_url_page("https://nextra.site/docs/guide", html) do |page|
      payload = extract(page)
      markdown = payload["markdown"]

      expect(payload["title"]).to eq("Guide")
      expect(markdown).to include("# Guide")
      expect(markdown).to include("available in all themes")
      expect(markdown).to include("[Markdown](https://nextra.site/docs/guide/markdown)")
      expect(markdown).to include("[Syntax Highlighting](https://nextra.site/docs/guide/syntax-highlighting)")
      expect(markdown).to include("Optimize image rendering in Nextra documents")
      expect(markdown).not_to include("Global nav")
      expect(markdown).not_to include("Documentation / Guide")
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
      payload = extract(page)

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
      payload = extract(page)

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

  it "keeps all MkDocs reference links in DOM order" do
    links = (1..55).map { |index| "<li><a href=\"/reference/item-#{index}/\">Item #{index}</a></li>" }.join
    html = <<~HTML
      <html><head><meta name="generator" content="mkdocs-1.6.1, mkdocs-material-9.7.1"></head>
      <body><nav class="md-nav"><div class="md-nav__item--nested"><a class="md-nav__link" href="https://docs.example.test/reference/">Current</a><nav class="md-nav">#{links}</nav></div></nav><main><h1>Reference</h1><p>Reference content.</p></main></body></html>
    HTML

    with_url_page("https://docs.example.test/reference/", html) do |page|
      markdown = extract(page)["markdown"]
      expect(markdown).to include("- [Item 55](https://docs.example.test/reference/item-55/)")
      expect(markdown.index("Item 1")).to be < markdown.index("Item 55")
    end
  end

  it "keeps all Dartdoc libraries in DOM order" do
    items = (1..85).map do |index|
      "<dt><span class=\"name\"><a href=\"/api/library_#{index}.html\">library_#{index}</a></span></dt><dd>Library #{index}.</dd>"
    end.join
    html = <<~HTML
      <html><head><title>Dart API</title><meta name="generator" content="dartdoc"></head><body><main><div id="dartdoc-main-content"><h1>Dart API</h1><div class="desc"><p>Libraries.</p></div><section class="summary"><dl>#{items}</dl></section></div></main></body></html>
    HTML

    with_url_page("https://api.example.test/", html) do |page|
      markdown = extract(page)["markdown"]
      expect(markdown).to include("- [library_85](https://api.example.test/api/library_85.html) - Library 85.")
      expect(markdown.index("library_1")).to be < markdown.index("library_85")
    end
  end
end
