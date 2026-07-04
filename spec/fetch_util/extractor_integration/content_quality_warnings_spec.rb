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

  it "does not flag url_content_mismatch for dataset record URLs resolved by numeric IDs" do
    html = <<~HTML
      <html>
        <head>
          <title>MELK involvement in the apoptosis cascade through Bcl-G</title>
          <meta property="og:site_name" content="Data Repository">
          <script type="application/ld+json">
          {"@context":"https://schema.org","@type":"Dataset","name":"MELK involvement in the apoptosis cascade through Bcl-G"}
          </script>
        </head>
        <body>
          <main>
            <article>
              <h1>MELK involvement in the apoptosis cascade through Bcl-G</h1>
              <p>posted on 2011-12-30, 18:07 authored by Meng-Lay Lin, Jae-Hyun Park, Toshihiko Nishidate, Yusuke Nakamura, Toyomasa Katagiri.</p>
              <p>This dataset record describes apoptosis cascade assays, MELK protein expression, Bcl-G interaction data, supplementary files, and DOI metadata for reuse.</p>
              <p>Repository metadata includes file downloads, citation information, and study details for the dataset identified by record number 12345.</p>
            </article>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://repository.example.org/articles/dataset/_/12345", html) do |page|
      payload = extract(page)

      expect(payload["warnings"]).not_to include("url_content_mismatch")
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

  it "does not flag stale_content for evergreen science and data pages with dated secondary content" do
    sections = 6.times.map do |i|
      <<~SECTION
        <h2>Science section #{i + 1}</h2>
        <p>This mission reference explains telescope operations, science themes, instrumentation, data releases, and long-lived facts for researchers and students.</p>
      SECTION
    end.join("\n")
    dated_cards = 4.times.map do |i|
      <<~CARD
        <aside class="related-card">
          <time datetime="2021-0#{i + 1}-10T10:00:00Z">2021 update #{i + 1}</time>
          <a href="/missions/webb/story-#{i + 1}">Related Webb science story #{i + 1}</a>
        </aside>
      CARD
    end.join("\n")
    html = <<~HTML
      <html>
        <head>
          <title>James Webb Space Telescope Mission</title>
          <meta property="article:published_time" content="2021-03-15T10:00:00Z">
          <meta property="og:type" content="article">
          <script type="application/ld+json">
          {"@context":"https://schema.org","@type":"NewsArticle","headline":"James Webb Space Telescope Mission","datePublished":"2021-03-15T10:00:00Z"}
          </script>
        </head>
        <body>
          <main>
            <article>
              <h1>James Webb Space Telescope Mission</h1>
              <h2>Key Facts</h2>
              <p>Key facts describe the observatory, orbit, sunshield, instruments, and mission overview for an evergreen NASA Science reference page.</p>
              <h2>Data Explorer</h2>
              <p>Researchers use the data explorer, charts, mission overview, and science themes as long-lived reference material.</p>
              #{sections}
              #{dated_cards}
            </article>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://science.example.org/mission/webb/", html) do |page|
      payload = extract(page)

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

  it "does not flag syndicated_repost for official legal instruments with wire-service words elsewhere" do
    articles = 12.times.map do |i|
      <<~ARTICLE
        <h2>Article #{i + 1}</h2>
        <p>The States Parties to the present Covenant undertake to respect and ensure the rights recognized in this article, in accordance with the Charter of the United Nations.</p>
      ARTICLE
    end.join("\n")
    html = <<~HTML
      <html>
        <head><title>International Covenant on Civil and Political Rights | Official Instrument</title></head>
        <body>
          <main>
            <article>
              <h1>International Covenant on Civil and Political Rights</h1>
              <p>Adopted by General Assembly resolution 2200A. Entry into force: 23 March 1976. Ratification status is maintained by the United Nations depositary.</p>
              <p>Preamble: The States Parties to the present Covenant recognize the inherent dignity of the human person.</p>
              #{articles}
              <footer>News and press release links may mention PR Newswire, Cision, or Business Wire in unrelated site chrome.</footer>
            </article>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.ohchr.example.org/en/instruments/international-covenant-civil-and-political-rights", html) do |page|
      payload = extract(page)

      expect(payload["markdown"]).to include("States Parties to the present Covenant")
      expect(payload["warnings"]).not_to include("syndicated_repost")
    end
  end

  it "does not flag official translated statute pages as syndicated reposts" do
    sections = 8.times.map do |i|
      <<~SECTION
        <h2>Section #{i + 1}</h2>
        <p>The legal provisions of this Code apply to the rights and duties described in this section.</p>
      SECTION
    end.join("\n")
    html = <<~HTML
      <html>
        <head><title>German Civil Code BGB</title></head>
        <body>
          <main id="paddingLR12">
            <article>
              <h1>German Civil Code BGB</h1>
              <p>Translation provided by Langenscheidt Übersetzungsservice, updated by Neil Mussett. The translation has most recently been revised and updated by Samson Übersetzungen GmbH.</p>
              <p>Version information: The translation includes the amendment to the Act by Article 1 of the Act of 10 August 2021 (Federal Law Gazette I p. 3515).</p>
              <p>Translations may not be updated at the same time as the German legal provisions displayed on this website.</p>
              #{sections}
            </article>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.gesetze-im-internet.example/englisch_bgb/", html) do |page|
      payload = extract(page)

      expect(payload["markdown"]).to include("Translation provided by")
      expect(payload["warnings"]).not_to include("syndicated_repost")
    end
  end

  it "does not flag court judgment pages as URL mismatches or syndicated reposts" do
    paragraphs = 10.times.map do |i|
      "<p>Lord Example explained ground #{i + 1} of the appeal. The appellant and respondent addressed the " \
        "House of Lords on statutory interpretation, detention, and the proper disposal of the cause.</p>"
    end.join("\n")
    html = <<~HTML
      <html>
        <head>
          <title>Reid v. Secretary of State for Scotland and Another [1998] UKHL 43</title>
          <meta name="citation" content="[1998] UKHL 43">
        </head>
        <body>
          <table><tr><td>Home</td><td>Databases</td><td>United Kingdom House of Lords Decisions</td></tr></table>
          <main>
            <article>
              <h1>Reid v. Secretary of State for Scotland and Another [1998] UKHL 43</h1>
              <p><strong>HOUSE OF LORDS</strong></p>
              <p><strong>OPINIONS OF THE LORDS OF APPEAL FOR JUDGMENT IN THE CAUSE</strong></p>
              <p>Hutchison Reid (Respondent) v. Secretary of State for Scotland and Another (Appellants).</p>
              #{paragraphs}
            </article>
          </main>
          <footer>Archive support links mention Business Wire, PR Newswire, and Cision in unrelated site chrome.</footer>
        </body>
      </html>
    HTML

    with_url_page("https://www.bailii.example/uk/cases/UKHL/1998/43.html", html) do |page|
      payload = extract(page)

      expect(payload["contentType"]).to eq("article")
      expect(payload["markdown"]).to include("OPINIONS OF THE LORDS OF APPEAL")
      expect(payload["warnings"]).not_to include("url_content_mismatch")
      expect(payload["warnings"]).not_to include("syndicated_repost")
    end
  end
end
