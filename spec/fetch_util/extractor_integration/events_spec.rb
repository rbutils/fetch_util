# frozen_string_literal: true

RSpec.describe 'FetchUtil event extraction' do
  include_context 'extractor integration helpers'

  it 'classifies JSON-LD Event pages and uses event dates as published_time' do
    html = fixture_contents(File.join(__dir__, '../../fixtures/event_json_ld.html'))

    with_url_page('https://events.example.test/ruby-ai-summit-2026', html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload['contentType']).to eq('event')
      expect(payload['title']).to eq('Ruby AI Summit 2026')
      expect(payload['publishedTime']).to eq('2026-09-18T09:00:00-04:00 - 2026-09-18T17:30:00-04:00')
      expect(payload['location']).to eq('Harbor Conference Center - 100 Harbor Way, Boston, MA, US')
      expect(payload['description']).to eq(
        'A practical one-day conference for Ruby developers building production AI systems, ' \
        'with talks on evals, observability, deployment, and maintainable agent workflows.'
      )
      expect(payload['markdown']).to include('- Date: 2026-09-18T09:00:00-04:00 - 2026-09-18T17:30:00-04:00')
      expect(payload['markdown']).to include('production AI systems')
      expect(payload['warnings']).to be_empty
    end
  end

  it 'falls back from blank structured descriptions to metadata excerpts' do
    html = <<~HTML
      <html><head>
        <meta name="description" content="A practical community gathering for local Ruby developers.">
        <script type="application/ld+json">{"@context":"https://schema.org","@type":"Event","name":"Ruby Meetup","startDate":"2026-10-10","description":"   "}</script>
      </head><body><main><h1>Ruby Meetup</h1></main></body></html>
    HTML

    extract_from_url('https://events.example.test/ruby-meetup', html) do |payload|
      expect_content_type(payload, 'event')
      expect(payload['description']).to eq('A practical community gathering for local Ruby developers.')
    end
  end

  it 'materializes links in source-authored structured descriptions' do
    html = <<~HTML
      <html><head>
        <script type="application/ld+json">{"@context":"https://schema.org","@type":"Event","name":"Safe event links","startDate":"2026-10-11","description":"A detailed event description with [registration guidance](javascript:openRegistration()) and a [safe attendee guide](/guides/attendee_(final)) for everyone planning a complete visit."}</script>
      </head><body><main><h1>Safe event links</h1></main></body></html>
    HTML

    extract_from_url('https://events.example.test/safe-event-links', html) do |payload|
      expect_content_type(payload, 'event')
      expect(payload['markdown']).to include('registration guidance', '[safe attendee guide](https://events.example.test/guides/attendee_%28final%29)')
      expect(payload['markdown']).not_to include('javascript:', 'openRegistration')
    end
  end

  it 'keeps Eventbrite title, date/time, location, and description without ticket chrome' do
    html = fixture_contents(File.join(__dir__, '../../fixtures/eventbrite_event.html'))

    with_url_page('https://www.eventbrite.com/e/railsconf-community-night-tickets-123456789', html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload['contentType']).to eq('event')
      expect(payload['title']).to eq('Harbor Makers Evening')
      expect(payload['publishedTime']).to eq('2026-08-20T18:00:00-05:00')
      expect(payload['location']).to include('Austin Central Library')
      expect(payload['markdown']).to include('Meet local builders for brief talks')
      expect(payload['markdown']).not_to include('Reserve a spot')
      expect(payload['warnings']).to be_empty
    end
  end

  it 'excludes hidden event descriptions while preserving restored visibility' do
    html = <<~HTML
      <html><head><title>Visible event details</title></head><body>
        <main class="event-detail">
          <h1>Visible community gathering</h1>
          <time datetime="2026-11-08T10:00:00Z">November 8, 2026 at 10:00 AM</time>
          <div class="location">Central Hall</div>
          <section class="description">
            <p>EVENT:Visible description explains the complete gathering agenda and practical visitor information.</p>
            <p style="display:none">EVENT:Display-none description must not appear.</p>
            <div style="visibility:hidden">
              EVENT:Inherited-hidden description must not appear.
              <p style="visibility:visible">EVENT:Restored description remains available to every visitor.</p>
            </div>
          </section>
        </main>
      </body></html>
    HTML

    extract_from_url('https://events.example.test/events/visible-gathering/1234', html) do |payload|
      expect_content_type(payload, 'event')
      expect(payload['markdown']).to include('EVENT:Visible description', 'EVENT:Restored description')
      expect(payload['markdown']).not_to include('EVENT:Display-none description', 'EVENT:Inherited-hidden description')
      expect(payload['html']).not_to include('EVENT:Display-none description', 'EVENT:Inherited-hidden description')
    end
  end

  it 'keeps conference schedule pages as rich list markdown' do
    html = fixture_contents(File.join(__dir__, '../../fixtures/rubyconf_schedule.html'))

    with_url_page('https://rubyconf.org/conferences/rubyconf-2026', html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload['contentType']).to eq('list')
      expect(payload['markdown']).to include('# RubyConf 2026 Schedule')
      expect(payload['markdown']).to include('## Tuesday, November 17')
      expect(payload['markdown']).to include('09:00 AM')
      expect(payload['markdown']).to include('Opening Address: Tools for the Coming Decade')
      expect(payload['markdown']).to include('Quick Checks for Broad Codebases')
      expect(payload['warnings']).to be_empty
    end
  end

  it 'keeps classless semantic conference schedules as lists' do
    html = <<~HTML
      <html><head>
        <title>Community conference program</title>
        <meta name="author" content="Program committee">
      </head><body><main>
        <h1>Community conference program</h1>
        <p>This program introduces a full day of practical sessions, with enough explanatory context to help visitors choose a useful route through the material and plan useful conversations between sessions.</p>
        <p style="display:none">SCHEDULE:Display-none guidance must not appear.</p>
        <div style="visibility:hidden">
          SCHEDULE:Inherited-hidden guidance must not appear.
          <p style="visibility:visible">SCHEDULE:Restored guidance remains available to every attendee.</p>
        </div>
        <article><h2><a href="/sessions/opening">Opening patterns</a></h2><time datetime="2026-09-10T09:00:00Z">09:00 AM</time><p>A practical opening session about choosing simple designs and communicating their constraints clearly.</p></article>
        <article><h2><a href="/sessions/testing">Reliable checks</a></h2><time datetime="2026-09-10T10:30:00Z">10:30 AM</time><p>Focused techniques for dependable changes, useful failures, and maintainable regression coverage.</p></article>
        <article><h2><a href="/sessions/closing">Closing discussion</a></h2><time datetime="2026-09-10T14:00:00Z">02:00 PM</time><p>A final discussion that connects the day's lessons and gives participants time for detailed questions.</p></article>
      </main></body></html>
    HTML

    extract_from_url('https://events.example.test/conferences/program-overview', html) do |payload|
      expect_content_type(payload, 'list')
      expect(payload['markdown']).to include('Opening patterns')
      expect(payload['markdown']).to include('Reliable checks')
      expect(payload['markdown']).to include('Closing discussion')
      expect(payload['markdown']).to include('SCHEDULE:Restored guidance')
      expect(payload['markdown']).not_to include('SCHEDULE:Display-none guidance', 'SCHEDULE:Inherited-hidden guidance')
      expect(payload['html']).not_to include('SCHEDULE:Display-none guidance', 'SCHEDULE:Inherited-hidden guidance')
    end
  end

  it 'extracts repeated dated event cards without treating incidental event links as an index' do
    html = <<~HTML
      <html><head><title>Online events</title></head><body><main><h1>Online events</h1>
        <article><h2><a href="/guides/venues">Venue planning guide</a></h2><p>Advice for selecting an accessible venue.</p></article>
        <article class="event-card"><h2><a href="javascript:openEvent()">Popup session</a></h2><time datetime="2026-09-11">Sep 11, 2026</time><p class="location">Online</p></article>
        <article class="event-card"><h2><a href="/e/ruby">Ruby for teams</a></h2><time datetime="2026-09-12">Sep 12, 2026</time><p class="location">Online</p></article>
        <article class="event-card"><h2><a href="/e/testing">Testing clinic</a></h2><time datetime="2026-09-13">Sep 13, 2026</time><p class="location">Online</p></article>
        <article class="event-card"><h2><a href="/e/security">Security workshop</a></h2><time datetime="2026-09-14">Sep 14, 2026</time><p class="location">Online</p></article>
        <article class="event-card" style="visibility:hidden"><h2 style="visibility:visible"><a href="/e/restored-card">Restored event card</a></h2><time style="visibility:visible" datetime="2026-09-15">Sep 15, 2026</time><p style="visibility:visible" class="location">Online</p></article>
        <article class="event-card"><h2><a style="visibility:hidden" href="/e/restored-link"><span style="visibility:visible">Child-restored event link</span></a></h2><time datetime="2026-09-16">Sep 16, 2026</time><p class="location">Online</p></article>
        <article class="event-card" style="display:none"><h2><a href="/e/hidden">Hidden event card</a></h2><time datetime="2026-09-17">Sep 17, 2026</time></article>
      </main></body></html>
    HTML

    extract_from_url('https://events.example.test/d/online/events', html) do |payload|
      expect_content_type(payload, 'list')
      expect(payload['markdown']).to eq(<<~MARKDOWN.chomp)
        - Popup session - 2026-09-11 - Online
        - [Ruby for teams](https://events.example.test/e/ruby) - 2026-09-12 - Online
        - [Testing clinic](https://events.example.test/e/testing) - 2026-09-13 - Online
        - [Security workshop](https://events.example.test/e/security) - 2026-09-14 - Online
        - [Restored event card](https://events.example.test/e/restored-card) - 2026-09-15 - Online
        - [Child-restored event link](https://events.example.test/e/restored-link) - 2026-09-16 - Online
      MARKDOWN
      expect(payload['html']).to include('Ruby for teams')
      expect(payload['markdown']).not_to include('javascript:', 'Hidden event card')
    end
  end

  it 'preserves recurring events that share one destination' do
    html = <<~HTML
      <html><head><title>Weekly community sessions</title></head><body><main><h1>Weekly community sessions</h1>
        <article class="event-card"><h2><a href="/events/community">Community workshop</a></h2><time datetime="2026-10-01">Oct 1, 2026</time></article>
        <article class="event-card"><h2><a href="/events/community">Community workshop</a></h2><time datetime="2026-10-08">Oct 8, 2026</time></article>
        <article class="event-card"><h2><a href="/events/community">Community workshop</a></h2><time datetime="2026-10-15">Oct 15, 2026</time></article>
        <article class="event-card responsive-copy"><h2><a href="/events/community">Community workshop</a></h2><time datetime="2026-10-01">Oct 1, 2026</time></article>
      </main></body></html>
    HTML

    extract_from_url('https://events.example.test/events', html) do |payload|
      expect_content_type(payload, 'list')
      expect(payload['markdown']).to include('2026-10-01', '2026-10-08', '2026-10-15')
      expect(payload['markdown'].scan('Community workshop').length).to eq(3)
    end
  end

  it 'preserves DOM order across event cards and ticket-link fallbacks' do
    html = <<~HTML
      <html><head><title>Community events</title></head><body><main><h1>Community events</h1>
        <div class="listing-card"><h2><a href="/e/early">Early community event</a></h2><time datetime="2026-10-01">Oct 1, 2026</time></div>
        <article class="event-card"><h2><a href="/events/middle">Middle community event</a></h2><time datetime="2026-10-02">Oct 2, 2026</time></article>
        <article class="event-card"><h2><a href="/events/late">Late community event</a></h2><time datetime="2026-10-03">Oct 3, 2026</time></article>
      </main></body></html>
    HTML

    extract_from_url('https://events.example.test/events', html) do |payload|
      expect_content_type(payload, 'list')
      markdown = payload.fetch('markdown')
      expect(markdown.scan('community event').length).to eq(3)
      expect(markdown.index('Early community event')).to be < markdown.index('Middle community event')
      expect(markdown.index('Middle community event')).to be < markdown.index('Late community event')
    end
  end

  it 'does not replace a substantive article with related event cards' do
    html = <<~HTML
      <html><head>
        <title>Planning an accessible event schedule</title>
        <meta name="author" content="Morgan Lee">
        <meta property="article:published_time" content="2026-08-20">
      </head><body><main>
        <article>
          <h1>Planning an accessible event schedule</h1>
          <p>Successful community events begin with a clear purpose, an accessible venue, and enough lead time for participants to plan their travel.</p>
          <p>Organizers should publish practical arrival details, describe available accommodations, and give attendees a direct way to request additional support.</p>
          <p>A useful schedule balances structured sessions with breaks, preserves transition time, and makes changes easy to find before the event begins.</p>
          <p>Afterward, the team should collect specific feedback, document what worked, and carry those lessons into the next planning cycle.</p>
        </article>
        <section><h2>Related events</h2>
          <article class="event-card"><h3><a href="/events/one">Venue workshop</a></h3><time datetime="2026-09-01T09:00:00Z">Sep 1, 2026 at 09:00 AM</time></article>
          <article class="event-card"><h3><a href="/events/two">Schedule clinic</a></h3><time datetime="2026-09-02T10:00:00Z">Sep 2, 2026 at 10:00 AM</time></article>
          <article class="event-card"><h3><a href="/events/three">Access forum</a></h3><time datetime="2026-09-03T11:00:00Z">Sep 3, 2026 at 11:00 AM</time></article>
          <article class="event-card"><h3><a href="/events/four">Feedback roundtable</a></h3><time datetime="2026-09-04T12:00:00Z">Sep 4, 2026 at 12:00 PM</time></article>
        </section>
      </main></body></html>
    HTML

    extract_from_url('https://events.example.test/guides/event-schedule', html) do |payload|
      expect_content_type(payload, 'article')
      expect(payload['markdown']).to include('Successful community events begin with a clear purpose')
      expect(payload['markdown']).to include('carry those lessons into the next planning cycle')
    end
  end

  it 'does not treat a scheduled event detail page as an explicit event index' do
    html = <<~HTML
      <html><head>
        <title>Annual gathering schedule and access guide</title>
        <meta name="author" content="Morgan Lee">
        <meta property="article:published_time" content="2026-08-21">
      </head><body><main>
        <article>
          <h1>Annual gathering schedule and access guide</h1>
          <p>The annual gathering brings community organizers together for a full day of practical sessions, facilitated discussions, and shared planning.</p>
          <p>This guide explains the event schedule, venue access, quiet spaces, meal arrangements, and the support available throughout the day.</p>
          <p>Attendees should review arrival instructions before traveling and contact the team early when they need a specific accommodation.</p>
          <p>Session updates will be published here so every participant has one reliable source for the current event plan.</p>
        </article>
      </main>
        <section><h2>Related events</h2>
          <article class="event-card"><h3><a href="/events/one">Venue workshop</a></h3><time datetime="2026-09-01">Sep 1, 2026</time></article>
          <article class="event-card"><h3><a href="/events/two">Schedule clinic</a></h3><time datetime="2026-09-02">Sep 2, 2026</time></article>
          <article class="event-card"><h3><a href="/events/three">Access forum</a></h3><time datetime="2026-09-03">Sep 3, 2026</time></article>
        </section>
      </body></html>
    HTML

    extract_from_url('https://events.example.test/events/annual-gathering/1234/', html) do |payload|
      expect_content_type(payload, 'article')
      expect(payload['markdown']).to include('The annual gathering brings community organizers together')
      expect(payload['markdown']).to include('one reliable source for the current event plan')
    end
  end

  it 'does not treat speaker profiles as a conference schedule' do
    html = <<~HTML
      <html><head>
        <title>Conference speaker interviews</title>
        <meta name="author" content="Morgan Lee">
        <meta property="article:published_time" content="2026-08-22">
      </head><body><main>
        <article>
          <h1>Conference speaker interviews</h1>
          <p>Four experienced conference speakers explain how they prepare examples, refine explanations, and adapt technical material for a mixed audience.</p>
          <p>Each interview focuses on the decisions behind a talk rather than presenting an agenda, timetable, or session directory.</p>
          <div class="speaker-profile">Alex shares a method for choosing one useful example.</div>
          <div class="speaker-profile">Blair describes testing explanations with peers.</div>
          <div class="speaker-profile">Casey discusses making diagrams more accessible.</div>
          <div class="speaker-profile">Devon explains how audience questions shape revisions.</div>
          <p>Together, their advice offers a practical guide for anyone developing a clear and maintainable technical presentation.</p>
        </article>
      </main>
        <section><h2>Related events</h2>
          <article class="event-card"><h3><a href="/events/one">Venue workshop</a></h3><time datetime="2026-09-01">Sep 1, 2026</time></article>
          <article class="event-card"><h3><a href="/events/two">Schedule clinic</a></h3><time datetime="2026-09-02">Sep 2, 2026</time></article>
          <article class="event-card"><h3><a href="/events/three">Access forum</a></h3><time datetime="2026-09-03">Sep 3, 2026</time></article>
        </section>
      </body></html>
    HTML

    extract_from_url('https://events.example.test/conferences/speaker-interviews', html) do |payload|
      expect_content_type(payload, 'article')
      expect(payload['markdown']).to include('Four experienced conference speakers explain')
      expect(payload['markdown']).to include('clear and maintainable technical presentation')
    end
  end

  it 'does not treat conference logistics times as a session schedule' do
    html = <<~HTML
      <html><head>
        <title>Conference visitor logistics</title>
        <meta name="author" content="Morgan Lee">
        <meta property="article:published_time" content="2026-08-22">
      </head><body><main>
        <article>
          <h1>Conference visitor logistics</h1>
          <p>Visitors can enter the venue from 08:30 AM, when the registration desk opens and staff begin answering accessibility questions.</p>
          <p>Lunch service starts at 12:30 PM in the atrium, with clearly labelled alternatives available from the same counters.</p>
          <p>The building closes at 06:00 PM, so attendees should collect stored belongings before making their way to evening activities.</p>
          <p>This practical article explains transport, meals, venue access, and support contacts rather than listing individual conference sessions.</p>
        </article>
      </main>
        <section><h2>Related events</h2>
          <article class="event-card"><h3><a href="/events/one">Venue workshop</a></h3><time datetime="2026-09-01">Sep 1, 2026</time></article>
          <article class="event-card"><h3><a href="/events/two">Schedule clinic</a></h3><time datetime="2026-09-02">Sep 2, 2026</time></article>
          <article class="event-card"><h3><a href="/events/three">Access forum</a></h3><time datetime="2026-09-03">Sep 3, 2026</time></article>
        </section>
      </body></html>
    HTML

    extract_from_url('https://events.example.test/conferences/visitor-logistics', html) do |payload|
      expect_content_type(payload, 'article')
      expect(payload['markdown']).to include('Visitors can enter the venue from 08:30 AM')
      expect(payload['markdown']).to include('rather than listing individual conference sessions')
    end
  end
end
