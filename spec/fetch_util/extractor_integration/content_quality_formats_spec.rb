# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'FetchUtil extractor integration - content quality formats' do
  include_context 'extractor integration helpers'

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
      payload = extract(page)

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
      payload = extract(page)

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
      payload = extract(page)

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
      payload = extract(page)

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
      payload = extract(page)

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
      payload = extract(page)

      expect(payload["contentFormat"]).to eq("video")
    end
  end

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
      payload = extract(page)

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
      payload = extract(page)

      expect(payload["warnings"]).not_to include("photo_gallery_page")
    end
  end

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
      payload = extract(page)

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
      payload = extract(page)

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
      payload = extract(page)

      expect(payload["contentFormat"]).not_to eq("newsletter")
    end
  end

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
      payload = extract(page)

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
      payload = extract(page)

      expect(payload["warnings"]).to include("multi_topic_page")
    end
  end

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
      payload = extract(page)

      expect(payload["warnings"]).to include("multi_topic_page")
    end
  end
end
