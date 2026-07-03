# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'FetchUtil extractor integration - social platform walls' do
  include_context 'extractor integration helpers'
  include_context 'fixture html helpers'

  it "flags consent interstitial pages as suspect" do
    html = simple_consent_wall_html(
      title: "reddit for rubyists",
      heading: "reddit for rubyists",
      paragraphs: ["Let us know your cookie preferences", "Before you continue to Reddit", "Accept all cookies"]
    )

    with_url_page("https://www.ft.com/", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["suspect"]).to eq(true)
      expect(payload["warnings"]).to include("consent_interstitial")
    end
  end

  it "summarizes Reddit cookie prompts from metadata and flags them" do
    html = simple_consent_wall_html(
      title: "Groundbird Gear out of business? : r/BackpackingDogs",
      heading: "Groundbird Gear out of business? : r/BackpackingDogs",
      paragraphs: [
        "Let us know your cookie preferences",
        "Before you continue to Reddit",
        "Reddit uses cookies and similar technologies to keep the website operational."
      ],
      head: %(<meta name="description" content="Discussion about whether Groundbird Gear is out of business.">)
    )

    with_url_page("https://www.reddit.com/r/BackpackingDogs/comments/17yd040/groundbird_gear_out_of_business", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("# Groundbird Gear out of business?")
      expect(payload["markdown"]).to include("Discussion about whether Groundbird Gear is out of business.")
      expect(payload["markdown"]).not_to include("Let us know your cookie preferences")
      expect(payload["warnings"]).to include("consent_interstitial")
    end
  end

  it "does not force a Reddit login-required summary when the real post is present after consent" do
    html = <<~HTML
      <html>
        <head>
          <title>Groundbird Gear out of business? : r/BackpackingDogs</title>
        </head>
        <body>
          <main>
            <h1>Groundbird Gear out of business?</h1>
            <p>Let us know your cookie preferences</p>
            <shreddit-post></shreddit-post>
            <faceplate-screen-reader-content>
              I was interested in getting a groundbird gear harness and pack system for my dog.
            </faceplate-screen-reader-content>
            <shreddit-comment></shreddit-comment>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.reddit.com/r/BackpackingDogs/comments/17yd040/groundbird_gear_out_of_business", html) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)

      expect(payload["markdown"]).to include("groundbird gear harness")
      expect(payload["markdown"]).not_to include("This Reddit page requires cookie acceptance or login")
    end
  end

  it "extracts reddit threads with comments without relying on readability" do
    html = <<~HTML
      <html>
        <head>
          <title>Ruby thread : r/ruby</title>
        </head>
        <body>
          <main>
            <shreddit-post author="alice" comment-count="2">
              <div slot="credit-bar">Go to ruby r/ruby 4d ago alice</div>
              <h1 slot="title">Ruby thread</h1>
              <div slot="text-body">Here is the original post body.</div>
            </shreddit-post>
            <shreddit-comment author="bob" depth="0" score="12">
              <div slot="commentMeta">bob 3d ago</div>
              <div slot="comment">First top-level comment.</div>
              <shreddit-comment author="nested" depth="1" score="2">
                <div slot="comment">Nested reply should not be promoted as a top-level heading.</div>
              </shreddit-comment>
            </shreddit-comment>
            <shreddit-comment author="carol" depth="0" score="4">
              <div slot="commentMeta">carol 2d ago</div>
              <div slot="comment">Second top-level comment.</div>
            </shreddit-comment>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.reddit.com/r/ruby/comments/123/ruby-thread", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["readerMode"]).to eq(false)
      expect(payload["markdown"]).to include("# Ruby thread")
      expect(payload["markdown"]).to include("Here is the original post body.")
      expect(payload["markdown"]).to include("## Top Comments")
      expect(payload["markdown"]).to include("### bob (12 points)")
      expect(payload["markdown"]).to include("First top-level comment.")
      expect(payload["markdown"]).to include("### carol (4 points)")
      expect(payload["markdown"]).to include("Second top-level comment.")
      expect(payload["markdown"]).not_to include("This Reddit page requires cookie acceptance or login")
    end
  end

  it "summarizes Behance cookie-settings prompts and flags them" do
    html = simple_consent_wall_html(
      title: "Embossage Projects :: Photos, videos, logos, illustrations and branding",
      heading: "Cookie Settings",
      paragraphs: ["Adobe and our partners use cookies to personalize advertising.", "Measure performance", "Personalize advertising"],
      head: %(<meta name="description" content="Discover projects related to embossage on Behance.">)
    ).sub('<h1>Cookie Settings</h1>', '<h2>Cookie Settings</h2>')

    with_url_page("https://www.behance.net/search/projects/embossage", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("# Embossage Projects")
      expect(payload["markdown"]).to include("Discover projects related to embossage on Behance.")
      expect(payload["markdown"]).not_to include("Adobe and our partners use cookies")
      expect(payload["warnings"]).to include("consent_interstitial")
    end
  end

  it "extracts behance search results when project cards are present" do
    html = <<~HTML
      <html>
        <head>
          <title>Embossage Projects :: Photos, videos, logos, illustrations and branding</title>
          <meta name="description" content="Discover projects related to embossage on Behance.">
        </head>
        <body>
          <main>
            <h1>40 Results for "embossage"</h1>
            <article>
              <a href="/gallery/33413299/Atelier-Embossage?tracking_source=search_projects%7Cembossage">Atelier : Embossage</a>
              <p>Jean-Philippe Ogez 44 views</p>
            </article>
            <article>
              <a href="/gallery/12959385/Embossage?tracking_source=search_projects%7Cembossage">Embossage</a>
              <p>marielle Marenati 746 views</p>
            </article>
            <article>
              <a href="/gallery/166395145/Cration-dun-faire-part-de-mariage?tracking_source=search_projects%7Cembossage">Création d'un faire-part de mariage</a>
            </article>
            <article>
              <a href="/gallery/128386867/Chapitre-02-Paragraphe?tracking_source=search_projects%7Cembossage">Chapitre 02 // Paragraphe</a>
            </article>
            <footer>
              <button>Cookie preferences</button>
            </footer>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.behance.net/search/projects/embossage", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["contentType"]).to eq("list")
      expect(payload["markdown"]).to include("- [Atelier : Embossage](https://www.behance.net/gallery/33413299/Atelier-Embossage)")
      expect(payload["markdown"]).to include("- [Chapitre 02 // Paragraphe](https://www.behance.net/gallery/128386867/Chapitre-02-Paragraphe)")
      expect(payload["warnings"]).not_to include("consent_interstitial")
    end
  end

  it "extracts Mastodon public profile bio and posts instead of footer nav" do
    html = <<~HTML
      <html>
        <head>
          <title>Ruby on Rails (@rubyonrails@mastodon.social) - Mastodon</title>
          <meta property="og:site_name" content="Mastodon">
        </head>
        <body>
          <main class="columns-area__panels__main">
            <section class="account__header">
              <div class="display-name"><strong>Ruby on Rails</strong> <span>@rubyonrails@mastodon.social</span></div>
              <div class="account__header__content">Compress the complexity of modern web apps with Rails.</div>
            </section>
            <article class="status status-public">
              <a class="status__display-name" href="/@rubyonrails">Ruby on Rails @rubyonrails@mastodon.social</a>
              <time datetime="2026-07-01T12:00:00Z">2d</time>
              <div class="status__content"><p>Rails 8.1 beta is available with improvements for database-backed apps.</p></div>
            </article>
            <article class="status status-public">
              <a class="status__display-name" href="/@rubyonrails">Ruby on Rails @rubyonrails@mastodon.social</a>
              <div class="status__content"><p>New Active Record examples are published for application developers.</p></div>
            </article>
          </main>
          <footer>
            <a href="/directory">Profiles directory</a>
            <a href="/keyboard-shortcuts">Keyboard shortcuts</a>
            <a href="https://github.com/mastodon/mastodon">View source code</a>
          </footer>
        </body>
      </html>
    HTML

    with_url_page("https://mastodon.social/@RubyOnRails", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["contentType"]).to eq("list")
      expect(payload["markdown"]).to include("# Ruby on Rails")
      expect(payload["markdown"]).to include("- Handle: @RubyOnRails@mastodon.social")
      expect(payload["markdown"]).to include("Compress the complexity of modern web apps")
      expect(payload["markdown"]).to include("Rails 8.1 beta is available")
      expect(payload["markdown"]).to include("New Active Record examples")
      expect(payload["markdown"]).not_to include("Profiles directory")
      expect(payload["markdown"]).not_to include("Keyboard shortcuts")
    end
  end

  it "classifies Mastodon hashtag timelines as social lists" do
    html = <<~HTML
      <html>
        <head>
          <title>#ruby - Mastodon</title>
          <meta property="og:site_name" content="Mastodon">
        </head>
        <body>
          <main class="columns-area__panels__main">
            <h1>#ruby</h1>
            <article class="status status-public">
              <a class="status__display-name" href="/@dev@example.social">Dev @dev@example.social</a>
              <div class="status__content"><p>Ruby pattern matching makes this data transformation easier to read.</p></div>
            </article>
            <article class="status status-public">
              <a class="status__display-name" href="/@ops@example.social">Ops @ops@example.social</a>
              <div class="status__content"><p>Shipping a tiny Rails service today with a smaller dependency graph.</p></div>
            </article>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://mastodon.social/tags/ruby", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["contentType"]).to eq("list")
      expect(payload["markdown"]).to include("# #ruby on Mastodon")
      expect(payload["markdown"]).to include("Ruby pattern matching")
      expect(payload["markdown"]).to include("tiny Rails service")
    end
  end
end
