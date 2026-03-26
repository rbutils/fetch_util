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

  it "salvages tiktok tag pages while still flagging verification walls" do
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

  it "salvages ebay cookie walls from metadata instead of cookie copy" do
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
