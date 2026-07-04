# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'FetchUtil extractor integration - content quality warnings' do
  include_context 'extractor integration helpers'

  it "flags paywall_partial_content for articles between 3000-5000 chars with paywall signals" do
    # Build article body that's ~3500 chars (above old 3000 threshold, below new 5000)
    paragraphs = 20.times.map { |i| "<p>This is paragraph #{i + 1} with moderate content providing details about the topic at hand.</p>" }.join("\n")
    html = <<~HTML
      <html>
        <head>
          <title>Premium Investigation Report</title>
          <meta property="article:content_tier" content="locked">
        </head>
        <body>
          <main>
            <article>
              <h1>Premium Investigation Report</h1>
              #{paragraphs}
            </article>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.example-news.com/premium-investigation-report", html) do |page|
      payload = extract(page)

      expect(payload["warnings"]).to include("paywall_partial_content")
      expect(payload["paywallState"]).to eq("detected")
    end
  end

  it "flags paywall_partial_content for ratio-based detection with large page text" do
    # Small article body but large surrounding page text (paywall teaser scenario)
    article_text = 8.times.map { |i| "<p>Brief teaser paragraph #{i + 1} about the main story with some detail.</p>" }.join("\n")
    # Large footer/nav to inflate page text
    nav_links = 120.times.map { |i| "<a href='/section-#{i}'>Section #{i + 1} with a longer link text for padding</a>" }.join(" | \n")
    html = <<~HTML
      <html>
        <head>
          <title>Exclusive Report on Market Trends</title>
          <script type="application/ld+json">
          {"@context":"https://schema.org","@type":"NewsArticle","isAccessibleForFree":false}
          </script>
        </head>
        <body>
          <nav>#{nav_links}</nav>
          <main>
            <article>
              <h1>Exclusive Report on Market Trends</h1>
              #{article_text}
              <div class="paywall-overlay">Subscribe to read more</div>
            </article>
          </main>
          <footer>#{nav_links}</footer>
        </body>
      </html>
    HTML

    with_url_page("https://www.example-news.com/exclusive-report-market-trends", html) do |page|
      payload = extract(page)

      expect(payload["warnings"]).to include("paywall_partial_content")
    end
  end

  # Truncation: broader moderate truncation detection
  it "flags truncated_content for moderate-length articles with very low page ratio" do
    # Build article with ~2000 chars (in the 1500-3000 range for new check)
    article_paragraphs = 12.times.map { |i| "<p>Article paragraph #{i + 1} with some meaningful content about the story.</p>" }.join("\n")
    # Inflate page text to >8000 chars to trigger the ratio check
    sidebar_items = 200.times.map { |i| "<li><a href='/archive/#{i}'>Archive item #{i + 1} with extra descriptive text</a></li>" }.join("\n")
    html = <<~HTML
      <html>
        <head><title>Breaking: Major Economic Policy Change Announced</title></head>
        <body>
          <nav>
            <ul>#{sidebar_items}</ul>
          </nav>
          <main>
            <article>
              <h1>Breaking: Major Economic Policy Change Announced</h1>
              #{article_paragraphs}
            </article>
          </main>
          <aside>
            <ul>#{sidebar_items}</ul>
          </aside>
        </body>
      </html>
    HTML

    with_url_page("https://www.example-news.com/breaking-major-economic-policy-change-announced", html) do |page|
      payload = extract(page)

      # The article text is small relative to the huge page text, should flag truncation
      expect(payload["warnings"]).to include("truncated_content")
    end
  end

  it "flags lyrics pages when extraction misses the visible lyrics body" do
    html = <<~HTML
      <html>
        <head><title>Example Artist - Example Song Lyrics | Example</title></head>
        <body>
          <main>
            <aside>
              <div data-lyrics-container="true" class="Lyrics__Container-sc-example">
                9 Contributors
                Example Song Lyrics
                [Verse 1]
                When the morning breaks over the city
                Every quiet window catches fire
                I am waiting there with empty pockets
                Listening for the station choir

                [Chorus]
                Hold the line, hold the line
                Sing it back one more time
                Hold the line, hold the line
                Let the signal climb

                [Verse 2]
                Every platform hums below the weather
                Every passing train repeats the rhyme
                If the lights go out before the ending
                I will keep the rhythm keeping time
              </div>
            </aside>
            <article class="Annotation__Container-sc-example">
              <h1>Song Bio</h1>
              <p>Written by the songwriter after a long tour, this commentary explains the recording process and the meaning of the single.</p>
              <p>The annotation describes production choices, release history, chart performance, and fan response without including the actual lyric stanzas.</p>
              <p>Contributors added background about the album campaign and interviews with the band.</p>
            </article>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://lyrics.example.com/example-artist-example-song-lyrics", html) do |page|
      payload = extract(page)

      expect(payload["warnings"]).to include("truncated_content")
    end
  end

  it "does not flag short ordinary articles as missing primary content" do
    html = <<~HTML
      <html>
        <head><title>Local Garden Opens New Exhibit</title></head>
        <body>
          <main>
            <article>
              <h1>Local Garden Opens New Exhibit</h1>
              <p>The city garden opened a new exhibit today with native plants, guided tours, and workshops for families.</p>
              <p>Organizers said the exhibit will remain open through the summer and will add new evening programs next month.</p>
            </article>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://news.example.com/local-garden-opens-new-exhibit", html) do |page|
      payload = extract(page)

      expect(payload["warnings"]).not_to include("truncated_content")
    end
  end

  # URL-content mismatch: lowered threshold
  it "flags url_content_mismatch when slug keywords poorly match body content" do
    html = <<~HTML
      <html>
        <head><title>Welcome to Our Portal</title></head>
        <body>
          <main>
            <article>
              <h1>Welcome to Our Portal</h1>
              <p>This page contains general information about our news service and subscription options. Browse our categories to find the content you are looking for. We offer premium and free tiers for all readers.</p>
            </article>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.example-news.hu/budapest-parliament-corruption-scandal-investigation", html) do |page|
      payload = extract(page)

      expect(payload["warnings"]).to include("url_content_mismatch")
    end
  end

  it "flags stale_content for articles published more than 30 days ago" do
    html = <<~HTML
      <html>
        <head>
          <title>Dublin Sea Level Report</title>
          <meta property="article:published_time" content="2021-03-15T10:00:00Z">
          <meta property="article:section" content="News">
          <script type="application/ld+json">
          {"@context":"https://schema.org","@type":"NewsArticle","headline":"Dublin Sea Level Report","datePublished":"2021-03-15T10:00:00Z"}
          </script>
        </head>
        <body>
          <main>
            <article>
              <h1>Dublin Sea Level Report</h1>
              <p>A comprehensive report on rising sea levels around the Dublin coast. The measurements show significant changes over the past decade.</p>
            </article>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.dublin-inquirer.example.com/sea-level-report", html) do |page|
      payload = extract(page)

      expect(payload["warnings"]).to include("stale_content")
    end
  end

  it "does not flag stale_content for old evergreen reference pages" do
    html = <<~HTML
      <html>
        <head>
          <title>Ruby (programming language) - Wikipedia</title>
          <meta property="article:published_time" content="2021-03-15T10:00:00Z">
          <meta property="og:type" content="article">
        </head>
        <body>
          <main id="content">
            <h1>Ruby (programming language)</h1>
            <div id="mw-content-text">
              <div class="mw-parser-output">
                <p>Ruby is a high-level, general-purpose programming language. It was designed with an emphasis on programming productivity and simplicity.</p>
                <h2>History</h2>
                <p>The language has remained useful as reference material for programmers learning its object model and standard library.</p>
                <h2>References</h2>
                <ol><li>Business Wire, archived product announcement cited as background material.</li></ol>
              </div>
            </div>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://en.wikipedia.org/wiki/Ruby_(programming_language)", html) do |page|
      payload = extract(page)

      expect(payload["markdown"]).to include("Ruby is a high-level")
      expect(payload["warnings"]).not_to include("stale_content")
    end
  end

  it "does not flag stale_content for recently published articles" do
    recent_date = (Time.now - (3 * 24 * 60 * 60)).strftime("%Y-%m-%dT%H:%M:%SZ")
    html = <<~HTML
      <html>
        <head>
          <title>Today's Economic Update</title>
          <meta property="article:published_time" content="#{recent_date}">
        </head>
        <body>
          <main>
            <article>
              <h1>Today's Economic Update</h1>
              <p>The latest economic indicators show continued growth in the manufacturing sector.</p>
            </article>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.example.com/todays-economic-update", html) do |page|
      payload = extract(page)

      expect(payload["warnings"]).not_to include("stale_content")
    end
  end

  it "flags paywall_partial_content for longer teasers with very low ratio to page" do
    # Article body ~8K-10K chars (above 8000 threshold) but page text much larger
    article_text = 50.times.map do |i|
      "<p>Detailed teaser paragraph #{i + 1} with financial analysis and market data discussion for premium subscribers only.</p>"
    end.join("\n")
    # Large nav/footer to inflate page text well beyond article
    nav_links = 300.times.map { |i| "<a href='/section-#{i}'>Section #{i + 1} navigation with extended label</a>" }.join(" | \n")
    html = <<~HTML
      <html>
        <head>
          <title>Premium Market Analysis Report</title>
          <meta property="article:content_tier" content="premium">
        </head>
        <body>
          <nav>#{nav_links}</nav>
          <main>
            <article>
              <h1>Premium Market Analysis Report</h1>
              #{article_text}
            </article>
          </main>
          <footer>#{nav_links}</footer>
        </body>
      </html>
    HTML

    with_url_page("https://www.example-premium.com/premium-market-analysis-report", html) do |page|
      payload = extract(page)

      expect(payload["warnings"]).to include("paywall_partial_content")
      expect(payload["paywallState"]).to eq("detected")
    end
  end

  it "still flags paywall_partial_content for article teasers with paywall signals" do
    html = <<~HTML
      <html>
        <head>
          <title>Subscriber Investigation</title>
          <meta property="article:content_tier" content="metered">
        </head>
        <body>
          <main>
            <article>
              <h1>Subscriber Investigation</h1>
              <p>This opening section summarizes a long investigation and gives readers enough context to understand the topic.</p>
              <p>The remaining interviews, documents, and source material are part of the member edition.</p>
              <div class="paywall">Member edition includes the full investigation.</div>
            </article>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.example-premium.com/news/subscriber-investigation", html) do |page|
      payload = extract(page)

      expect(payload["warnings"]).to include("paywall_partial_content")
    end
  end

  # Syndicated repost detection
  it "flags syndicated_repost for wire service content" do
    html = <<~HTML
      <html>
        <head><title>Company Announces New Product Launch</title></head>
        <body>
          <main>
            <article>
              <h1>Company Announces New Product Launch</h1>
              <p>NEW YORK, April 9, 2026 -- TechCorp today announced the launch of its newest product line. The company expects significant market adoption in Q3.</p>
              <p>This press release was distributed by EIN Presswire. For more information visit einpresswire.com.</p>
            </article>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.voiceofmoldova.md/company-announces-new-product-launch", html) do |page|
      payload = extract(page)

      expect(payload["warnings"]).to include("syndicated_repost")
    end
  end

  it "does not flag syndicated_repost for original editorial content" do
    html = <<~HTML
      <html>
        <head><title>Local Elections Analysis</title></head>
        <body>
          <main>
            <article>
              <h1>Local Elections Analysis</h1>
              <p>Our correspondent reports from the campaign trail. The polling data suggests a tight race between the two leading candidates, with undecided voters likely to determine the outcome.</p>
            </article>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.example.com/local-elections-analysis", html) do |page|
      payload = extract(page)

      expect(payload["warnings"]).not_to include("syndicated_repost")
    end
  end

  it "does not flag syndicated_repost for incidental wire-service references" do
    html = <<~HTML
      <html>
        <head><title>Ruby (programming language) - Reference Article</title></head>
        <body>
          <main>
            <article>
              <h1>Ruby (programming language)</h1>
              <p>Ruby is a high-level, general-purpose programming language with dynamic typing and a focus on developer productivity.</p>
              <p>The language reference explains objects, classes, modules, blocks, exceptions, and the standard library in detail.</p>
              <h2>References</h2>
              <ol>
                <li>A historical company announcement archived by Business Wire is cited as background for an implementation milestone.</li>
              </ol>
            </article>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://example.org/reference/ruby-programming-language", html) do |page|
      payload = extract(page)

      expect(payload["markdown"]).to include("Business Wire")
      expect(payload["warnings"]).not_to include("syndicated_repost")
    end
  end
end
