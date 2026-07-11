# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'FetchUtil extractor integration - docs content cleanup fragments' do
  include_context 'extractor integration helpers'

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
      payload = extract(page)

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
      payload = extract(page)

      expect(payload["title"]).to eq("RUN quoted")
      expect(payload["markdown"]).to include("# RUN quoted")
      expect(payload["markdown"]).to include("quoted anchors")
      expect(payload["markdown"]).not_to include("Overview")
    end
  end

  it "preserves Javadoc reference hierarchy, signatures, and member details" do
    html = fixture_contents(File.expand_path('../../fixtures/javadoc_reference.html', __dir__))

    with_url_page("https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/Map.html", html) do |page|
      markdown = extract(page).fetch("markdown")

      expect(markdown).to include("# Interface Map<K,V>")
      expect(markdown).to include("## Method Summary")
      expect(markdown).to include("### put")
      expect(markdown).to include("V put(K key, V value)")
      expect(markdown).to include("Parameters:")
      expect(markdown).to include("Returns:")
      expect(markdown).to include("Throws:")
      expect(markdown).not_to include("Oracle navigation")
    end
  end

  it "does not treat a generic flex-box block as Javadoc" do
    html = <<~HTML
      <html><head><title>Architecture guide</title></head><body>
        <main><article><h1>Architecture guide</h1><div class="flex-box"><div class="block">Reusable layout block</div></div><p>General documentation content.</p></article></main>
      </body></html>
    HTML

    with_url_page("https://docs.example.test/architecture", html) do |page|
      markdown = extract(page).fetch("markdown")

      expect(markdown).to include("Reusable layout block")
      expect(markdown).to include("General documentation content.")
    end
  end

  it "preserves MDN reference sections instead of removing populated short sections" do
    html = fixture_contents(File.expand_path('../../fixtures/mdn_reference.html', __dir__))

    with_url_page("https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Array/map", html) do |page|
      markdown = extract(page).fetch("markdown")

      expect(markdown).to include("## Syntax")
      expect(markdown).to include("## Parameters")
      expect(markdown).to include("## Return value")
      expect(markdown).to include("## Examples")
      expect(markdown).to include("## Specifications")
      expect(markdown).to include("## Browser compatibility")
    end
  end
end
