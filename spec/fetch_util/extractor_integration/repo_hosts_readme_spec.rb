# frozen_string_literal: true

RSpec.describe 'FetchUtil repo host README extraction' do
  include_context 'extractor integration helpers'

  it "surfaces GitHub rendered README content from article markdown bodies" do
    html = <<~HTML
      <html>
        <head>
          <title>GitHub - acme/widgets: Widget toolkit</title>
          <meta name="description" content="GitHub - acme/widgets: Widget toolkit">
        </head>
        <body>
          <div data-testid="repository-container-header">
            <h1><span>acme</span> / <strong itemprop="name"><a href="/acme/widgets">widgets</a></strong></h1>
          </div>
          <p data-testid="repository-description">Widget toolkit for integration tests.</p>
          <div id="readme">
            <article class="markdown-body entry-content" itemprop="text">
              <h1>Widgets</h1>
              <p>Rendered README content is available.</p>
              <h2>Usage</h2>
              <p>Install widgets and run the demo.</p>
            </article>
          </div>
        </body>
      </html>
    HTML

    with_url_page("https://github.com/acme/widgets", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("# acme/widgets: Widget toolkit")
      expect(payload["markdown"]).to include("Widget toolkit for integration tests.")
      expect(payload["markdown"]).to include("# Widgets")
      expect(payload["markdown"]).to include("## Usage")
    end
  end

  it "surfaces GitHub README content from alternate rendered containers" do
    html = <<~HTML
      <html>
        <head>
          <title>GitHub - acme/portable-readme: Portable README</title>
        </head>
        <body>
          <div data-testid="repository-container-header">
            <h1><span>acme</span> / <strong itemprop="name"><a href="/acme/portable-readme">portable-readme</a></strong></h1>
          </div>
          <div data-testid="readme">
            <div data-testid="readme-content">
              <h1>Portable README</h1>
              <p>This README is rendered outside an article markdown-body container.</p>
              <blockquote><p>Keep visible README comments and notes.</p></blockquote>
            </div>
          </div>
        </body>
      </html>
    HTML

    with_url_page("https://github.com/acme/portable-readme", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("# Portable README")
      expect(payload["markdown"]).to include("This README is rendered outside an article markdown-body container.")
      expect(payload["markdown"]).to include("Keep visible README comments and notes.")
    end
  end

  it "degrades GitHub repository pages without READMEs to compact project summaries" do
    html = <<~HTML
      <html>
        <head>
          <title>GitHub - acme/no-readme: Project without a README</title>
        </head>
        <body>
          <div data-testid="repository-container-header">
            <h1><span>acme</span> / <strong itemprop="name"><a href="/acme/no-readme">no-readme</a></strong></h1>
          </div>
          <p data-testid="repository-description">Compact repository summary should remain available.</p>
          <nav>
            <a href="/acme/no-readme/issues">Issues</a>
            <a href="/acme/no-readme/pulls">Pull requests</a>
          </nav>
        </body>
      </html>
    HTML

    with_url_page("https://github.com/acme/no-readme", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("# acme/no-readme: Project without a README")
      expect(payload["markdown"]).to include("Compact repository summary should remain available.")
      expect(payload["textContent"]).not_to be_empty
    end
  end

  it "preserves GitLab project README extraction" do
    html = <<~HTML
      <html>
        <head>
          <title>Group / Project · GitLab</title>
          <meta name="application-name" content="GitLab">
          <meta name="description" content="Collaborative project description.">
        </head>
        <body>
          <header class="project-home-panel">
            <p>Collaborative project description.</p>
            <p>Project ID: 12345</p>
          </header>
          <article class="file-holder readme-holder">
            <div class="md">
              <h2>Getting started</h2>
              <p>Clone the repository and run the setup script.</p>
            </div>
          </article>
        </body>
      </html>
    HTML

    with_url_page("https://gitlab.example.com/group/project", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("# Group / Project")
      expect(payload["markdown"]).to include("Collaborative project description.")
      expect(payload["markdown"]).to include("## Getting started")
      expect(payload["markdown"]).not_to include("Project ID: 12345")
    end
  end

  it "prefers GitLab rendered README over project file-list chrome" do
    html = <<~HTML
      <html>
        <head>
          <title>GitLab.org / GitLab · GitLab</title>
          <meta name="application-name" content="GitLab">
          <meta name="description" content="Open-source DevSecOps platform.">
        </head>
        <body>
          <header class="project-home-panel">
            <p class="project-description">Open-source DevSecOps platform.</p>
            <p>Project ID: 278964</p>
          </header>
          <main>
            <section class="tree-holder">
              <a href="/gitlab-org/gitlab/-/blob/master/README.md">README.md</a>
              <a href="/gitlab-org/gitlab/-/tree/master/app">app</a>
              <a href="/gitlab-org/gitlab/-/tree/master/config">config</a>
              <a href="/gitlab-org/gitlab/-/tree/master/doc">doc</a>
            </section>
            <aside>
              <a href="/help/user/workspace/workspaces_troubleshooting.html">Workspaces documentation</a>
              <p>A workspace is a virtual sandbox environment for your code in GitLab.</p>
            </aside>
            <article class="file-holder limited-width-container readme-holder">
              <div class="file-title">README.md</div>
              <div class="file-content js-markup-content md">
                <h1>GitLab</h1>
                <p>GitLab is an open-source DevSecOps platform that provides a complete software development lifecycle toolchain.</p>
                <h2>Canonical source</h2>
                <p>The canonical source of GitLab where all development takes place is hosted on GitLab.com.</p>
              </div>
            </article>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://gitlab.com/gitlab-org/gitlab", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["contentType"]).to eq("article")
      expect(payload["markdown"]).to include("# GitLab.org / GitLab")
      expect(payload["markdown"]).to include("GitLab is an open-source DevSecOps platform")
      expect(payload["markdown"]).to include("## Canonical source")
      expect(payload["markdown"]).not_to include("Workspaces documentation")
      expect(payload["markdown"]).not_to include("README.md](")
    end
  end
end
