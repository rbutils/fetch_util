# frozen_string_literal: true

RSpec.describe 'FetchUtil extractor integration - portal homepages' do
  include_context 'extractor integration helpers'

  it 'extracts generic marketplace homepages into compact lead-story lists' do
    html = <<~HTML
      <html>
        <head>
          <title>Orbit Marketplace | Find, compare, and book deals</title>
          <meta name="description" content="Find deals, compare sellers, and book your next stay.">
        </head>
        <body>
          <header>
            <nav>
              <a href="/about">About</a>
              <a href="/help">Help</a>
              <a href="/cookies">Cookies</a>
            </nav>
          </header>
          <main>
            <h1>Find and compare the best marketplace deals</h1>
            <h2>Top stories</h2>
            <h2>Featured listings</h2>
            <section class="card">
              <a href="https://orbit.example/listings/a1">Compact electric bikes with delivery this week</a>
              <p>New inventory from local sellers in major cities.</p>
            </section>
            <section class="card">
              <a href="https://orbit.example/listings/a2">Weekend city apartments with flexible check-in</a>
              <p>Popular picks for short stays and longer breaks.</p>
            </section>
            <section class="card">
              <a href="https://orbit.example/listings/a3">Marketplace furniture bundles for small homes</a>
              <p>Compare condition, shipping, and pickup options.</p>
            </section>
            <section class="card">
              <a href="https://orbit.example/listings/a4">Local services for moving and setup help</a>
              <p>Trusted providers with fast quotes.</p>
            </section>
          </main>
          <footer>
            <p>Manage cookies and privacy choices</p>
          </footer>
        </body>
      </html>
    HTML

    with_url_page('https://orbit.example/', html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["contentType"]).to eq("list")
      expect(payload["markdown"]).to include("# Find and compare the best marketplace deals")
      expect(payload["markdown"]).to include("- [Compact electric bikes with delivery this week](https://orbit.example/listings/a1)")
      expect(payload["markdown"]).to include("- [Local services for moving and setup help](https://orbit.example/listings/a4)")
      expect(payload["markdown"]).not_to include("Manage cookies")
      expect(payload["markdown"]).not_to include("privacy choices")
    end
  end

  it 'leaves real article pages on the normal article path' do
    html = <<~HTML
      <html>
        <head>
          <title>City council approves long-delayed riverfront plan</title>
          <meta name="description" content="City council approves long-delayed riverfront plan">
        </head>
        <body>
          <main>
            <article>
              <h1>City council approves long-delayed riverfront plan</h1>
              <p>The city council approved a long-delayed riverfront redevelopment plan after months of hearings and budget revisions.</p>
              <p>The proposal includes new public transit access, flood defenses, and housing commitments for the surrounding district.</p>
              <p>Officials said construction could begin next spring once final permits are issued.</p>
              <p>Residents and local businesses will now review the schedule, zoning map, and mitigation details before the final vote.</p>
            </article>
            <section>
              <h2>RELATED STORIES</h2>
              <a href="/news/other">Other local updates</a>
            </section>
          </main>
        </body>
      </html>
    HTML

    with_url_page('https://news.example.com/news/some-article', html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["contentType"]).to eq("article")
      expect(payload["markdown"]).to include("The city council approved a long-delayed riverfront redevelopment plan")
      expect(payload["markdown"]).to include("construction could begin next spring")
      expect(payload["markdown"]).not_to include("# Find and compare")
    end
  end

  it 'keeps existing financial times homepage compaction working' do
    html = <<~HTML
      <html>
        <head>
          <title>Home - Financial Times</title>
          <meta property="og:site_name" content="Financial Times">
          <meta name="description" content="News, analysis and opinion from the Financial Times.">
        </head>
        <body>
          <main>
            <section class="story-group-slice">
              <a href="https://www.ft.com/content/a1">Iran threatens vital infrastructure in response to ultimatum</a>
              <p>Tehran's military says its strategy has shifted from defensive to offensive.</p>
            </section>
            <section class="story-group-slice">
              <a href="https://www.ft.com/content/a2">World faces gas supply cliff edge as Gulf shipments approach ports</a>
              <p>Energy traders warn of mounting supply risk.</p>
            </section>
            <section class="story-group-slice">
              <a href="https://www.ft.com/content/a3">How the Iran war could derail the AI boom</a>
              <p>Opinion content.</p>
            </section>
            <section class="story-group-slice">
              <a href="https://www.ft.com/content/a4">Global carmakers retreat from electric vehicle plans</a>
              <p>Demand for petrol engines persists.</p>
            </section>
          </main>
        </body>
      </html>
    HTML

    with_url_page('https://www.ft.com/', html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["contentType"]).to eq("list")
      expect(payload["markdown"]).to include("- [Iran threatens vital infrastructure in response to ultimatum](https://www.ft.com/content/a1)")
      expect(payload["markdown"]).to include("- [Global carmakers retreat from electric vehicle plans](https://www.ft.com/content/a4)")
      expect(payload["markdown"]).not_to include("# Find and compare")
    end
  end

  it 'extracts booking-style portal shells into compact lead content' do
    html = <<~HTML
      <html>
        <head>
          <title>Book stays and compare hotels | TripDesk</title>
          <meta name="description" content="Find hotels, destinations, and property deals.">
        </head>
        <body>
          <main>
            <h1>Book your next stay</h1>
            <h2>Popular destinations</h2>
            <h2>Browse by property type</h2>
            <section class="listing">
              <a href="https://tripdesk.example/search?destination=lisbon">Lisbon boutique hotels with flexible cancellation</a>
              <p>Compare city-center stays and nearby apartments.</p>
            </section>
            <section class="listing">
              <a href="https://tripdesk.example/search?destination=tokyo">Tokyo family apartments near transit lines</a>
              <p>Shortlists for longer stays and quick bookings.</p>
            </section>
            <section class="listing">
              <a href="https://tripdesk.example/search?destination=miami">Miami beach properties with pool access</a>
              <p>Search rates across neighborhoods and seasons.</p>
            </section>
            <section class="listing">
              <a href="https://tripdesk.example/search?destination=rome">Rome rooms close to historic landmarks</a>
              <p>Compare properties, reviews, and check-in options.</p>
            </section>
          </main>
          <footer>
            <p>Cookie settings and privacy preferences</p>
          </footer>
        </body>
      </html>
    HTML

    with_url_page('https://tripdesk.example/', html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["contentType"]).to eq("list")
      expect(payload["markdown"]).to include("# Book your next stay")
      expect(payload["markdown"]).to include("- [Lisbon boutique hotels with flexible cancellation](https://tripdesk.example/search?destination=lisbon)")
      expect(payload["markdown"]).to include("- [Rome rooms close to historic landmarks](https://tripdesk.example/search?destination=rome)")
      expect(payload["markdown"]).not_to include("Cookie settings")
      expect(payload["markdown"]).not_to include("privacy preferences")
    end
  end

  it 'does not flag accessible portal homepages as paywall partial content' do
    html = <<~HTML
      <html>
        <head><title>Daily Portal</title></head>
        <body>
          <main>
            <h1>Daily Portal</h1>
            <section class="lead-card">
              <a href="https://portal.example/news/a">Morning briefing with transport, weather, and market updates</a>
              <p>Editors collect the main public updates for readers.</p>
            </section>
            <section class="lead-card">
              <a href="https://portal.example/news/b">Schools publish holiday timetable and exam guidance</a>
              <p>Important dates and links for families.</p>
            </section>
            <section class="paywall-promo">
              <a href="https://portal.example/subscribe">Support independent reporting</a>
              <p>Subscription offers appear in the homepage chrome, but the public story list remains accessible.</p>
            </section>
            <section class="lead-card">
              <a href="https://portal.example/news/c">Council approves new public library opening hours</a>
              <p>Branches will extend weekend access next month.</p>
            </section>
          </main>
        </body>
      </html>
    HTML

    with_url_page('https://portal.example/', html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("Morning briefing with transport")
      expect(payload["warnings"]).not_to include("paywall_partial_content")
    end
  end
end
