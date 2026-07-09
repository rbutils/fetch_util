# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'FetchUtil extractor integration - social platform walls' do
  include_context 'extractor integration helpers'
  include_context 'fixture html helpers'

  it "flags consent interstitial pages as suspect" do
    html = simple_consent_wall_html(
      title: "forum for sample builders",
      heading: "forum for sample builders",
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
      title: "Is Cedar Outfitters changing plans? : r/BackpackingDogs",
      heading: "Is Cedar Outfitters changing plans? : r/BackpackingDogs",
      paragraphs: [
        "Let us know your cookie preferences",
        "Before you continue to Reddit",
        "This forum uses cookies and similar tools to keep the page operational."
      ],
      head: %(<meta name="description" content="Discussion about whether Cedar Outfitters is changing plans.">)
    )

    with_url_page("https://www.reddit.com/r/BackpackingDogs/comments/17yd040/groundbird_gear_out_of_business", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("# Is Cedar Outfitters changing plans?")
      expect(payload["markdown"]).to include("Discussion about whether Cedar Outfitters is changing plans.")
      expect(payload["markdown"]).not_to include("Let us know your cookie preferences")
      expect(payload["warnings"]).to include("consent_interstitial")
    end
  end

  it "does not force a Reddit login-required summary when the real post is present after consent" do
    html = <<~HTML
      <html>
        <head>
          <title>Is Cedar Outfitters changing plans? : r/BackpackingDogs</title>
        </head>
        <body>
          <main>
             <h1>Is Cedar Outfitters changing plans?</h1>
            <p>Let us know your cookie preferences</p>
            <shreddit-post></shreddit-post>
            <faceplate-screen-reader-content>
               I was interested in finding a cedar trail harness and pack system for my dog.
            </faceplate-screen-reader-content>
            <shreddit-comment></shreddit-comment>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.reddit.com/r/BackpackingDogs/comments/17yd040/groundbird_gear_out_of_business", html) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)

      expect(payload["markdown"]).to include("cedar trail harness")
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
            <section class="_comp_account_header__barWrapper">
              <div class="_comp_account_header__name"><h1><bdi><span>Ruby on Rails</span></bdi></h1></div>
              <button class="_comp_account_header__handleHelpButton">@rubyonrails@mastodon.social</button>
              <div class="_comp_account_bio__bio">Compress the complexity of modern web apps with Rails.</div>
            </section>
            <article class="status__wrapper status-public">
              <a class="status__display-name" href="/@rubyonrails">Ruby on Rails @rubyonrails@mastodon.social</a>
              <time datetime="2026-07-01T12:00:00Z">2d</time>
              <div class="status__content status__content--with-action">
                <div class="status__content__text"><p>Rails 8.1 beta is available with improvements for database-backed apps.</p></div>
              </div>
            </article>
            <article class="status__wrapper status-public">
              <a class="status__display-name" href="/@rubyonrails">Ruby on Rails @rubyonrails@mastodon.social</a>
              <div class="status__content status__content--with-action">
                <div class="status__content__text"><p>New Active Record examples are published for application developers.</p></div>
              </div>
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

      expect(payload).to include("contentType" => "social", "socialKind" => "profile", "platform" => "Mastodon", "handle" => "@RubyOnRails@mastodon.social")
      expect(payload["markdown"]).to include("# Ruby on Rails")
      expect(payload["markdown"]).to include("- Handle: @RubyOnRails@mastodon.social")
      expect(payload["markdown"]).to include("Compress the complexity of modern web apps")
      expect(payload["markdown"]).to include("Rails 8.1 beta is available")
      expect(payload["markdown"]).to include("New Active Record examples")
      expect(payload["markdown"]).not_to include("Profiles directory")
      expect(payload["markdown"]).not_to include("Keyboard shortcuts")
    end
  end

  it 'classifies a DOM-backed Mastodon explore timeline as a social feed without dropping statuses' do
    html = fixture_contents('spec/fixtures/mastodon_explore_timeline.html')

    with_url_page('https://mastodon.social/explore', html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload).to include('contentType' => 'social', 'socialKind' => 'feed', 'platform' => 'Mastodon')
      expect(payload['markdown']).to include('Mastodon Explore', 'Explore status 01', 'Explore status 20')
      expect(payload['markdown']).to include('quoted post', '#fediverse', 'a sunset over the city')
      expect(payload['markdown'].index('Explore status 01')).to be < payload['markdown'].index('Explore status 20')
    end
  end

  it 'retains visible Mastodon profile HTML while cleaning hidden, reblog, and action chrome' do
    html = fixture_contents('spec/fixtures/mastodon_profile_cleanup.html')

    with_url_page('https://mastodon.social/@Mastodon', html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload).to include('contentType' => 'social', 'socialKind' => 'profile', 'platform' => 'Mastodon')
      expect(payload['markdown']).to include('Synthetic status body', '#mastodon', 'synthetic media description', 'Another synthetic status remains')
      expect(payload['markdown']).not_to include('Hidden status text', 'Boosted by', 'Reply Boost Favourite')
      expect(payload['html']).to include(
        'Mastodon</h1>', '@Mastodon@mastodon.social', 'Synthetic profile bio for the cleanup fixture.', 'Website',
        'joinmastodon.org', 'Location', 'Federated Web', 'Synthetic profile bio for the cleanup fixture.'
      )
      expect(payload['html']).to include(
        'Synthetic status body', '#mastodon', 'synthetic media description', 'Another synthetic status remains',
        '<time datetime="2026-07-10T12:00:00Z">1h</time>'
      )
      expect(payload['html']).not_to include('aria-hidden', 'status__action-bar', 'status__prepend')
      expect(payload['html']).not_to include('Hidden status text', 'Boosted by', 'Reply Boost Favourite')
    end
  end

  it 'gives Reddit challenge shells precedence over otherwise feed-like markup' do
    html = fixture_contents('spec/fixtures/reddit_challenge_shell.html')

    with_url_page('https://www.reddit.com/r/programming/?js_challenge=1&solution=token', html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload['contentType']).to eq('interstitial')
      expect(payload['markdown']).to include('Challenge: Reddit access verification')
      expect(payload['contentType']).not_to eq('social')
    end
  end

  it 'preserves every visible Mastodon profile field beyond the former cap' do
    html = fixture_contents('spec/fixtures/mastodon_profile_over_cap.html')

    with_url_page('https://mastodon.example/@ada', html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload).to include('contentType' => 'social', 'socialKind' => 'profile', 'platform' => 'Mastodon')
      expect(payload['markdown']).to match(/Followers.*101.*Account age 6 years/m)
    end
  end

  it "extracts Mastodon single posts as articles with replies" do
    html = <<~HTML
      <html>
        <head>
          <title>Mastodon (@Mastodon@mastodon.social) - Mastodon</title>
          <meta property="og:site_name" content="Mastodon">
          <meta property="og:title" content="Mastodon on Mastodon">
        </head>
        <body>
          <main class="columns-area__panels__main">
            <article class="status__wrapper status-public">
              <a class="status__display-name" href="/@Mastodon">Mastodon @Mastodon@mastodon.social</a>
              <time datetime="2026-07-08T10:00:00Z">Jul 8</time>
              <div class="status__content status__content--with-action">
                <div class="status__content__text">
                  <p>We are rolling out a new stable Mastodon release with better moderation tooling and timeline controls.</p>
                </div>
              </div>
            </article>
            <article class="status__wrapper status-public">
              <a class="status__display-name" href="/@admin@example.social">Admin @admin@example.social</a>
              <time datetime="2026-07-08T10:05:00Z">5m</time>
              <div class="status__content status__content--with-action">
                <div class="status__content__text">
                  <p>Thanks for the update. The reply controls are visible on our instance.</p>
                </div>
              </div>
            </article>
          </main>
          <footer>
            <a href="/directory">Profiles directory</a>
            <a href="/keyboard-shortcuts">Keyboard shortcuts</a>
          </footer>
        </body>
      </html>
    HTML

    with_url_page("https://mastodon.social/@Mastodon/116765910384325070", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload).to include("contentType" => "social", "socialKind" => "thread", "platform" => "Mastodon",
                                 "handle" => "@Mastodon@mastodon.social", "replyCount" => 1)
      expect(payload["markdown"]).to include("# Mastodon on Mastodon")
      expect(payload["markdown"]).to include("- Author: Mastodon @Mastodon@mastodon.social")
      expect(payload["markdown"]).to include("new stable Mastodon release")
      expect(payload["markdown"]).to include("## Replies")
      expect(payload["markdown"]).to include("Thanks for the update")
      expect(payload["markdown"]).not_to include("Profiles directory")
      expect(payload["markdown"]).not_to include("Recent Posts")
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

      expect(payload).to include("contentType" => "social", "socialKind" => "feed", "platform" => "Mastodon", "community" => "#ruby")
      expect(payload["markdown"]).to include("# #ruby on Mastodon")
      expect(payload["markdown"]).to include("Ruby pattern matching")
      expect(payload["markdown"]).to include("tiny Rails service")
    end
  end

  it "classifies Mastodon single statuses without rendered replies as social posts" do
    html = <<~HTML
      <html><head><title>Example (@example@mastodon.social) - Mastodon</title><meta property="og:site_name" content="Mastodon"></head><body><main class="columns-area__panels__main"><article class="status__wrapper status-public"><a class="status__display-name" href="/@example">Example @example@mastodon.social</a><div class="status__content"><p>This public status has enough visible text to be retained without any rendered replies.</p></div></article></main></body></html>
    HTML

    with_url_page("https://mastodon.social/@example/116765910384325071", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload).to include("contentType" => "social", "socialKind" => "post", "platform" => "Mastodon", "handle" => "@example@mastodon.social", "replyCount" => nil)
      expect(payload["markdown"]).to include("This public status has enough visible text")
    end
  end

  it "classifies Mastodon-family detailed statuses without Mastodon metadata" do
    html = fixture_contents(File.expand_path("../../fixtures/mastodon_detailed_status.html", __dir__))

    with_url_page("https://todon.nl/@burnoutqueen/116892639909737254", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload).to include("contentType" => "social", "socialKind" => "post", "platform" => "Mastodon",
                                 "handle" => "@burnoutqueen@todon.nl", "replyCount" => nil)
      expect(payload["markdown"]).to include("The solution of the many body problem")
      expect(payload["markdown"]).not_to include("Boost")
    end
  end

  it "does not classify ActivityPub-looking pages without Mastodon evidence" do
    html = <<~HTML
      <html><head><title>Example social status</title><meta property="og:site_name" content="ActivityPub"></head><body><main><div class="detailed-status__wrapper"><div class="detailed-status"><a class="detailed-status__display-name" href="/@example">Example</a><div class="status__content"><p>This ActivityPub-compatible site uses status-like markup but lacks Mastodon-family evidence.</p></div></div></div></main></body></html>
    HTML

    with_url_page("https://social.example/@example/123456", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["contentType"]).not_to eq("social")
      expect(payload.values_at("socialKind", "platform", "handle", "replyCount", "community", "score")).to all(be_nil)
    end
  end
end
