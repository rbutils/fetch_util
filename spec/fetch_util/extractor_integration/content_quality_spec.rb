# frozen_string_literal: true

RSpec.describe 'FetchUtil extractor integration' do
  include_context 'extractor integration helpers'

  # P2-13: Duplicate-line suppression in cleanupMarkdownNoise
  it "collapses consecutive duplicate lines in extracted markdown" do
    html = <<~HTML
      <html>
        <head><title>Test Article</title></head>
        <body>
          <main>
            <article>
              <h1>Test Article</h1>
              <p>Introduction paragraph with real content.</p>
              <p>Share this article</p>
              <p>Share this article</p>
              <p>Share this article</p>
              <p>Share this article</p>
              <p>The article continues with more meaningful text here.</p>
            </article>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.example.com/test-article", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      markdown = payload["markdown"]
      # Consecutive duplicates (3+) should be collapsed to 1 occurrence
      occurrences = markdown.scan(/Share this article/).length
      expect(occurrences).to be <= 2
      expect(markdown).to include("Introduction paragraph with real content")
      expect(markdown).to include("The article continues with more meaningful text")
    end
  end

  it "collapses non-consecutive duplicate lines appearing many times" do
    # Build HTML with the same line repeated 5 times non-consecutively
    items = 5.times.map do |i|
      "<p>Unique paragraph number #{i + 1}.</p>\n<p>Repeated boilerplate line here</p>"
    end.join("\n")
    html = <<~HTML
      <html>
        <head><title>Duplicate Test</title></head>
        <body>
          <main>
            <article>
              <h1>Duplicate Test</h1>
              #{items}
            </article>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.example.com/dup-test", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      markdown = payload["markdown"]
      # Non-consecutive duplicates appearing 4+ times should be collapsed to first occurrence only
      occurrences = markdown.scan(/Repeated boilerplate line here/).length
      expect(occurrences).to be <= 3
    end
  end

  # P2-14: Nav-only / chrome-only short extraction warning
  it "flags heading-heavy chrome-only extractions as short_extraction" do
    # Build a page where Readability extracts a short article dominated by headings
    # with minimal prose (simulating chrome/navigation-only extraction).
    # Use repeated footer links to inflate pageText beyond 2000 chars.
    footer_links = 40.times.map { |i| "<a href=\"/page-#{i}\">Page #{i + 1} with extra text</a>" }.join(" | \n")
    html = <<~HTML
      <html>
        <head><title>News Portal Sections</title></head>
        <body>
          <main>
            <article>
              <h1>News Portal</h1>
              <h2>Politics</h2>
              <h2>Economy</h2>
              <h2>World</h2>
              <h2>Culture</h2>
              <p>Navigate above.</p>
            </article>
          </main>
          <footer>#{footer_links}</footer>
        </body>
      </html>
    HTML

    with_url_page("https://www.tvp.info/some-article-slug", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["contentType"]).to eq("article")
      expect(payload["warnings"]).to include("short_extraction")
    end
  end

  # P2-15: Event listing / calendar content format detection
  it "detects event listing pages via title and date patterns" do
    html = <<~HTML
      <html>
        <head><title>Events Calendar - Reykjavik</title></head>
        <body>
          <main>
            <article>
              <h1>Events Calendar - Reykjavik</h1>
              <div class="event">
                <h2>Jazz Night</h2>
                <p>15 January 2026 - Harpa Concert Hall</p>
                <p>An evening of jazz with local musicians.</p>
              </div>
              <div class="event">
                <h2>Art Exhibition Opening</h2>
                <p>22 January 2026 - National Gallery</p>
                <p>Contemporary Icelandic art.</p>
              </div>
              <div class="event">
                <h2>Food Festival</h2>
                <p>5 February 2026 - City Centre</p>
                <p>Local and international cuisine.</p>
              </div>
            </article>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://grapevine.is/events/", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["contentFormat"]).to eq("event_listing")
      expect(payload["warnings"]).to include("multi_topic_page")
    end
  end

  it "detects event pages via Event structured data" do
    html = <<~HTML
      <html>
        <head>
          <title>Upcoming Events</title>
          <script type="application/ld+json">
          {
            "@context": "https://schema.org",
            "@type": "Event",
            "name": "Summer Music Festival",
            "startDate": "2026-07-15",
            "location": { "@type": "Place", "name": "City Park" }
          }
          </script>
        </head>
        <body>
          <main>
            <article>
              <h1>Upcoming Events</h1>
              <p>Join us for the summer season.</p>
            </article>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://example.com/events/summer", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["contentFormat"]).to eq("event_listing")
    end
  end

  # P2-16: Video-only page content format detection
  it "detects video pages via VideoObject structured data with short text" do
    html = <<~HTML
      <html>
        <head>
          <title>Evening News Bulletin</title>
          <script type="application/ld+json">
          {
            "@context": "https://schema.org",
            "@type": "VideoObject",
            "name": "Evening News Bulletin",
            "description": "Today's evening news summary.",
            "uploadDate": "2026-04-09",
            "duration": "PT25M"
          }
          </script>
        </head>
        <body>
          <main>
            <h1>Evening News Bulletin</h1>
            <p>Watch today's evening news summary.</p>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://auvio.rtbf.be/emission/jt-19h30", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["contentFormat"]).to eq("video")
      expect(payload["warnings"]).to include("multi_topic_page")
    end
  end

  it "detects video pages via video player DOM elements with short content" do
    html = <<~HTML
      <html>
        <head><title>Live Coverage: Press Conference</title></head>
        <body>
          <main>
            <h1>Live Coverage: Press Conference</h1>
            <div class="video-player" data-video-id="abc123">
              <video src="https://cdn.example.com/stream.mp4"></video>
            </div>
            <p>Watch the live stream above.</p>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://example.com/video/press-conference", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["contentFormat"]).to eq("video")
    end
  end

  it "does not classify full articles with embedded video as video format" do
    paragraphs = 10.times.map do |i|
      "<p>This is paragraph #{i + 1} of the article with substantial content that discusses the topic in depth and provides meaningful analysis.</p>"
    end.join("\n")
    html = <<~HTML
      <html>
        <head>
          <title>In-Depth Analysis Article</title>
          <script type="application/ld+json">
          {
            "@context": "https://schema.org",
            "@type": "VideoObject",
            "name": "Summary Video",
            "description": "Video summary of the article."
          }
          </script>
        </head>
        <body>
          <main>
            <article>
              <h1>In-Depth Analysis Article</h1>
              <div class="video-player"><video src="summary.mp4"></video></div>
              #{paragraphs}
            </article>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://example.com/analysis/detailed-report", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      # Full articles with embedded video should NOT be classified as video
      expect(payload["contentFormat"]).not_to eq("video")
    end
  end

  it "detects video pages via video URL path with minimal prose" do
    html = <<~HTML
      <html>
        <head><title>Replay: Evening Journal</title></head>
        <body>
          <main>
            <h1>Replay: Evening Journal</h1>
            <p>Click play to watch.</p>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://auvio.rtbf.be/replay/evening-journal", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["contentFormat"]).to eq("video")
    end
  end

  # Paywall partial content: improved detection with higher threshold and ratio check
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
      payload = FetchUtil::Extractor.new.extract(page)

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
      payload = FetchUtil::Extractor.new.extract(page)

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
      payload = FetchUtil::Extractor.new.extract(page)

      # The article text is small relative to the huge page text, should flag truncation
      expect(payload["warnings"]).to include("truncated_content")
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
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["warnings"]).to include("url_content_mismatch")
    end
  end

  # Photo gallery page detection
  it "flags photo_gallery_page for gallery URL paths with minimal text" do
    html = <<~HTML
      <html>
        <head><title>Serie A - Photo Gallery</title></head>
        <body>
          <main>
            <h1>Serie A Highlights</h1>
            <div class="gallery">
              <img src="photo1.jpg" alt="Goal celebration">
              <img src="photo2.jpg" alt="Match action">
            </div>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.sportmediaset.it/foto/serie-a-highlights", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["warnings"]).to include("photo_gallery_page")
    end
  end

  it "does not flag photo_gallery_page when gallery URL has substantial text" do
    paragraphs = 15.times.map { |i| "<p>Detailed description of photo #{i + 1} showing the event in context with historical background.</p>" }.join("\n")
    html = <<~HTML
      <html>
        <head><title>Historical Photo Collection</title></head>
        <body>
          <main>
            <article>
              <h1>Historical Photo Collection</h1>
              #{paragraphs}
            </article>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.example.com/gallery/historical-collection", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["warnings"]).not_to include("photo_gallery_page")
    end
  end

  # Stale content detection
  it "flags stale_content for articles published more than 30 days ago" do
    html = <<~HTML
      <html>
        <head>
          <title>Dublin Sea Level Report</title>
          <meta property="article:published_time" content="2021-03-15T10:00:00Z">
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
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["warnings"]).to include("stale_content")
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
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["warnings"]).not_to include("stale_content")
    end
  end

  # Newsletter / hub / digest format detection
  it "detects newsletter digest pages with many short heading-delimited blocks" do
    # Build a page that looks like a newsletter / flash-news digest:
    # many headings, each followed by a short summary + link
    # Title avoids matching the "briefing" pattern to test newsletter-specific heuristic
    items = 7.times.map do |i|
      <<~ITEM
        <h2>Story #{i + 1}: Headline about topic #{i + 1}</h2>
        <p>Brief summary of the story with a <a href="/story-#{i + 1}">read more link</a>.</p>
      ITEM
    end.join("\n")
    html = <<~HTML
      <html>
        <head><title>Today's Flash Coverage</title></head>
        <body>
          <main>
            <article>
              <h1>Today's Flash Coverage</h1>
              #{items}
            </article>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.meta.mk/todays-flash-coverage", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["contentFormat"]).to eq("newsletter")
      expect(payload["warnings"]).to include("multi_topic_page")
    end
  end

  it "detects link-dominated hub pages as newsletter format" do
    # Build a page dominated by links with very little prose — typical hub/index
    links = 12.times.map do |i|
      "<h3><a href=\"/article-#{i}\">Article headline number #{i + 1}</a></h3>"
    end.join("\n")
    html = <<~HTML
      <html>
        <head><title>News Hub - Today's Stories</title></head>
        <body>
          <main>
            <article>
              <h1>News Hub</h1>
              #{links}
            </article>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.example-hub.com/todays-stories", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["contentFormat"]).to eq("newsletter")
      expect(payload["warnings"]).to include("multi_topic_page")
    end
  end

  it "does not flag a regular article with a few headings as newsletter" do
    paragraphs = 6.times.map do |i|
      <<~SECTION
        <h2>Section #{i + 1}</h2>
        <p>This is a detailed paragraph providing in-depth analysis and context for section #{i + 1}. The content discusses multiple aspects of the topic with sufficient depth to demonstrate this is a genuine article rather than a digest of short items. Additional sentences provide more context and nuance to the discussion at hand.</p>
      SECTION
    end.join("\n")
    html = <<~HTML
      <html>
        <head><title>Comprehensive Analysis Report</title></head>
        <body>
          <main>
            <article>
              <h1>Comprehensive Analysis Report</h1>
              #{paragraphs}
            </article>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.example.com/comprehensive-analysis-report", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["contentFormat"]).not_to eq("newsletter")
    end
  end

  # Paywall third-tier detection: longer teasers with very low body-to-page ratio
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
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["warnings"]).to include("paywall_partial_content")
      expect(payload["paywallState"]).to eq("detected")
    end
  end

  # Consent interstitial: Nordic language detection
  it "detects Norwegian consent wall interstitial" do
    html = <<~HTML
      <html>
        <head><title>Dine personverninnstillinger</title></head>
        <body>
          <main>
            <h1>Dine personverninnstillinger</h1>
            <p>Vi bruker informasjonskapsler og lignende teknologier for å gi deg en bedre opplevelse.</p>
            <p>Vi og våre partnere lagrer og bruker informasjonskapsler for å tilpasse innhold og annonser.</p>
            <button>Godta alle</button>
            <button>Avvis valgfrie informasjonskapsler</button>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.document.no/some-article", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["warnings"]).to include("consent_interstitial")
    end
  end

  it "detects Swedish consent wall interstitial" do
    html = <<~HTML
      <html>
        <head><title>Cookie-inställningar</title></head>
        <body>
          <main>
            <h1>Vi använder kakor</h1>
            <p>Vi anvander kakor och liknande tekniker for att ge dig en battre upplevelse.</p>
            <p>Samtycke till personanpassade annonser och innehall.</p>
            <button>Acceptera alla</button>
            <button>Avvisa valfria kakor</button>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.svd.se/some-article", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["warnings"]).to include("consent_interstitial")
    end
  end

  it "detects Finnish consent wall interstitial" do
    html = <<~HTML
      <html>
        <head><title>Evästeasetukset</title></head>
        <body>
          <main>
            <h1>Evästeasetukset</h1>
            <p>Käytämme evästeitä ja vastaavia teknologioita parantaaksemme käyttökokemustasi.</p>
            <p>Me ja kumppanimme käytämme evästeitä mainonnan ja sisällön personointiin.</p>
            <button>Hyväksy kaikki</button>
            <button>Hylkää valinnaiset evästeet</button>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.hs.fi/some-article", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["warnings"]).to include("consent_interstitial")
    end
  end

  it "detects Lithuanian consent wall interstitial" do
    html = <<~HTML
      <html>
        <head><title>Slapukų nustatymai</title></head>
        <body>
          <main>
            <h1>Naudojame slapukus</h1>
            <p>Naudojame slapukus ir panašias technologijas, kad pagerintume jūsų patirtį.</p>
            <p>Slapukų nustatymai leidžia jums pasirinkti kokius slapukus naudojame.</p>
            <button>Priimti visus</button>
            <button>Atmesti pasirinktinius slapukus</button>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.delfi.lt/some-article", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["warnings"]).to include("consent_interstitial")
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
      payload = FetchUtil::Extractor.new.extract(page)

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
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["warnings"]).not_to include("syndicated_repost")
    end
  end

  # --- Liveblog false-positive prevention ---

  it "does not flag liveblog for a regular article with sidebar time elements" do
    # Simulates an article page where <time> elements exist in a sidebar (related articles)
    # but the main content is a single article — should NOT trigger liveblog
    sidebar_times = (1..6).map do |i|
      %(<li><a href="/article-#{i}"><time datetime="2026-04-0#{i}T10:00:00">April #{i}</time> Related story #{i}</a></li>)
    end.join("\n")

    html = <<~HTML
      <html>
        <head><title>Regular News Article</title></head>
        <body>
          <main>
            <article>
              <h1>Regular News Article</h1>
              <time datetime="2026-04-10T08:30:00">April 10, 2026</time>
              <p>This is a regular news article with substantial content about an important topic. The journalist reports from the scene with detailed observations and expert commentary that spans multiple paragraphs.</p>
              <p>Additional reporting provides context and background information that helps readers understand the significance of the events described in this article.</p>
              <h2>Expert Analysis</h2>
              <p>Leading researchers have weighed in on the implications, noting that similar patterns have been observed in previous years across multiple regions.</p>
              <h2>Public Reaction</h2>
              <p>Community members have expressed a range of opinions about the developments, with some welcoming the changes and others expressing concern about potential consequences.</p>
            </article>
          </main>
          <aside class="sidebar">
            <h3>Related Articles</h3>
            <ul>
              #{sidebar_times}
            </ul>
          </aside>
        </body>
      </html>
    HTML

    with_url_page("https://www.tagesschau.de/inland/article-example", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["warnings"]).not_to include("multi_topic_page")
    end
  end

  it "still flags liveblog for a genuine liveblog page with many timestamped entries" do
    entries = (1..10).map do |i|
      <<~ENTRY
        <h2>Update #{i}: Development at #{8 + i}:00</h2>
        <time datetime="2026-04-10T#{format("%02d", 8 + i)}:00:00">#{8 + i}:00 CET</time>
        <p>Breaking development number #{i} with details about the ongoing situation and reporter commentary.</p>
      ENTRY
    end.join("\n")

    html = <<~HTML
      <html>
        <head><title>Live: Breaking Event Coverage</title></head>
        <body>
          <main>
            <article>
              <h1>Live: Breaking Event Coverage</h1>
              #{entries}
            </article>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.example.com/live-coverage", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["warnings"]).to include("multi_topic_page")
    end
  end

  # --- Outbrain/Taboola ad URL stripping ---

  it "strips Outbrain and Taboola ad links from extracted markdown" do
    html = <<~HTML
      <html>
        <head><title>Article With Ad Links</title></head>
        <body>
          <main>
            <article>
              <h1>Article With Ad Links</h1>
              <p>This is a legitimate article about technology trends in 2026. The industry has seen remarkable growth in several key areas including artificial intelligence and renewable energy.</p>
              <p>Read more: <a href="https://paid.outbrain.com/network/redir?key=abc123&url=https://spam.example.com">Sponsored: Amazing Product</a></p>
              <p>Experts predict continued growth in the sector, driven by consumer demand and regulatory support for green initiatives across Europe and North America.</p>
              <p><a href="https://trc.taboola.com/campaign/click?item=12345">You Won't Believe This</a></p>
              <p>The article continues with substantial analysis of market dynamics and competitive positioning among the major players.</p>
            </article>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.lemonde.fr/article-with-ads", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).not_to match(/outbrain\.com/i)
      expect(payload["markdown"]).not_to match(/taboola\.com/i)
      # The actual article content should still be present
      expect(payload["markdown"]).to include("technology trends")
    end
  end

  # --- Newsletter/hub detection threshold ---

  it "detects hub/newsletter pages with 4 headings" do
    # A page with exactly 4 headings and many links — should now be caught
    # with the lowered threshold (was >= 5, now >= 4)
    items = (1..6).map do |i|
      <<~ITEM
        <h2>Story #{i}: Notable Event</h2>
        <p>Brief summary of story #{i}. <a href="https://example.com/story-#{i}">Read more</a></p>
      ITEM
    end.join("\n")

    html = <<~HTML
      <html>
        <head><title>Daily News Digest</title></head>
        <body>
          <main>
            #{items}
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.channel4.com/news", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["warnings"]).to include("multi_topic_page")
    end
  end
end
