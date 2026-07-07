# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'FetchUtil extractor integration - content quality noise' do
  include_context 'extractor integration helpers'

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
      payload = extract(page)

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
      payload = extract(page)

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
      payload = extract(page)

      expect(payload["contentType"]).to eq("article")
      expect(payload["warnings"]).to include("short_extraction")
    end
  end

  it "does not flag short_extraction for a compact article with clear article structure" do
    nav_links = 80.times.map { |i| "<a href=\"/story-#{i}\">Section #{i + 1} with extra navigation text</a>" }.join(" | \n")
    html = <<~HTML
      <html>
        <head><title>Brief Local Update</title></head>
        <body>
          <nav>#{nav_links}</nav>
          <main>
            <article>
              <h1>Brief Local Update</h1>
              <p>The council approved the new park plan.</p>
              <p>Work starts next week and finishes before summer.</p>
            </article>
          </main>
          <footer>#{nav_links}</footer>
        </body>
      </html>
    HTML

    with_url_page("https://news.example.com/brief-local-update", html) do |page|
      payload = extract(page)

      expect(payload["contentType"]).to eq("article")
      expect(payload["warnings"]).not_to include("short_extraction")
      expect(payload["warnings"]).not_to include("truncated_content")
    end
  end

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
      payload = extract(page)

      expect(payload["markdown"]).not_to match(/outbrain\.com/i)
      expect(payload["markdown"]).not_to match(/taboola\.com/i)
      # The actual article content should still be present
      expect(payload["markdown"]).to include("technology trends")
    end
  end
end
