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
end
