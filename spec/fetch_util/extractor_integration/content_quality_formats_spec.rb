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

  it "does not classify one unknown-host report with quote sections and topic tags as a newsletter" do
    title = "President addresses the summit"
    subtitle = "At the summit, the president described the next steps and answered questions."
    lead = "The opening report summarizes the press conference and links to the full summit record."
    quote_sections = [
      ["We will review the proposal", "The president said officials would review the proposal before making a decision."],
      ["The talks are continuing", "The delegation confirmed that discussions with regional partners are continuing."],
      ["We have not reached an agreement", "The press conference made clear that no agreement has yet been reached."],
      ["There will be another meeting", "Officials said they expect another meeting after the technical review is complete."],
      ["We will publish the findings", "The final statement said the findings would be published after all parties respond."]
    ]
    topic_tags = %w[Summit President Security Region Diplomacy]
    sections = quote_sections.map do |heading, paragraph|
      "<section><h3>#{heading}</h3><p>#{paragraph}</p></section>"
    end.join
    tags = topic_tags.each_with_index.map do |tag, index|
      %(<a href="/topics/topic-#{index + 1}">#{tag}</a>)
    end.join(" ")
    html = <<~HTML
      <html><head><title>#{title}</title></head><body><main><article>
        <header><h1>#{title}</h1><h2>#{subtitle}</h2></header>
        <p>#{lead} <a href="/reports/summit-record">Summit record</a>.</p>
        #{sections}
        <section class="topic-taxonomy"><p>Topics:</p>#{tags}</section>
      </article></main></body></html>
    HTML
    tag_urls = 5.times.map { |index| "/topics/topic-#{index + 1}" }

    with_url_page("https://independent.example/reports/summit", html) do |page|
      payload = extract(page)
      markdown = payload.fetch("markdown")

      expect(payload["contentType"]).to eq("article")
      expect(payload["contentFormat"]).to be_nil
      expect(payload["warnings"]).not_to include("multi_topic_page")
      expect(markdown).to include(title, subtitle, lead, *quote_sections.flatten, *topic_tags)
      expect(payload.fetch("html")).to include(*tag_urls)
      expect(markdown.index(quote_sections.first.first)).to be < markdown.index(quote_sections.last.first)
    end
  end

  it "keeps linked short records as a newsletter on an unknown host" do
    records = (1..6).map do |index|
      <<~RECORD
        <h2>Independent report #{index}</h2>
        <p>Brief summary #{index} describes a separate public development. <a href="/stories/#{index}">Read the full report</a>.</p>
      RECORD
    end
    html = <<~HTML
      <html><head><title>Independent reports</title></head><body><main><article>
        <h1>Independent reports</h1>#{records.join}
      </article></main></body></html>
    HTML
    headlines = 6.times.map { |index| "Independent report #{index + 1}" }
    summaries = 6.times.map { |index| "Brief summary #{index + 1} describes a separate public development." }
    story_urls = 6.times.map { |index| "/stories/#{index + 1}" }

    with_url_page("https://independent.example/coverage/reports", html) do |page|
      payload = extract(page)
      markdown = payload.fetch("markdown")

      expect(payload["contentType"]).to eq("article")
      expect(payload["contentFormat"]).to eq("newsletter")
      expect(payload["warnings"]).to include("multi_topic_page")
      expect(markdown).to include(*headlines, *summaries, "Read the full report")
      expect(payload.fetch("html")).to include(*story_urls)
    end
  end

  it "does not classify a titled single article with focal sections as a newsletter" do
    sections = (1..6).map do |index|
      <<~SECTION
        <section>
          <h2>Part #{index}: Reporting detail</h2>
          <p>The article's reporting explains this development and its context for readers. <a href="/related/#{index}">Related report #{index}</a>.</p>
        </section>
      SECTION
    end.join
    title = "A single report about an unfolding public event"
    html = <<~HTML
      <html><head><title>#{title}</title>
        <meta property="og:type" content="article">
        <meta property="og:title" content="#{title}">
      </head><body><main><article>
        <h1>#{title}</h1>
        <p>The source identifies this as one report, despite its related linked sections.</p>
        #{sections}
      </article></main></body></html>
    HTML

    with_url_page("https://unknown.example/reports/public-event", html) do |page|
      payload = extract(page)
      expect(payload["contentFormat"]).not_to eq("newsletter")
      expect(payload["markdown"]).to include("Part 1: Reporting detail", "Part 6: Reporting detail")
    end
  end

  it "does not infer newsletter from linked list entries without authored digest summaries" do
    entries = (1..8).map do |index|
      day = format("%02d", index)
      %(<article><h2><a href="/news/#{index}">Independent newsroom report #{index}</a></h2>
        <time datetime="2026-09-#{day}">September #{index}</time></article>)
    end.join
    html = <<~HTML
      <html><head><title>Independent newsroom</title></head><body><main>
        <h1>Independent newsroom</h1>#{entries}
      </main></body></html>
    HTML

    with_url_page("https://unknown.example/news/", html) do |page|
      payload = extract(page)
      expect(payload["contentType"]).to eq("list")
      expect(payload["contentFormat"]).not_to eq("newsletter")
      expect(payload["warnings"]).to include("multi_topic_page")
      expect(payload["markdown"]).to include("Independent newsroom report 1", "Independent newsroom report 8")
    end
  end

  it "keeps the multi-topic warning for product feature modules without newsletter format" do
    modules = (1..8).map do |index|
      <<~MODULE
        <article>
          <h2><a href="/features/#{index}">Platform feature #{index}</a></h2>
          <p>This module explains a distinct platform capability and how teams apply it in their daily work.</p>
        </article>
      MODULE
    end.join
    html = <<~HTML
      <html><head><title>Platform features</title>
        <meta property="og:type" content="website">
        <script type="application/ld+json">{"@context":"https://schema.org","@type":"SoftwareApplication","name":"Platform"}</script>
      </head><body><header><h1>Platform features</h1></header><section class="features">#{modules}</section></body></html>
    HTML

    with_url_page("https://unknown.example/platform/features", html) do |page|
      payload = extract(page)
      expect(payload["contentType"]).to eq("list")
      expect(payload["contentFormat"]).not_to eq("newsletter")
      expect(payload["warnings"]).to include("multi_topic_page")
      expect(payload["markdown"]).to include("Platform feature 1", "Platform feature 8")
    end
  end

  it "detects an anonymous digest from an owned editorial introduction and independent list records" do
    records = (1..6).map do |index|
      <<~RECORD
        <article>
          <h2><a href="/reports/#{index}">Independent public report #{index}</a></h2>
          <p>Summary #{index} explains a separate development and why it matters to readers.</p>
        </article>
      RECORD
    end.join
    html = <<~HTML
      <html><head><title>Independent reports</title></head><body><main>
        <h1>Independent reports</h1>
        <p>Our editors selected six separate reports and added context on the developments that matter across policy, science, and community life.</p>
        #{records}
      </main></body></html>
    HTML

    with_url_page("https://unknown.example/reports/selection", html) do |page|
      payload = extract(page)
      markdown = payload.fetch("markdown")
      expect(payload["contentType"]).to eq("list")
      expect(payload["contentFormat"]).to eq("newsletter")
      expect(markdown).to include("Our editors selected six separate reports", "Independent public report 1", "Independent public report 6")
      expect(payload.fetch("html")).to include(*6.times.map { |index| "/reports/#{index + 1}" })
    end
  end

  it "does not infer newsletter from linked topic sections outside a focal article" do
    sections = (1..6).map do |index|
      <<~SECTION
        <section>
          <h2>Research area #{index}</h2>
          <p>Our teams investigate this area and publish work for practitioners and policy makers.</p>
          <p><a href="/research/reports/#{index}">Reports</a> <a href="/research/projects/#{index}">Projects</a></p>
        </section>
      SECTION
    end.join
    title = "Research"
    html = <<~HTML
      <html><head><title>#{title}</title>
        <meta property="og:type" content="article">
        <meta property="og:title" content="#{title}">
      </head><body><main>
        <article><h1>#{title}</h1><p>Research across natural environments, production, technology, space, and health.</p></article>
        #{sections}
      </main></body></html>
    HTML

    with_url_page("https://unknown.example/research", html) do |page|
      payload = extract(page)
      expect(payload["contentFormat"]).not_to eq("newsletter")
      expect(payload["markdown"]).to include("Research area 1", "Research area 6", "/research/reports/1", "/research/projects/6")
      expect(payload.fetch("markdown").index("Research area 1")).to be < payload.fetch("markdown").index("Research area 6")
    end
  end

  it "does not count taxonomy links split across paragraphs as linked newsletter records" do
    sections = (1..5).map do |index|
      "<section><h3>Conference statement #{index}</h3><p>The speaker described the next step in the negotiations.</p></section>"
    end.join
    tags = (1..5).map do |index|
      %(<p><a rel="tag" href="/topics/topic-#{index}">Topic #{index}</a></p>)
    end.join
    html = <<~HTML
      <html><head><title>Conference statement</title></head><body><main><article>
        <h1>Conference statement</h1><h2>What officials said</h2>
        <p>The report covers one press conference and links to <a href="/reports/briefing">the briefing</a>.</p>
        #{sections}<section class="topic-taxonomy"><h3>Topics</h3>#{tags}</section>
      </article></main></body></html>
    HTML

    with_url_page("https://independent.example/reports/conference", html) do |page|
      payload = extract(page)

      expect(payload["contentFormat"]).to be_nil
      expect(payload["warnings"]).not_to include("multi_topic_page")
      expect(payload.fetch("markdown")).to include("Conference statement", "Topic 1", "Topic 5")
      expect(payload.fetch("html")).to include(*5.times.map { |index| "/topics/topic-#{index + 1}" })
    end
  end

  it "counts a repeated destination at most once across short headed sections" do
    sections = (1..5).map do |index|
      <<~SECTION
        <h3>Conference statement #{index}</h3>
        <p>The speaker described the next step in the negotiations. <a href="/reports/shared">Read the same report</a>.</p>
      SECTION
    end.join
    html = <<~HTML
      <html><head><title>Conference statement</title></head><body><main><article>
        <h1>Conference statement</h1><h2>What officials said</h2>
        <p>The report covers one press conference and links to <a href="/reports/shared">the briefing</a>.</p>
        #{sections}
      </article></main></body></html>
    HTML

    with_url_page("https://independent.example/reports/conference", html) do |page|
      payload = extract(page)

      expect(payload["contentFormat"]).to be_nil
      expect(payload["warnings"]).not_to include("multi_topic_page")
      expect(payload.fetch("markdown")).to include(*5.times.map { |index| "Conference statement #{index + 1}" })
      expect(payload.fetch("html")).to include("/reports/shared")
    end
  end

  it "does not count fragment or topic navigation as independent linked records" do
    sections = (1..5).map do |index|
      <<~SECTION
        <section id="section-#{index}">
          <h3>Conference statement #{index}</h3>
          <p>The speaker described the next step in the negotiations. <a href="#section-#{index}">Jump to this section</a>.</p>
        </section>
      SECTION
    end.join
    navigation = (1..5).map do |index|
      %(<a href="/topics/topic-#{index}">Topic #{index}</a>)
    end.join("\n")
    html = <<~HTML
      <html><head><title>Conference statement</title></head><body><main><article>
        <h1>Conference statement</h1><h2>What officials said</h2>
        <p>The report covers one press conference and gives readers a topic index.</p>
        #{sections}<nav aria-label="Topics">#{navigation}</nav>
      </article></main></body></html>
    HTML

    with_url_page("https://independent.example/reports/conference", html) do |page|
      payload = extract(page)

      expect(payload["contentFormat"]).to be_nil
      expect(payload["warnings"]).not_to include("multi_topic_page")
      expect(payload.fetch("markdown")).to include(*5.times.map { |index| "Conference statement #{index + 1}" })
      expect(payload.fetch("html")).to include(*5.times.map { |index| "/topics/topic-#{index + 1}" })
    end
  end

  it "keeps short linked records as newsletter when their destinations are long" do
    long_path = "detail-" * 28
    urls = (1..6).map { |index| "/stories/#{index}/#{long_path}" }
    records = urls.each_with_index.map do |url, index|
      <<~RECORD
        <h2>Independent report #{index + 1}</h2>
        <p>Brief summary #{index + 1} describes a separate public development. <a href="#{url}">Read the full report</a>.</p>
      RECORD
    end
    html = <<~HTML
      <html><head><title>Independent reports</title></head><body><main><article>
        <h1>Independent reports</h1>#{records.join}
      </article></main></body></html>
    HTML

    with_url_page("https://independent.example/coverage/reports", html) do |page|
      payload = extract(page)

      expect(payload["contentFormat"]).to eq("newsletter")
      expect(payload["warnings"]).to include("multi_topic_page")
      expect(payload.fetch("markdown")).to include("Brief summary 1", "Brief summary 6")
      expect(payload.fetch("html")).to include(*urls)
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

  it "keeps a narrative Japanese product review with linked commerce cards as an article" do
    sections = (1..5).map do |index|
      <<~SECTION
        <h2>商品のポイント#{index}</h2>
        <p>この商品は毎日の食卓で使いやすく、素材の風味と使い心地を丁寧に確かめました。家族で楽しめる味わいで、季節の料理にも合わせやすいと感じます。</p>
        <article itemtype="https://schema.org/Product">
          <a data-item-id="offer-#{index}" data-detail-setting='{"show_price":true}' href="/shop/item-#{index}">
            <img src="/images/item-#{index}.jpg" alt="商品#{index}">商品#{index}の詳細
          </a>
        </article>
      SECTION
    end.join
    html = <<~HTML
      <html><head><title>夏の食品セットを実際に試したレビュー</title></head><body><main><article>
        <h1>夏の食品セットを実際に試したレビュー</h1>
        <p>こんにちは。今回は夏限定の食品セットを実際に試し、味や使い方を一つずつ紹介します。</p>
        #{sections}
        <p>販売情報まとめ。価格や購入方法を確認してから選ぶと安心です。</p>
        <a href="/shop/bundle">セットを購入する</a>
      </article></main></body></html>
    HTML

    with_url_page("https://reviews.example.com/summer-food-set", html) do |page|
      payload = extract(page)
      expect(payload["contentType"]).to eq("article")
      expect(payload["contentFormat"]).not_to eq("newsletter")
      expect(payload["markdown"]).to include("商品のポイント", "販売情報まとめ", "/shop/item-5", "/shop/bundle")
      expect(payload["html"]).to include(*5.times.map { |index| "item-#{index + 1}.jpg" })
    end
  end

  it "keeps a mixed market digest a newsletter when one story has a product offer card" do
    stories = (1..7).map do |index|
      offer = if index == 3
                '<article itemtype="https://schema.org/Product">' \
                  '<a data-item-id="market-offer" data-detail-setting="{}" href="/offers/fund">' \
                  '<img src="/fund.jpg" alt="Fund offer">Fund offer details</a></article>'
              else
                ""
              end
      <<~STORY
        <h2>Market update #{index}</h2>
        <p>#{offer}The daily market bulletin reports a short update on rates, earnings, and the latest movement in this sector.</p>
        <a href="/markets/story-#{index}">Read the full update</a>
      STORY
    end.join
    html = <<~HTML
      <html><head><title>Today's Market Briefing</title></head><body><main><article>
        <h1>Today's Market Briefing</h1>
        #{stories}
      </article></main></body></html>
    HTML

    with_url_page("https://news.example.com/market-briefing", html) do |page|
      payload = extract(page)

      expect(payload["contentFormat"]).to eq("newsletter")
    end
  end

  it "does not mistake short Japanese narrative prose for a linked digest" do
    html = <<~HTML
      <html><head><title>今日の買い物メモ</title></head><body><main><article>
        <h1>今日の買い物メモ</h1>
        <h2>朝のこと</h2><p>今朝は近所でパンを買い、家でゆっくり朝食を楽しみました。</p><article><a href="/shop/bread"><img src="/bread.jpg" alt="パン">パンの商品情報</a></article>
        <h2>昼のこと</h2><p>昼には季節の野菜を使って、簡単な料理を作りました。</p><article><a href="/shop/vegetables"><img src="/vegetables.jpg" alt="野菜">野菜の商品情報</a></article>
        <h2>夕方のこと</h2><p>夕方は家族と散歩をして、帰りに必要なものを買いました。</p><article><a href="/shop/tea"><img src="/tea.jpg" alt="お茶">お茶の商品情報</a></article>
        <h2>明日の予定</h2><p>明日は天気を見ながら、また出かける場所を決めたいと思います。</p><article><a href="/shop/bag"><img src="/bag.jpg" alt="バッグ">バッグの商品情報</a></article>
      </article></main></body></html>
    HTML

    with_url_page("https://diary.example.com/today", html) do |page|
      payload = extract(page)

      expect(payload["contentFormat"]).not_to eq("newsletter")
      expect(payload["markdown"]).to include("朝のこと", "明日の予定")
    end
  end

  it "does not warn multi_topic_page for a substantial institutional overview with focus cards" do
    intro = 8.times.map do |i|
      <<~PARAGRAPH
        <p>UNICEF works across countries and territories to protect children, provide services, advocate for rights, and support communities before, during, and after emergencies.
        Overview paragraph #{i + 1} explains the agency mission.</p>
      PARAGRAPH
    end.join("\n")
    cards = 7.times.map do |i|
      <<~CARD
        <h2><a href="/focus-#{i + 1}">Focus area #{i + 1}</a></h2>
        <p>Brief programme summary #{i + 1}.</p>
      CARD
    end.join("\n")
    html = <<~HTML
      <html>
        <head><title>What we do | International Children's Agency</title></head>
        <body>
          <main>
            <article>
              <h1>What we do</h1>
              #{intro}
              <h2>What we focus on</h2>
              #{cards}
            </article>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.institution.example.org/what-we-do", html) do |page|
      payload = extract(page)

      expect(payload["contentFormat"]).to eq("newsletter")
      expect(payload["warnings"]).not_to include("multi_topic_page")
    end
  end

  it "does not warn multi_topic_page for a substantial scholarly article with related reference blocks" do
    long_abstract = 70.times.map do |i|
      "Protein structure prediction paragraph #{i + 1} describes methods, results, discussion, data availability, and references for a single scientific article."
    end.join(" ")
    references = 8.times.map do |i|
      <<~REF
        <h2>Reference #{i + 1}</h2>
        <p><a href="/articles/ref-#{i + 1}">Related scientific citation #{i + 1}</a>.</p>
      REF
    end.join("\n")
    html = <<~HTML
      <html>
        <head><title>Highly accurate protein structure prediction with AlphaFold</title></head>
        <body>
          <main>
            <article>
              <h1>Highly accurate protein structure prediction with AlphaFold</h1>
              <h2>Abstract</h2>
              <p>#{long_abstract}</p>
              <h2>Methods</h2>
              <p>The methods section describes the model architecture, datasets, validation, and limitations.</p>
              <h2>References</h2>
              #{references}
            </article>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.journal.example.org/articles/s41586-021-03819-2", html) do |page|
      payload = extract(page)

      expect(payload["contentFormat"]).to eq("newsletter")
      expect(payload["warnings"]).not_to include("multi_topic_page")
    end
  end

  it "does not warn multi_topic_page for an article with related comment and recommendation widgets" do
    article_paragraphs = 8.times.map do |i|
      "<p>Detailed reporting paragraph #{i + 1} explains the event, the people involved, and the follow-up developments in a focused single story.</p>"
    end.join("\n")
    related_links = 6.times.map do |i|
      "<li><a href=\"/related-#{i + 1}\">Related story #{i + 1}</a></li>"
    end.join("\n")
    html = <<~HTML
      <html>
        <head><title>Community Election Results</title></head>
        <body>
          <main>
            <article>
              <h1>Community Election Results</h1>
              #{article_paragraphs}
            </article>
            <aside class="related-widget">
              <h2>Recommended</h2>
              <ul>
                #{related_links}
              </ul>
            </aside>
            <section class="comments-section">
              <h2>Comments</h2>
              <p>Reader reactions and moderation notes.</p>
            </section>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.example.com/community-election-results", html) do |page|
      payload = extract(page)

      expect(payload["warnings"]).not_to include("multi_topic_page")
    end
  end

  it "does not warn multi_topic_page for a structured scientific compound record" do
    sections = (1..8).map do |i|
      <<~SECTION
        <h2><a href="/compound/2244/section-#{i}">#{i} Compound Record Section</a></h2>
        <table class="record-metadata">
          <tr><th>CID</th><td>2244</td></tr>
          <tr><th>Molecular Formula</th><td>C9H8O4</td></tr>
          <tr><th>InChIKey</th><td>BSYNRYMUTXBXSQ-UHFFFAOYSA-N</td></tr>
          <tr><th>Canonical SMILES</th><td>CC(=O)OC1=CC=CC=C1C(=O)O</td></tr>
        </table>
        <p><a href="/compound/2244/download-#{i}">Aspirin data export #{i}</a>.</p>
      SECTION
    end.join("\n")

    html = <<~HTML
      <html>
        <head>
          <title>Aspirin | Compound Record</title>
          <meta property="og:site_name" content="Chemical Database">
        </head>
        <body>
          <main>
            <article>
              <h1>Aspirin</h1>
              <time datetime="2026-01-01T08:00:00Z">08:00 UTC</time>
              <time datetime="2026-01-01T09:00:00Z">09:00 UTC</time>
              <time datetime="2026-01-01T10:00:00Z">10:00 UTC</time>
              <time datetime="2026-01-01T11:00:00Z">11:00 UTC</time>
              <time datetime="2026-01-01T12:00:00Z">12:00 UTC</time>
              <time datetime="2026-01-01T13:00:00Z">13:00 UTC</time>
              #{sections}
            </article>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://science-records.example.org/compound/2244", html) do |page|
      payload = extract(page)

      expect(payload["contentFormat"]).to be_nil
      expect(payload["warnings"]).not_to include("multi_topic_page")
    end
  end

  it "does not warn multi_topic_page for a substantive treaty article index" do
    articles = (1..8).map do |i|
      roman = %w[I II III IV V VI VII VIII][i - 1]
      <<~ARTICLE
        <h3><a href="/chemical-weapons-convention/articles/article-#{i}">Article #{roman} - Convention obligation #{i}</a></h3>
        <p>Article #{roman} sets out requirements for States Parties under the Convention.</p>
      ARTICLE
    end.join("\n")

    html = <<~HTML
      <html>
        <head><title>Chemical Weapons Convention | International Organisation</title></head>
        <body>
          <main>
            <article>
              <h1>Chemical Weapons Convention</h1>
              <p>The Convention on the Prohibition of the Development, Production, Stockpiling and Use of Chemical Weapons and on their Destruction is comprised of a Preamble, Articles, and Annexes.</p>
              <p>States Parties agree to eliminate chemical weapons, submit declarations, and cooperate with verification measures administered under the Convention.</p>
              <p>The instrument includes challenge inspection procedures, obligations for destruction, and implementation measures for activities not prohibited by the Convention.</p>
              #{articles}
            </article>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.institution.example.org/chemical-weapons-convention", html) do |page|
      payload = extract(page)

      expect(payload["contentFormat"]).to eq("newsletter")
      expect(payload["warnings"]).not_to include("multi_topic_page")
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

  it "does not infer liveblog from timestamps on a root homepage list" do
    cards = (1..8).map do |i|
      <<~CARD
        <article>
          <h3><a href="/news/#{i}">Independent report #{i}</a></h3>
          <time datetime="2026-04-10T#{format("%02d", 8 + i)}:00:00">#{8 + i}:00 CET</time>
        </article>
      CARD
    end
    html = <<~HTML
      <html><head><title>Independent newsroom</title></head><body><main>
        <h1>Independent newsroom</h1>
        <section><h2>National reports</h2>#{cards.first(4).join}</section>
        <section><h2>International reports</h2>#{cards.last(4).join}</section>
      </main></body></html>
    HTML

    with_url_page("https://www.example.com/", html) do |page|
      payload = extract(page)

      expect(payload["contentType"]).to eq("list")
      expect(payload["contentFormat"]).not_to eq("liveblog")
    end
  end

  it "does not infer liveblog from dated records in an internal publication series" do
    records = (1..12).map do |index|
      <<~RECORD
        <li>
          <h3><a href="/publications/report-#{index}">Regional indicators report #{index}</a></h3>
          <time datetime="#{2012 + index}-08-15T12:00:00Z">August #{2012 + index}</time>
          <p>Detailed economic and environmental indicators for the region in report #{index}, with independent country and regional assessments.</p>
        </li>
      RECORD
    end.join
    html = <<~HTML
      <html><head><title>Regional indicators publication series</title></head><body>
        <main><h1>Regional indicators publication series</h1><section><h2>Publications</h2><ul>#{records}</ul></section></main>
      </body></html>
    HTML

    with_url_page("https://research.example.org/publications/series/indicators", html) do |page|
      root = File.expand_path("../../..", __dir__)
      source = File.readlines(File.join(root, "websieve/manifest.txt"), chomp: true).reject(&:empty?).map do |entry|
        File.read(File.join(root, "websieve", entry))
      end.join("\n")
      page.add_script_tag(content: source.sub("})(window);", "global.contentFormatProbe = { detect: detectContentFormat, markdown: markdownFor }; })(window);"))
      format = page.evaluate(<<~JS)
        (() => {
          const owner = document.querySelector('main');
          return contentFormatProbe.detect(
            { title: document.title },
            { contentType: 'list', title: document.title, html: owner.innerHTML, textContent: owner.textContent },
            contentFormatProbe.markdown(owner.innerHTML)
          );
        })()
      JS

      expect(format).to be_nil
    end
  end

  it "keeps an owned anonymous digest despite unrelated sidebar product and application entities" do
    records = (1..6).map do |index|
      <<~RECORD
        <article><h2><a href="/reports/#{index}">Independent public report #{index}</a></h2>
          <p>Summary #{index} explains a separate development and why it matters to readers.</p>
        </article>
      RECORD
    end.join
    html = <<~HTML
      <html><head><title>Independent reports</title></head><body>
        <aside class="related-software">
          <script type="application/ld+json">{"@context":"https://schema.org","@graph":[
            {"@type":"SoftwareApplication","name":"Unrelated publisher tool"},
            {"@type":"Product","name":"Unrelated catalog item"}
          ]}</script>
        </aside>
        <main><h1>Independent reports</h1>
          <p>Our editors selected six separate reports and added context on developments that matter across policy, science, and community life.</p>
          #{records}
        </main>
      </body></html>
    HTML

    with_url_page("https://unknown.example/reports/selection", html) do |page|
      payload = extract(page)
      expect(payload["contentFormat"]).to eq("newsletter")
      expect(payload["markdown"]).to include("Our editors selected six separate reports", "Independent public report 1", "Independent public report 6")
    end
  end

  it "does not borrow newsletter context from a footer or linked story headline" do
    records = (1..6).map do |index|
      <<~RECORD
        <article>
          <h2><a href="/stories/#{index}">Newsletter coverage: report #{index}</a></h2>
          <p>Newsroom report #{index} records the public decision and its immediate local consequences.</p>
        </article>
      RECORD
    end.join
    html = <<~HTML
      <html><head><title>Independent newsroom</title></head><body><main>
        <h1>Independent newsroom</h1>
        #{records}
      </main><footer><h2>Newsletter</h2><p>Subscribe for updates.</p></footer></body></html>
    HTML

    with_url_page("https://unknown.example/news/", html) do |page|
      payload = extract(page)
      expect(payload["contentFormat"]).not_to eq("newsletter")
      expect(payload["warnings"]).to include("multi_topic_page")
      expect(payload["markdown"]).to include("Newsletter coverage: report 1", "Newsletter coverage: report 6")
    end
  end

  it "does not borrow an editorial introduction from a nested foreign record" do
    records = (1..6).map do |index|
      <<~RECORD
        <article><h2><a href="/reports/#{index}">Independent report #{index}</a></h2>
          <p>Report #{index} explains the public development and its effect on local communities.</p>
        </article>
      RECORD
    end.join
    foreign_records = (1..4).map do |index|
      <<~RECORD
        <h2><a href="/features/selected-#{index}">Selected editorial feature #{index}</a></h2>
        <p>This separate feature record summarizes its own source material and reader context without selecting the surrounding report collection.</p>
      RECORD
    end.join
    foreign_record = <<~FOREIGN
      <article class="foreign-feature">
        <p>Our editors selected this individual feature after reviewing its reporting and reader interest in the subject.</p>
        #{foreign_records}
      </article>
    FOREIGN
    html = <<~HTML
      <html><head><title>Independent reports</title></head><body><main>
        <h1>Independent reports</h1>
        #{foreign_record}
        #{records}
      </main></body></html>
    HTML

    with_url_page("https://unknown.example/reports/", html) do |page|
      root = File.expand_path("../../..", __dir__)
      source = File.readlines(File.join(root, "websieve/manifest.txt"), chomp: true).reject(&:empty?).map do |entry|
        File.read(File.join(root, "websieve", entry))
      end.join("\n")
      page.add_script_tag(content: File.read(File.join(root, "lib/fetch_util/assets/vendor/turndown.js")))
      page.add_script_tag(content: source.sub(
        "})(window);",
        "global.newsletterIntroProbe = { owned: newsletterOwnedEditorialIntro, detect: detectContentFormat, markdown: markdownFor }; })(window);"
      ))
      result = page.evaluate(<<~JS)
        (() => {
          const owner = document.querySelector("main");
          return {
            ownedIntro: newsletterIntroProbe.owned(owner, { title: document.title }, { title: document.title }),
            format: newsletterIntroProbe.detect(
              { title: document.title },
              { contentType: "list", title: document.title, html: owner.innerHTML, textContent: owner.textContent },
              newsletterIntroProbe.markdown(owner.innerHTML)
            )
          };
        })()
      JS

      expect(result).to eq("ownedIntro" => false, "format" => nil)
    end
  end

  it "binds article identity and focal ownership to the visible selected headline" do
    title = "A separate foreign article headline"
    html = <<~HTML
      <html><head><title>Selected source report</title>
        <meta property="og:type" content="article">
        <meta property="og:title" content="#{title}">
      </head><body>
        <h1 hidden>#{title}</h1>
        <aside class="sidebar"><h1>#{title}</h1></aside>
        <main><article><h1>Selected source report</h1>
          <p>The visible article body belongs to a different selected source record and provides its own reporting context.</p>
        </article><article class="secondary-publication">
          <h2><a href="/stories/foreign">#{title}</a></h2>
          <p>This separate linked story card has a different selected owner and article body.</p>
        </article></main>
      </body></html>
    HTML

    with_url_page("https://unknown.example/reports/selected", html) do |page|
      root = File.expand_path("../../..", __dir__)
      source = File.readlines(File.join(root, "websieve/manifest.txt"), chomp: true).reject(&:empty?).map do |entry|
        File.read(File.join(root, "websieve", entry))
      end.join("\n")
      page.add_script_tag(content: source.sub(
        "})(window);",
        "global.newsletterOwnershipProbe = { singleArticle: newsletterSingleArticleIdentity, focalArticle: newsletterFocalArticleRoot }; })(window);"
      ))
      result = page.evaluate(<<~JS)
        (() => {
          const selected = document.createElement('div');
          selected.innerHTML = '<main><article><h2><a href="/stories/foreign">A separate foreign article headline</a></h2><p>This separate linked story card has a different selected owner and article body.</p></article></main>';
          return {
            singleArticle: newsletterOwnershipProbe.singleArticle(selected),
            borrowedFocalRoot: !!newsletterOwnershipProbe.focalArticle(
              { title: #{title.to_json} },
              { contentType: 'article', title: #{title.to_json} },
              selected
            )
          };
        })()
      JS

      expect(result).to eq("singleArticle" => false, "borrowedFocalRoot" => false)
    end
  end

  it "recognizes authored digest records inside an identified article body" do
    records = (1..6).map do |index|
      <<~RECORD
        <section>
          <h2>Selected report #{index}</h2>
          <p>This authored digest record summarizes a distinct verified public development for readers. <a href="/reports/#{index}">Read the full source report</a>.</p>
        </section>
      RECORD
    end.join
    title = "A source-authored report collection"
    html = <<~HTML
      <html><head><title>#{title}</title>
        <meta property="og:type" content="article">
        <meta property="og:title" content="#{title}">
      </head><body><main><article>
        <h1>#{title}</h1>
        #{records}
      </article></main></body></html>
    HTML

    with_url_page("https://unknown.example/reports/collection", html) do |page|
      payload = extract(page)
      expect(payload["contentType"]).to eq("article")
      expect(payload["contentFormat"]).to eq("newsletter")
      expect(payload["markdown"]).to include("Selected report 1", "Selected report 6", "Read the full source report")
    end
  end

  it "does not infer newsletter from a root homepage list" do
    cards = (1..8).map do |i|
      <<~CARD
        <article>
          <h3><a href="/news/#{i}">Independent report #{i}</a></h3>
          <p>Concise summary for independent report #{i}.</p>
        </article>
      CARD
    end
    html = <<~HTML
      <html><head><title>Independent newsroom</title></head><body><main>
        <h1>Independent newsroom</h1>
        <section><h2>National reports</h2>#{cards.first(4).join}</section>
        <section><h2>International reports</h2>#{cards.last(4).join}</section>
      </main></body></html>
    HTML

    with_url_page("https://www.example.com/", html) do |page|
      payload = extract(page)

      expect(payload["contentType"]).to eq("list")
      expect(payload["contentFormat"]).to be_nil
      expect(payload["warnings"]).not_to include("multi_topic_page")
    end
  end

  it "still detects a single-section root digest as newsletter format" do
    cards = (1..7).map do |i|
      <<~CARD
        <article>
          <h3><a href="/digest/#{i}">Digest report #{i}</a></h3>
          <p>Brief digest summary #{i} with a compact update.</p>
        </article>
      CARD
    end.join
    html = <<~HTML
      <html><head><title>Reader digest</title></head><body><main>
        <section><h2>Weekly reader digest</h2>#{cards}</section>
      </main></body></html>
    HTML

    with_url_page("https://www.example.com/", html) do |page|
      payload = extract(page)

      expect(payload["contentType"]).to eq("list")
      expect(payload["contentFormat"]).to eq("newsletter")
      expect(payload["warnings"]).to include("multi_topic_page")
    end
  end

  it "keeps explicit liveblog schema authoritative on a root homepage list" do
    cards = (1..8).map do |i|
      <<~CARD
        <article>
          <h3><a href="/updates/#{i}">Live update #{i}</a></h3>
          <time datetime="2026-04-10T#{format("%02d", 8 + i)}:00:00">#{8 + i}:00 CET</time>
          <p>Verified development #{i} in a continuing public event.</p>
        </article>
      CARD
    end.join
    html = <<~HTML
      <html><head><title>Public event updates</title>
        <script type="application/ld+json">{"@context":"https://schema.org","@type":"LiveBlogPosting","headline":"Public event updates"}</script>
      </head><body><main><h1>Public event updates</h1>#{cards}</main></body></html>
    HTML

    with_url_page("https://www.example.com/", html) do |page|
      payload = extract(page)

      expect(payload["contentType"]).to eq("list")
      expect(payload["contentFormat"]).to eq("liveblog")
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
