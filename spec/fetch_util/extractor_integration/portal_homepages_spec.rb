# frozen_string_literal: true

RSpec.describe 'FetchUtil extractor integration - portal homepages' do
  include_context 'extractor integration helpers'

  def fetch_result_for_homepage(url, html, payload_overrides: {})
    with_url_page(url, html) do |page|
      payload = FetchUtil::Extractor.new.extract(page).merge(payload_overrides)
      browser = instance_double(FetchUtil::Browser)
      extractor = instance_double(FetchUtil::Extractor)
      raw_docs_fallback = instance_double(FetchUtil::RawDocsFallback, fetch: nil)

      allow(browser).to receive(:with_page).with(url).and_yield(instance_double('FerrumPage', current_url: url))
      allow(extractor).to receive(:extract).and_return(payload)

      FetchUtil::Fetcher.new(browser: browser, extractor: extractor, raw_docs_fallback: raw_docs_fallback).fetch(url)
    end
  end

  def expect_structural_portal(url, html, sections:, cards:)
    with_url_page(url, html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)
      markdown = payload.fetch('markdown')

      expect(payload['contentType']).to eq('list')
      expect(payload['hostAware']).to eq(false)
      expect(payload.dig('portalRootEvidence', 'namedSectionCount')).to be >= 2
      expect(payload.dig('portalRootEvidence', 'canonicalCardCount')).to eq(cards.length)
      sections.each { |section| expect(markdown).to include("## #{section}") }
      cards.each do |title, url, context|
        expect(markdown).to include("[#{title}](#{url})")
        expect(markdown).to include(context)
      end
      cards.each_cons(2) { |first, second| expect(markdown.index(first.first)).to be < markdown.index(second.first) }
      expect(markdown.scan(cards.first[1]).length).to eq(1)
    end
  end

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

  it 'materializes portal evidence when the first shared extractor already returns a list' do
    html = fixture_contents(File.expand_path('../../fixtures/already_list_portal_root.html', __dir__))

    with_url_page('https://regional.example.test/', html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)
      markdown = payload.fetch('markdown')

      expect(payload['contentType']).to eq('list')
      expect(payload['portalRootEvidence']).to eq('namedSectionCount' => 2, 'canonicalCardCount' => 4)
      expect(markdown).to include('## International', '## Science')
      expect(markdown).to include('[Delegates publish a new cross-border transport plan](https://regional.example.test/international/first)')
      expect(markdown).to include('Officials outlined funding and the next review.')
      expect(markdown).to include('[New observatory shares its first public images](https://regional.example.test/science/second)')
      expect(markdown.index('Delegates publish')).to be < markdown.index('Coastal communities')
      expect(markdown.index('Coastal communities')).to be < markdown.index('Researchers map')
      expect(markdown.index('Researchers map')).to be < markdown.index('New observatory')
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

  it 'deduplicates generic portal cards while retaining DOM order' do
    html = <<~HTML
      <html>
        <head>
          <title>Daily Portal latest headlines</title>
          <meta name="description" content="Latest headlines and public updates from the daily portal.">
        </head>
        <body>
          <main>
            <h1>Latest headlines</h1>
            <section class="card"><a href="/news/first?utm_source=rail">First public headline with an extensive daily update</a><p>First detail.</p></section>
            <section class="card"><a href="/news/second">Second public headline with an extensive daily update</a><p>Second detail.</p></section>
            <section class="card"><a href="/news/first?utm_medium=rail">First public headline with an extensive daily update</a><p>Duplicate detail.</p></section>
            <section class="card"><a href="/news/third">Third public headline with an extensive daily update</a><p>Third detail.</p></section>
            <section class="card"><a href="/news/fourth">Fourth public headline with an extensive daily update</a><p>Fourth detail.</p></section>
          </main>
        </body>
      </html>
    HTML

    with_url_page('https://portal.example/', html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      markdown = payload['markdown']
      expect(markdown.scan('First public headline').length).to eq(1)
      expect(markdown.index('First public headline')).to be < markdown.index('Second public headline')
      expect(markdown.index('Second public headline')).to be < markdown.index('Third public headline')
      expect(markdown).to include('Fourth public headline')
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
              <p>Shipping teams report a narrow arrival window.</p>
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
              <p>Useful dates and links for local families.</p>
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

  it 'does not flag scientific database homepages as homepage index pages' do
    html = <<~HTML
      <html>
        <head>
          <title>Welcome to ProteomicsDB</title>
          <meta property="og:site_name" content="Proteomics Database">
        </head>
        <body>
          <main>
            <h1>Welcome to ProteomicsDB</h1>
            <p>ProteomicsDB is a multi-omics and multi-organism database resource for life science research. It covers proteomics, transcriptomics, and phenomics data for human, mouse, arabidopsis, and rice. The scientific resource supports protein-centric interrogation, drug-centric interrogation, analytics workflows, downloadable evidence tables, and curated repository metadata for researchers comparing experiments across organisms and tissues.</p>
            <p>The database homepage explains the scope of the resource, the available visualization modules, the status of public datasets, and the research workflows supported by the platform rather than presenting a general news index or unrelated latest headlines.</p>
            <ul>
              <li>Status</li>
              <li>Protein-centric interrogation</li>
              <li>Drug-centric interrogation</li>
              <li>Analytics section</li>
            </ul>
          </main>
        </body>
      </html>
    HTML

    database_markdown = <<~MARKDOWN
      # Welcome to ProteomicsDB

      ProteomicsDB is a multi-omics and multi-organism database resource for life science research. It covers proteomics, transcriptomics, and phenomics data for human, mouse, arabidopsis, and rice. The scientific resource supports protein-centric interrogation, drug-centric interrogation, analytics workflows, downloadable evidence tables, and curated repository metadata for researchers comparing experiments across organisms and tissues.

      - Status
      - Protein-centric interrogation
      - Drug-centric interrogation
      - Analytics section
    MARKDOWN

    result = fetch_result_for_homepage(
      'https://researchdb.example.org/', html,
      payload_overrides: { 'contentType' => 'list', 'markdown' => database_markdown }
    )

    expect(result.content_type).to eq('list')
    expect(result.warnings).not_to include('homepage_index_page')
  end

  it 'still flags generic news homepages as homepage index pages' do
    html = <<~HTML
      <html>
        <head><title>Daily News</title></head>
        <body>
          <main>
            <h1>Daily News</h1>
            <h2>Top stories</h2>
            <ul>
              <li><a href="https://news.example.org/a">Breaking news from city hall after overnight talks</a></li>
              <li><a href="https://news.example.org/b">Latest news on markets, sports, and weather</a></li>
              <li><a href="https://news.example.org/c">Headlines from around the country this morning</a></li>
              <li><a href="https://news.example.org/d">World updates and election analysis from reporters</a></li>
            </ul>
          </main>
        </body>
      </html>
    HTML

    result = fetch_result_for_homepage('https://news.example.org/', html, payload_overrides: { 'contentType' => 'list' })

    expect(result.content_type).to eq('list')
    expect(result.warnings).to include('homepage_index_page')
  end

  it 'arbitrates BBC sections through the shared card path' do
    html = <<~HTML
      <main><h1>BBC News</h1><section><h2>Top Stories</h2>
      <article><a href="/news/one"><h3>BBC first report from the morning desk</h3></a><p>BBC first context.</p></article>
      <article><a href="/news/two"><h3>BBC second report from the evening desk</h3></a><p>BBC second context.</p></article>
      </section><section><h2>World</h2>
      <article><a href="/news/three"><h3>BBC third report from international desk</h3></a><p>BBC third context.</p></article>
      <article><a href="/news/four"><h3>BBC fourth report from climate desk</h3></a><p>BBC fourth context.</p></article>
      </section></main>
    HTML
    expect_structural_portal(
      'https://www.bbc.com/', html, sections: ['Top Stories', 'World'],
                                    cards: [
                                      ['BBC first report from the morning desk', 'https://www.bbc.com/news/one', 'BBC first context.'],
                                      ['BBC second report from the evening desk', 'https://www.bbc.com/news/two', 'BBC second context.'],
                                      ['BBC third report from international desk', 'https://www.bbc.com/news/three', 'BBC third context.'],
                                      ['BBC fourth report from climate desk', 'https://www.bbc.com/news/four', 'BBC fourth context.']
                                    ]
    )
  end

  it 'arbitrates France24 regional cards without relying on a root path' do
    html = <<~HTML
      <main><h1>France 24</h1><div role="region"><h2>Latest News</h2><ul>
      <li><a href="/en/a"><h3>France24 first regional bulletin arrives</h3></a><p>France24 first context.</p></li>
      <li><a href="/en/b"><h3>France24 second regional bulletin arrives</h3></a><p>France24 second context.</p></li>
      </ul></div><div role="region"><h2>Europe</h2><ul>
      <li><a href="/en/c"><h3>France24 third regional bulletin arrives</h3></a><p>France24 third context.</p></li>
      <li><a href="/en/d"><h3>France24 fourth regional bulletin arrives</h3></a><p>France24 fourth context.</p></li>
      </ul></div></main>
    HTML
    expect_structural_portal(
      'https://www.france24.com/en/', html, sections: ['Latest News', 'Europe'],
                                            cards: [
                                              ['France24 first regional bulletin arrives', 'https://www.france24.com/en/a', 'France24 first context.'],
                                              ['France24 second regional bulletin arrives', 'https://www.france24.com/en/b', 'France24 second context.'],
                                              ['France24 third regional bulletin arrives', 'https://www.france24.com/en/c', 'France24 third context.'],
                                              ['France24 fourth regional bulletin arrives', 'https://www.france24.com/en/d', 'France24 fourth context.']
                                            ]
    )
  end

  it 'arbitrates Guardian cards in canonical DOM order and deduplicates tracking URLs' do
    html = <<~HTML
      <main><h1>The Guardian</h1><section><h2>Headlines</h2>
      <div class="dcr-card"><a href="/world/one?utm_source=home"><h3>Guardian first reporting from the capital</h3></a><p>Guardian first context.</p></div>
      <div class="dcr-card"><a href="/world/two"><h3>Guardian second reporting from the capital</h3></a><p>Guardian second context.</p></div>
      </section><section><h2>Opinion</h2>
      <div class="dcr-card"><a href="/world/one"><h3>Guardian duplicate reporting from the capital</h3></a><p>Duplicate context.</p></div>
      <div class="dcr-card"><a href="/world/three"><h3>Guardian third reporting from the capital</h3></a><p>Guardian third context.</p></div>
      <div class="dcr-card"><a href="/world/four"><h3>Guardian fourth reporting from the capital</h3></a><p>Guardian fourth context.</p></div>
      </section></main>
    HTML
    expect_structural_portal(
      'https://www.theguardian.com/international',
      html,
      sections: %w[Headlines Opinion],
      cards: [
        [
          'Guardian first reporting from the capital',
          'https://www.theguardian.com/world/one',
          'Guardian first context.'
        ],
        [
          'Guardian second reporting from the capital',
          'https://www.theguardian.com/world/two',
          'Guardian second context.'
        ],
        [
          'Guardian third reporting from the capital',
          'https://www.theguardian.com/world/three',
          'Guardian third context.'
        ],
        [
          'Guardian fourth reporting from the capital',
          'https://www.theguardian.com/world/four',
          'Guardian fourth context.'
        ]
      ]
    )
  end

  it 'arbitrates Ynet legacy home sections using named main children' do
    html = <<~HTML
      <main><h1>Ynet</h1><div><h2>חדשות</h2>
      <article><a href="/news/a"><h3>Ynet first headline with complete context</h3></a><p>Ynet first context.</p></article>
      <article><a href="/news/b"><h3>Ynet second headline with complete context</h3></a><p>Ynet second context.</p></article>
      </div><div><h2>כלכלה</h2>
      <article><a href="/news/c"><h3>Ynet third headline with complete context</h3></a><p>Ynet third context.</p></article>
      <article><a href="/news/d"><h3>Ynet fourth headline with complete context</h3></a><p>Ynet fourth context.</p></article>
      </div></main>
    HTML
    expect_structural_portal(
      'https://www.ynet.co.il/home/0,7340,L-8,00.html', html, sections: %w[חדשות כלכלה],
                                                              cards: [
                                                                ['Ynet first headline with complete context', 'https://www.ynet.co.il/news/a', 'Ynet first context.'],
                                                                ['Ynet second headline with complete context', 'https://www.ynet.co.il/news/b', 'Ynet second context.'],
                                                                ['Ynet third headline with complete context', 'https://www.ynet.co.il/news/c', 'Ynet third context.'],
                                                                ['Ynet fourth headline with complete context', 'https://www.ynet.co.il/news/d', 'Ynet fourth context.']
                                                              ]
    )
  end

  it 'arbitrates Eventbrite event cards while preserving time context' do
    html = <<~HTML
      <main><h1>Online events</h1><section><h2>Popular online events</h2>
      <article class="event-card"><a href="/e/a"><h3>Eventbrite first online community event</h3></a><time datetime="2026-07-12">July 12</time><p>Eventbrite first context.</p></article>
      <article class="event-card"><a href="/e/b"><h3>Eventbrite second online community event</h3></a><time datetime="2026-07-13">July 13</time><p>Eventbrite second context.</p></article>
      </section><section><h2>Classes</h2>
      <article class="event-card"><a href="/e/c"><h3>Eventbrite third online community event</h3></a><time datetime="2026-07-14">July 14</time><p>Eventbrite third context.</p></article>
      <article class="event-card"><a href="/e/d"><h3>Eventbrite fourth online community event</h3></a><time datetime="2026-07-15">July 15</time><p>Eventbrite fourth context.</p></article>
      </section></main>
    HTML
    expect_structural_portal(
      'https://www.eventbrite.com/d/online/online-events/', html,
      sections: ['Popular online events', 'Classes'],
      cards: [
        ['Eventbrite first online community event', 'https://www.eventbrite.com/e/a', '2026-07-12'],
        ['Eventbrite second online community event', 'https://www.eventbrite.com/e/b', '2026-07-13'],
        ['Eventbrite third online community event', 'https://www.eventbrite.com/e/c', '2026-07-14'],
        ['Eventbrite fourth online community event', 'https://www.eventbrite.com/e/d', '2026-07-15']
      ]
    )
  end

  it 'arbitrates DW portal sections without claiming host-aware provenance' do
    html = <<~HTML
      <main><h1>DW</h1><section><h2>Germany</h2>
      <article><a href="/en/a"><h3>DW first newsroom briefing for readers</h3></a><p>DW first context.</p></article>
      <article><a href="/en/b"><h3>DW second newsroom briefing for readers</h3></a><p>DW second context.</p></article>
      </section><section><h2>Culture</h2>
      <article><a href="/en/c"><h3>DW third newsroom briefing for readers</h3></a><p>DW third context.</p></article>
      <article><a href="/en/d"><h3>DW fourth newsroom briefing for readers</h3></a><p>DW fourth context.</p></article>
      </section></main>
    HTML
    expect_structural_portal(
      'https://www.dw.com/en/', html, sections: %w[Germany Culture],
                                      cards: [
                                        ['DW first newsroom briefing for readers', 'https://www.dw.com/en/a', 'DW first context.'],
                                        ['DW second newsroom briefing for readers', 'https://www.dw.com/en/b', 'DW second context.'],
                                        ['DW third newsroom briefing for readers', 'https://www.dw.com/en/c', 'DW third context.'],
                                        ['DW fourth newsroom briefing for readers', 'https://www.dw.com/en/d', 'DW fourth context.']
                                      ]
    )
  end

  it 'keeps a DW detail article with inline links on the article path' do
    html = <<~HTML
      <html><head><title>Spain wildfire kills several amid heat wave</title></head><body>
        <main><article>
          <h1>Spain wildfire kills several amid heat wave</h1>
          <p class="byline">By DW staff · 10 July 2026</p>
          <p>The wildfire spread across several provinces as crews worked through difficult conditions.</p>
          <p>Officials described the response and warned residents to follow evacuation instructions.</p>
          <p>Related coverage: <a href="/en/climate/a-1">Climate report</a>, <a href="/en/europe/a-2">Europe briefing</a>, <a href="/en/world/a-3">World updates</a>.</p>
        </article></main>
      </body></html>
    HTML

    with_url_page('https://www.dw.com/en/spain-wildfire-kills-several-amid-heat-wave/a-77898335', html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload['contentType']).to eq('article')
      expect(payload['markdown']).to include('The wildfire spread across several provinces')
      expect(payload['hostAware']).to eq(false)
      expect(payload['portalRootEvidence']).to be_nil
    end
  end

  it 'does not certify a weak root that lacks enough canonical cards' do
    html = <<~HTML
      <main><h1>Small portal</h1><section><h2>Latest</h2>
      <article><a href="/one"><h3>First small portal report for readers</h3></a><p>First context.</p></article>
      </section><section><h2>More</h2>
      <article><a href="/two"><h3>Second small portal report for readers</h3></a><p>Second context.</p></article>
      <article><a href="/three"><h3>Third small portal report for readers</h3></a><p>Third context.</p></article>
      </section></main>
    HTML

    with_url_page('https://weak.example/', html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload['portalRootEvidence']).to be_nil
    end
  end

  it 'does not replace a liveblog article with a structural portal list' do
    html = <<~HTML
      <main><article><h1>Live: city council vote and reactions</h1><p class="byline">By Live Desk</p>
      <section><h2>Live updates</h2><article><a href="/update/one"><h3>First live update from the council chamber</h3></a><p>Update context.</p></article>
      <article><a href="/update/two"><h3>Second live update from the council chamber</h3></a><p>Update context.</p></article></section>
      <section><h2>Related coverage</h2><article><a href="/related/one"><h3>First related report from city hall</h3></a><p>Related context.</p></article>
      <article><a href="/related/two"><h3>Second related report from city hall</h3></a><p>Related context.</p></article></section></article></main>
    HTML

    with_url_page('https://news.example/2026/07/10/live-city-council', html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload['contentType']).to eq('article')
      expect(payload['portalRootEvidence']).to be_nil
    end
  end

  it 'does not certify challenge pages as portal roots' do
    html = <<~HTML
      <main><h1>Just a moment...</h1><section><h2>Checking your browser</h2>
      <p>Please enable JavaScript and cookies to continue.</p></section>
      <section><h2>Security check</h2><p>Confirming that the visitor is human before continuing.</p></section></main>
    HTML

    with_url_page('https://challenge.example/', html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload['contentType']).to eq('interstitial')
      expect(payload['portalRootEvidence']).to be_nil
    end
  end
end
