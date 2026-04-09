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
end
