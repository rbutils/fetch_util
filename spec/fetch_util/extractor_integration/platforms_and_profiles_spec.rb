# frozen_string_literal: true

RSpec.describe 'FetchUtil extractor integration' do
  include_context 'extractor integration helpers'

  it "prefers project summary and readme content on generic gitlab instances" do
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
              <ul>
                <li>Install dependencies</li>
                <li>Run tests</li>
              </ul>
            </div>
          </article>
        </body>
      </html>
    HTML

    with_page(html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("# Group / Project")
      expect(payload["markdown"]).to include("Collaborative project description.")
      expect(payload["markdown"]).to include("## Getting started")
      expect(payload["markdown"]).to include("Install dependencies")
      expect(payload["markdown"]).not_to include("Project ID: 12345")
    end
  end

  it "prefers package registry descriptions over release history chrome" do
    html = <<~HTML
      <html>
        <head>
          <title>pandas · PyPI</title>
          <meta name="description" content="Powerful data structures for data analysis.">
        </head>
        <body>
          <main>
            <div class="sidebar-section">
              <h3>Navigation</h3>
              <a href="#history">Release history</a>
            </div>
            <section id="history" class="vertical-tabs__content">
              <h2 class="page-title split-layout">Release history</h2>
              <div class="release-timeline">
                <a class="card release__card" href="/project/pandas/3.0.4/">3.0.4 yanked Jun 28, 2026</a>
                <a class="card release__card" href="/project/pandas/3.0.0rc2/">3.0.0rc2 pre-release Jan 14, 2026</a>
              </div>
            </section>
            <section id="description" class="vertical-tabs__content">
              <h2 class="page-title">Project description</h2>
              <div class="project-description">
                <h1>pandas: A Powerful Python Data Analysis Toolkit</h1>
                <p>pandas is a Python package providing fast, flexible, and expressive data structures.</p>
                <p>It aims to be the fundamental high-level building block for practical data analysis.</p>
              </div>
            </section>
          </main>
        </body>
      </html>
    HTML

    extract_from_url("https://pypi.org/project/pandas/", html) do |payload|
      expect(payload["contentType"]).to eq("article")
      expect(payload["markdown"]).to include("pandas: A Powerful Python Data Analysis Toolkit")
      expect(payload["markdown"]).to include("fast, flexible, and expressive data structures")
      expect(payload["markdown"]).not_to include("3.0.4 yanked")
      expect(payload["warnings"]).not_to include("multi_topic_page")
    end
  end

  it "does not flag single package pages as multi-topic compilations" do
    html = <<~HTML
      <html>
        <head>
          <title>rails | RubyGems.org | your community gem host</title>
          <meta name="description" content="Ruby on Rails is a full-stack web framework.">
        </head>
        <body>
          <main>
            <div id="markup" class="gem__desc">
              <p>Ruby on Rails is a full-stack web framework optimized for programmer happiness and sustainable productivity.</p>
              <h2>Required Ruby Version</h2>
              <time datetime="2026-01-01">Jan 1, 2026</time>
              <h2>Required Rubygems Version</h2>
              <time datetime="2026-02-01">Feb 1, 2026</time>
              <h2>Authors</h2>
              <time datetime="2026-03-01">Mar 1, 2026</time>
              <h2>Links</h2>
              <time datetime="2026-04-01">Apr 1, 2026</time>
              <h2>Versions</h2>
              <time datetime="2026-05-01">May 1, 2026</time>
              <h2>Dependencies</h2>
              <time datetime="2026-06-01">Jun 1, 2026</time>
            </div>
          </main>
        </body>
      </html>
    HTML

    extract_from_url("https://rubygems.org/gems/rails", html) do |payload|
      expect(payload["contentType"]).to eq("article")
      expect(payload["markdown"]).to include("Ruby on Rails is a full-stack web framework")
      expect(payload["warnings"]).not_to include("multi_topic_page")
      expect(payload["suspect"]).to be(false)
    end
  end

  it "extracts pinterest search pages into compact pin bullets" do
    html = <<~HTML
      <html>
        <head>
          <title>Pinterest</title>
          <meta name="description" content="Discover recipes, home ideas, style inspiration and other ideas to try.">
        </head>
        <body>
          <main>
            <h1>Search</h1>
            <h2>Showing more search results for ruby programming</h2>
            <a href="/pin/1" aria-label="ruby programming logo with the words ruby programming written in red on a white background"></a>
            <a href="/pin/2"><img alt="the ruby programming poster shows how ruby programs are used for learning and developing computer skills"></a>
            <a href="/pin/3" aria-label="the six reasons why you should learn ruby today"></a>
            <a href="/pin/4" aria-label="a red poster with instructions on how to use ruby"></a>
          </main>
        </body>
      </html>
    HTML

    with_page(html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["contentType"]).to eq("list")
      expect(payload["markdown"]).to include("- [ruby programming logo with the words ruby programming written in red on a white background](/pin/1)")
      expect(payload["markdown"]).to include("- [the six reasons why you should learn ruby today](/pin/3)")
      expect(payload["warnings"]).not_to include("url_content_mismatch")
    end
  end

  it "summarizes TikTok tag pages while still flagging verification prompts" do
    html = <<~HTML
      <html>
        <head>
          <title>TikTok - Make Your Day</title>
          <meta name="description" content="Watch popular Ruby videos on TikTok.">
        </head>
        <body>
          <main>
            <h1>#ruby</h1>
            <h2>1.2M posts</h2>
            <p>Drag the slider to fit the puzzle</p>
          </main>
        </body>
      </html>
    HTML

    with_page(html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("# #ruby")
      expect(payload["markdown"]).to include("- 1.2M posts")
      expect(payload["warnings"]).to include("human_verification_interstitial")
    end
  end

  it "summarizes eBay cookie prompts from metadata instead of cookie copy" do
    html = <<~HTML
      <html>
        <head>
          <title>Ruby Programming for sale | eBay</title>
          <meta name="description" content="Get the best deals for Ruby Programming at eBay.com. We have a great online selection at the lowest prices with Fast &amp; Free shipping on many items!">
        </head>
        <body>
          <main>
            <p>We use cookies and other technologies that are essential to provide you our services and site functionality.</p>
            <p>Accept all</p>
          </main>
        </body>
      </html>
    HTML

    with_page(html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("# Ruby Programming for sale | eBay")
      expect(payload["markdown"]).to include("Get the best deals for Ruby Programming at eBay.com.")
      expect(payload["markdown"]).not_to include("We use cookies and other technologies")
      expect(payload["warnings"]).to include("consent_interstitial")
    end
  end

  it "extracts Stack Exchange questions together with top answers" do
    html = <<~HTML
      <html>
        <head>
          <title>How likely is it that any non-Celtic language was spoken in the British Isles when the Romans invaded? - History Stack Exchange</title>
        </head>
        <body>
          <main>
            <div class="question" id="question">
              <div class="question-header">
                <h1>How likely is it that any non-Celtic language was spoken in the British Isles when the Romans invaded?</h1>
              </div>
              <div class="user-details"><a href="/users/1/timothy">Timothy</a></div>
              <div class="js-post-body">We know from Roman writers the names of many ancient British tribes, but not much about their language boundaries.</div>
            </div>
            <div id="answers">
              <div class="answer accepted-answer">
                <span class="js-vote-count">33</span>
                <div class="user-details"><a href="/users/2/example">Example User</a></div>
                <div class="js-post-body">The answer appears to be that we do not know with certainty. Earlier languages likely existed before Celtic spread, but the evidence is fragmentary.</div>
              </div>
            </div>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://history.stackexchange.com/questions/68200/example", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("## Top Answers")
      expect(payload["markdown"]).to include("### Example User (accepted) - score 33")
      expect(payload["markdown"]).to include("Earlier languages likely existed before Celtic spread")
    end
  end

  it "extracts Substack post bodies instead of related links and comments" do
    html = <<~HTML
      <html>
        <head>
          <title>The end of the vibecession? - Example Stack</title>
          <meta property="og:image" content="https://substackcdn.com/image/fetch/example.jpg">
        </head>
        <body>
          <article class="typography newsletter-post post">
            <div class="post-header">
              <h1 class="post-title published">The end of the vibecession?</h1>
              <div class="byline-names">Example Writer</div>
            </div>
            <div class="available-content">
              <div dir="auto" class="body markup">
                <p>One constant source of frustration for econ writers and economists is that the connection between public perceptions of the economy and the actual state of the economy is not clear.</p>
                <p>That does not mean the connection does not exist, or that people's perceptions are simply random noise.</p>
                <p>The more useful question is whether wages, prices, and employment are moving in ways that match what people say they feel.</p>
                <p>Those facts make the vibecession debate a real article body rather than a list of recommended posts.</p>
              </div>
            </div>
          </article>
          <section class="related-posts">
            <a href="/p/yes-were-probably-in-a-recession">have a recession</a>
            <a href="/p/another-post">Another related post</a>
          </section>
          <div class="comment-list post-page-root-comment-list">
            <a href="/p/the-end/comment/1">Jun 28, 2023</a>
            <a href="/p/the-end/comments">102 more comments...</a>
          </div>
        </body>
      </html>
    HTML

    extract_from_url("https://example.substack.com/p/the-end-of-the-vibecession", html) do |payload|
      expect(payload["contentType"]).to eq("article")
      expect(payload["markdown"]).to include("# The end of the vibecession?")
      expect(payload["markdown"]).to include("One constant source of frustration")
      expect(payload["markdown"]).to include("vibecession debate a real article body")
      expect(payload["markdown"]).not_to include("102 more comments")
      expect(payload["markdown"]).not_to include("have a recession")
    end
  end

  it "does not misclassify non-meta pages that mention facebook in share chrome" do
    html = <<~HTML
      <html>
        <head>
          <title>The New Yorker</title>
          <meta name="description" content="Reporting, Profiles, breaking news, cultural coverage, podcasts, videos, and cartoons from The New Yorker.">
        </head>
        <body>
          <main>
            <h1>The New Yorker</h1>
            <p>Reporting, Profiles, breaking news, cultural coverage, podcasts, videos, and cartoons from The New Yorker.</p>
            <a href="https://facebook.com/sharer">Share on Facebook</a>
          </main>
        </body>
      </html>
    HTML

    with_page(html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["warnings"]).not_to include("meta_login_wall")
    end
  end
end
