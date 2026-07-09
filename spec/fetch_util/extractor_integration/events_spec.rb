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

  it 'keeps conference schedule pages as rich list markdown' do
    html = fixture_contents(File.join(__dir__, '../../fixtures/rubyconf_schedule.html'))

    with_url_page('https://rubyconf.org/schedule/', html) do |page|
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

  it 'extracts repeated dated event cards without treating incidental event links as an index' do
    html = <<~HTML
      <html><head><title>Online events</title></head><body><main><h1>Online events</h1>
        <article class="event-card"><h2><a href="/e/ruby">Ruby for teams</a></h2><time datetime="2026-09-12">Sep 12, 2026</time><p class="location">Online</p></article>
        <article class="event-card"><h2><a href="/e/testing">Testing clinic</a></h2><time datetime="2026-09-13">Sep 13, 2026</time><p class="location">Online</p></article>
        <article class="event-card"><h2><a href="/e/security">Security workshop</a></h2><time datetime="2026-09-14">Sep 14, 2026</time><p class="location">Online</p></article>
      </main></body></html>
    HTML

    extract_from_url('https://events.example.test/d/online/events', html) do |payload|
      expect_content_type(payload, 'list')
      expect(payload['markdown']).to include('[Ruby for teams](https://events.example.test/e/ruby)')
      expect(payload['markdown']).to include('[Testing clinic](https://events.example.test/e/testing)')
      expect(payload['markdown']).to include('[Security workshop](https://events.example.test/e/security)')
      expect(payload['markdown']).to include('2026-09-12')
      expect(payload['markdown']).to include('2026-09-13')
      expect(payload['markdown']).to include('2026-09-14')
      expect(payload['markdown']).to include('Online')
      expect(payload['markdown'].index('Ruby for teams')).to be < payload['markdown'].index('Testing clinic')
      expect(payload['markdown'].index('Testing clinic')).to be < payload['markdown'].index('Security workshop')
    end
  end
end
