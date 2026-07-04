# frozen_string_literal: true

RSpec.describe 'FetchUtil extractor integration' do
  include_context 'extractor integration helpers'

  it "extracts antora article pages without byline and version chrome" do
    html = <<~HTML
      <html>
        <head>
          <title>Getting Started :: Fedora Docs</title>
          <meta name="generator" content="Antora 3.1.14">
        </head>
        <body>
          <div class="toolbar">Toolbar</div>
          <div class="crumbs">Breadcrumbs</div>
          <main class="main">
            <article class="doc">
              <p>The Fedora Docs Team Version F43 Last review: 2026-03-01</p>
              <h1>Getting Started</h1>
              <p>Fedora provides various methods to help you get started quickly.</p>
              <h2>Introduction</h2>
              <p>This guide introduces installation paths and help channels.</p>
            </article>
          </main>
        </body>
      </html>
    HTML

    with_page(html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("# Getting Started")
      expect(payload["markdown"]).to include("Fedora provides various methods to help you get started quickly.")
      expect(payload["markdown"]).not_to include("The Fedora Docs Team")
      expect(payload["markdown"]).not_to include("Version F43")
      expect(payload["markdown"]).not_to include("Breadcrumbs")
    end
  end

  it "extracts rails guides with title-first content and no chapter toc chrome" do
    html = <<~HTML
      <html>
        <head>
          <title>Getting Started with Rails — Ruby on Rails Guides</title>
        </head>
        <body>
          <div id="topNav">Rails nav</div>
          <main id="main">
            <a href="#main">Skip to main content</a>
            <h1>Getting Started with Rails</h1>
            <p>This guide covers getting up and running with Ruby on Rails.</p>
            <div>
              <h2>Chapters</h2>
              <ul>
                <li><a href="#introduction">Introduction</a></li>
                <li><a href="#philosophy">Rails Philosophy</a></li>
              </ul>
            </div>
            <div id="column-main">
              <h2>1. Introduction</h2>
              <p>Rails is a web framework built for the Ruby programming language.</p>
            </div>
          </main>
        </body>
      </html>
    HTML

    with_page(html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)
      markdown = payload["markdown"].delete("\\")

      expect(markdown).to include("# Getting Started with Rails")
      expect(markdown).to include("This guide covers getting up and running with Ruby on Rails.")
      expect(markdown).to include("## 1. Introduction")
      expect(markdown).not_to include("Skip to main content")
      expect(markdown).not_to include("## Chapters")
    end
  end

  it "does not flag long single-topic rails guides as multi-topic pages" do
    sections = 7.times.map do |i|
      <<~SECTION
        <h2>#{i + 1}. Guide section #{i + 1}</h2>
        <p>This section continues the same Rails guide with a focused explanation and a <a href="#example-#{i}">supporting example</a>.</p>
      SECTION
    end.join("\n")

    html = <<~HTML
      <html>
        <head>
          <title>Getting Started with Rails — Ruby on Rails Guides</title>
        </head>
        <body>
          <main id="main">
            <h1>Getting Started with Rails</h1>
            <p>This guide covers getting up and running with Ruby on Rails.</p>
            <div id="column-main">
              #{sections}
            </div>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://guides.rubyonrails.org/getting_started.html", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["warnings"]).not_to include("multi_topic_page")
    end
  end

  it "extracts rails api docs without file-tree or anchor chrome" do
    html = <<~HTML
      <html>
        <head>
          <title>ActiveRecord::Base</title>
        </head>
        <body>
          <h1>files</h1>
          <div id="bodyContent">
            <form>Search</form>
            <a href="#search">Skip to Search</a>
            <h2>Class ActiveRecord::Base < Object <a href="#top">↑</a> <a href="#class">¶</a></h2>
            <p>Active Record objects don't specify their attributes directly.</p>
            <h2>Creation <a href="#creation">¶</a></h2>
            <p>Active Record objects can be instantiated as either empty or pre-set.</p>
          </div>
        </body>
      </html>
    HTML

    with_page(html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)
      markdown = payload["markdown"].delete("\\")

      expect(markdown).to include("# ActiveRecord::Base")
      expect(markdown).to include("## Class ActiveRecord::Base < Object")
      expect(markdown).to include("## Creation")
      expect(markdown).not_to include("Skip to Search")
      expect(markdown).not_to include("¶")
      expect(markdown).not_to include("↑")
      expect(markdown).not_to include("# files")
    end
  end

  it "extracts generic rdoc docs with title-first content and no toc chrome" do
    html = <<~HTML
      <html>
        <head>
          <title>class String - RDoc Documentation</title>
        </head>
        <body>
          <main>
            <div id="class-metadata">Parent Object Included Modules Methods</div>
            <h1>class String</h1>
            <h2>Home</h2>
            <ul>
              <li><a href="#methods">Methods</a></li>
              <li><a href="#queries">Queries</a></li>
              <li><a href="#conversion">Conversion</a></li>
              <li><a href="#iteration">Iteration</a></li>
            </ul>
            <p>A String object has an arbitrary sequence of bytes, typically representing text or binary data.</p>
            <h2>Methods for Creating a String <a href="#methods">¶</a></h2>
            <p>You can create a String object explicitly with a string literal.</p>
          </main>
        </body>
      </html>
    HTML

    with_page(html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)
      markdown = payload["markdown"].delete("\\")

      expect(markdown).to include("# String")
      expect(markdown).to include("A String object has an arbitrary sequence of bytes")
      expect(markdown).to include("## Methods for Creating a String")
      expect(markdown).not_to include("Parent Object Included Modules")
      expect(markdown).not_to include("## Home")
      expect(markdown).not_to include("¶")
    end
  end

  it "extracts rubyapi landing pages into compact class lists" do
    html = <<~HTML
      <html>
        <head>
          <title>Home | Ruby API (v4.0)</title>
          <meta name="description" content="Ruby API is the go-to resource to search and find everything you need for the Ruby programming language.">
        </head>
        <body>
          <header>
            <nav>Main navigation</nav>
          </header>
          <div class="p-6 max-w-7xl mx-auto">
            <div class="flex flex-wrap">
              <div class="block w-full md:w-6/12 md:p-3 py-3">
                <div class="border rounded p-3">
                  <h2>String</h2>
                  <p>A String object holds and manipulates an arbitrary sequence of bytes.</p>
                  <div><a href="/4.0/o/string">Read more</a></div>
                </div>
              </div>
              <div class="block w-full md:w-6/12 md:p-3 py-3">
                <div class="border rounded p-3">
                  <h2>Integer</h2>
                  <p>Represent whole numbers in Ruby.</p>
                  <div><a href="/4.0/o/integer">Read more</a></div>
                </div>
              </div>
              <div class="block w-full md:w-6/12 md:p-3 py-3">
                <div class="border rounded p-3">
                  <h2>Array</h2>
                  <p>An ordered, integer-indexed collection of objects.</p>
                  <div><a href="/4.0/o/array">Read more</a></div>
                </div>
              </div>
            </div>
          </div>
        </body>
      </html>
    HTML

    with_url_page("https://rubyapi.org/", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["contentType"]).to eq("list")
      expect(payload["markdown"]).to include("# Home")
      expect(payload["markdown"]).to include("- [String](https://rubyapi.org/4.0/o/string) - A String object holds and manipulates an arbitrary sequence of bytes.")
      expect(payload["markdown"]).to include("- [Integer](https://rubyapi.org/4.0/o/integer) - Represent whole numbers in Ruby.")
      expect(payload["markdown"]).not_to include("Main navigation")
    end
  end

  it "extracts rubyapi object pages without sidebar toggle chrome" do
    html = <<~HTML
      <html>
        <head>
          <title>String | Ruby API (v3.4)</title>
        </head>
        <body>
          <nav>Type Signatures Preview Enable Type Signatures</nav>
          <main class="w-full mt-16 lg:mt-20 lg:w-3/4">
            <section>
              <div>
                <h1><a href="/3.4/o/string">String</a></h1>
              </div>
              <div class="ruby-documentation">
                <p>A <code>String</code> object has an arbitrary sequence of bytes, typically representing text or binary data.</p>
                <h2>Methods for Creating a String</h2>
                <p>You can create a String object explicitly with a string literal.</p>
              </div>
            </section>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://rubyapi.org/3.4/o/string", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("# String")
      expect(payload["markdown"]).to include("A `String` object has an arbitrary sequence of bytes")
      expect(payload["markdown"]).to include("## Methods for Creating a String")
      expect(payload["markdown"]).not_to include("Enable Type Signatures")
      expect(payload["markdown"]).not_to include("Preview")
    end
  end

  it "extracts generic sphinx docs through system detection" do
    html = <<~HTML
      <html>
        <head>
          <title>Configuration — Example 1.0 documentation</title>
          <meta name="generator" content="Sphinx 8.1.0">
        </head>
        <body>
          <div class="body" role="main">
            <h1>Configuration<a class="headerlink" href="#configuration">¶</a></h1>
            <dt class="sig sig-object py" id="pkg.load">pkg.load(path, *, strict=False)<a class="headerlink" href="#pkg.load">¶</a></dt>
            <dd><p>Load configuration from a file path.</p></dd>
            <div class="highlight-bash"><button class="copybutton">Copy</button><pre>$ pkg load config.yml</pre></div>
          </div>
        </body>
      </html>
    HTML

    with_page(html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)
      markdown = payload["markdown"].delete("\\")

      expect(markdown).to include("# Configuration")
      expect(markdown).to include("### pkg.load(path, *, strict=False)")
      expect(markdown).to include('```bash')
      expect(markdown).not_to include("Copy")
      expect(markdown).not_to include("¶")
    end
  end
end
