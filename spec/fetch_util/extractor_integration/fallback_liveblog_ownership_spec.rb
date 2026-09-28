# frozen_string_literal: true

require 'cgi'

RSpec.describe 'FetchUtil generic liveblog ownership' do
  include_context 'extractor integration helpers'

  def liveblog_record(id:, title:, time:, body:, footer: '')
    <<~HTML
      <article class="live-update" id="#{id}">
        <time datetime="#{time}">#{time}</time>
        <h2>#{title}</h2>
        <p class="byline">Reporter #{id}</p>
        <div class="update-content">
          <p>#{body}</p>
          <figure><img src="/#{id}.jpg" alt="#{title}"><figcaption>Caption for #{title}.</figcaption></figure>
          <p>Read the <a href="/reports/#{id}">source report</a> for the complete update.</p>
        </div>
        #{footer}
      </article>
    HTML
  end

  def liveblog_page(canonical:, records:, extra: '')
    <<~HTML
      <html><head>
        <title>Regional response live updates</title>
        <meta property="og:title" content="Regional response live updates">
        <link rel="canonical" href="#{canonical}">
      </head><body><main class="liveblog-page">
        <h1>Regional response live updates</h1>
        <section class="live-updates">#{records}</section>
        #{extra}
      </main></body></html>
    HTML
  end

  def update_body(label)
    [
      "Officials published the #{label} response after a new inspection.",
      'The update includes a complete schedule, confirms who is responsible for each action,',
      'and explains how residents can check the next public notice.'
    ].join(' ')
  end

  it 'isolates the one update with a visible share URL that identifies the requested record' do
    current = 'https://wire.example/live/dispatch?update=second'
    share = "<a class='share-button' href='https://share.example/post?url=#{CGI.escape(current)}'>Share</a>"
    records = [
      liveblog_record(id: 'update-first', title: 'Initial response', time: '2026-09-27T09:00:00Z', body: update_body('initial')),
      liveblog_record(id: 'update-second', title: 'Bridge inspection complete', time: '2026-09-27T10:30:00Z', body: update_body('bridge inspection'), footer: share)
    ].join

    with_url_page(current, liveblog_page(canonical: 'https://wire.example/live/dispatch', records: records)) do |page|
      payload = extract_payload(page)

      expect_content_type(payload, 'article')
      expect(payload['contentFormat']).to eq('liveblog')
      expect(payload['title']).to eq('Bridge inspection complete')
      expect(payload['publishedTime']).to include('2026-09-27T10:30:00Z')
      expect(payload['byline']).to include('Reporter update-second')
      expect(payload['markdown']).to include('complete schedule', '/update-second.jpg', 'Caption for Bridge inspection complete.', '/reports/update-second')
      expect(payload['markdown']).not_to include('Initial response', 'initial response after a new inspection')
      expect_warnings(payload, exclude: %w[multi_topic_page empty_extraction short_extraction url_content_mismatch])
    end
  end

  it 'keeps the full parent when its URL matches despite a body citation and related/comment links' do
    current = 'https://wire.example/live/dispatch'
    citation = "<p>Background <a href='#{current}'>parent coverage</a> contains reference material.</p>"
    records = [
      liveblog_record(id: 'update-first', title: 'Initial response', time: '2026-09-27T09:00:00Z', body: update_body('initial'), footer: citation),
      liveblog_record(id: 'update-second', title: 'Bridge inspection complete', time: '2026-09-27T10:30:00Z', body: update_body('bridge inspection'))
    ].join
    extra = [
      "<aside class='related-stories'><a class='permalink' href='#{current}'>Related parent link</a></aside>",
      "<section class='comments'><p>A reader reply remains part of the liveblog.</p><a class='permalink' href='#{current}'>Comment reference</a></section>"
    ].join

    with_url_page(current, liveblog_page(canonical: current, records: records, extra: extra)) do |page|
      payload = extract_payload(page)

      expect(payload['title']).to eq('Regional response live updates')
      expect(payload['contentType']).to eq('article')
      expect(payload['contentFormat']).to eq('liveblog')
      expect(payload['publishedTime']).to be_nil
      expect(payload['byline']).to be_nil
      expect(payload['markdown']).to include(
        'Initial response', 'Bridge inspection complete', 'parent coverage',
        'A reader reply remains part of the liveblog.', 'Comment reference'
      )
      expect(payload['markdown']).not_to include('Related parent link')
    end
  end

  it 'uses parent-owned structured publication time and authors instead of an update byline' do
    current = 'https://wire.example/live/dispatch'
    records = [
      liveblog_record(id: 'update-first', title: 'Initial response', time: '2026-09-27T09:00:00Z', body: update_body('initial')),
      liveblog_record(id: 'update-second', title: 'Bridge inspection complete', time: '2026-09-27T10:30:00Z', body: update_body('bridge inspection'))
    ].join
    parent = <<~JSON.strip
      <script type="application/ld+json">
        {"@graph":[{"@type":"LiveBlogPosting","url":"#{current}","mainEntityOfPage":{"@type":"WebPage","@id":"#{current}"},"headline":"Regional response live updates","datePublished":"2026-09-26T08:15:00Z","author":[{"@type":"Person","name":"News Desk"},{"@type":"Person","name":"Alex Rivera"}]},{"@type":"WebPage","@id":"#{current}"}]}
      </script>
    JSON
    html = liveblog_page(canonical: current, records: records).sub('</head>', "#{parent}</head>")

    with_url_page(current, html) do |page|
      payload = extract_payload(page)

      expect(payload['publishedTime']).to eq('2026-09-26T08:15:00Z')
      expect(payload['byline']).to eq('News Desk, Alex Rivera')
      expect(payload['contentFormat']).to eq('liveblog')
    end
  end

  it 'uses a matching structured parent title when the only visible H1 is an update headline' do
    current = 'https://wire.example/live/dispatch/updates-742913'
    records = [
      liveblog_record(id: 'update-first', title: 'Bridge inspection complete', time: '2026-09-27T09:00:00Z', body: update_body('bridge inspection')),
      liveblog_record(id: 'update-second', title: 'Transit detour begins', time: '2026-09-27T10:30:00Z', body: update_body('transit detour'))
    ].join
    title = 'Regional response live updates'
    html = liveblog_page(canonical: current, records: records)
    html = html.sub("<title>#{title}</title>", "<title>#{title} | Daily Wire</title>")
    parent_metadata = <<~META.strip
      <meta property="og:title" content="#{title} | Daily Wire">
      <meta property="og:site_name" content="Daily Wire">
      <script type="application/ld+json">
        {"@type":"LiveBlogPosting","url":"#{current}","headline":"#{title}"}
      </script>
    META
    html = html.sub('<meta property="og:title" content="Regional response live updates">', parent_metadata)
    html = html.sub('<h1>Regional response live updates</h1>', '<h1>Bridge inspection complete</h1>')

    with_url_page(current, html) do |page|
      payload = extract_payload(page)

      expect_content_type(payload, 'article')
      expect(payload['title']).to eq('Regional response live updates')
      expect(payload['contentFormat']).to eq('liveblog')
      expect(payload['markdown']).to include('Bridge inspection complete', 'Transit detour begins')
    end
  end

  it 'keeps the full parent when the only matching permalink is hidden' do
    current = 'https://wire.example/live/dispatch?update=second'
    hidden = "<a class='permalink' href='#{current}' hidden>Hidden update permalink</a>"
    records = [
      liveblog_record(id: 'update-first', title: 'Initial response', time: '2026-09-27T09:00:00Z', body: update_body('initial')),
      liveblog_record(id: 'update-second', title: 'Bridge inspection complete', time: '2026-09-27T10:30:00Z', body: update_body('bridge inspection'), footer: hidden)
    ].join

    with_url_page(current, liveblog_page(canonical: 'https://wire.example/live/dispatch', records: records)) do |page|
      payload = extract_payload(page)

      expect(payload['title']).to eq('Regional response live updates')
      expect(payload['markdown']).to include('Initial response', 'Bridge inspection complete')
      expect(payload['markdown']).not_to include('Hidden update permalink')
    end
  end

  it 'keeps the full parent when a visible share URL is claimed by two records' do
    current = 'https://wire.example/live/dispatch?update=shared'
    permalink = "<a class='permalink' href='#{current}'>Update link</a>"
    records = [
      liveblog_record(id: 'update-first', title: 'Initial response', time: '2026-09-27T09:00:00Z', body: update_body('initial'), footer: permalink),
      liveblog_record(id: 'update-second', title: 'Bridge inspection complete', time: '2026-09-27T10:30:00Z', body: update_body('bridge inspection'), footer: permalink)
    ].join

    with_url_page(current, liveblog_page(canonical: 'https://wire.example/live/dispatch', records: records)) do |page|
      payload = extract_payload(page)

      expect(payload['title']).to eq('Regional response live updates')
      expect(payload['markdown']).to include('Initial response', 'Bridge inspection complete')
    end
  end

  it 'rejects credential-bearing update links and does not infer identity from a TOC fragment' do
    current = 'https://wire.example/live/dispatch#update-second'
    credential_link = "<a class='permalink' href='https://user:secret@wire.example/live/dispatch#update-second'>Credential link</a>"
    records = [
      liveblog_record(id: 'update-first', title: 'Initial response', time: '2026-09-27T09:00:00Z', body: update_body('initial'), footer: credential_link),
      liveblog_record(id: 'update-second', title: 'Bridge inspection complete', time: '2026-09-27T10:30:00Z', body: update_body('bridge inspection'))
    ].join
    toc = "<nav><a href='#update-second'>Bridge inspection complete</a></nav>"

    with_url_page(current, liveblog_page(canonical: 'https://wire.example/live/dispatch', records: records, extra: toc)) do |page|
      payload = extract_payload(page)

      expect(payload['title']).to eq('Regional response live updates')
      expect(payload['markdown']).to include('Initial response', 'Bridge inspection complete')
      expect(payload['markdown']).to include('Credential link')
      expect(payload['markdown']).not_to include('user:secret')
      expect(payload['html']).to include('Credential link')
      expect(payload['html']).not_to include('user:secret')
    end
  end

  it 'keeps the parent when a relative share query merely matches the request URL' do
    current = 'https://wire.example/live/dispatch?text=second'
    share = "<div class='share-controls'><a class='share-button' href='?text=second'>Share</a></div>"
    records = [
      liveblog_record(id: 'update-first', title: 'Initial response', time: '2026-09-27T09:00:00Z', body: update_body('initial')),
      liveblog_record(id: 'update-second', title: 'Bridge inspection complete', time: '2026-09-27T10:30:00Z', body: update_body('bridge inspection'), footer: share)
    ].join

    with_url_page(current, liveblog_page(canonical: 'https://wire.example/live/dispatch', records: records)) do |page|
      payload = extract_payload(page)

      expect(payload['title']).to eq('Regional response live updates')
      expect(payload['contentFormat']).to eq('liveblog')
      expect(payload['markdown']).to include(
        'Initial response', 'initial response after a new inspection',
        'Bridge inspection complete', 'bridge inspection response after a new inspection'
      )
    end
  end

  it 'uses a visible unique bookmark fragment but not an unowned table-of-contents fragment' do
    current = 'https://wire.example/live/dispatch#update-second'
    bookmark = "<a rel='bookmark' href='#update-second'>Permalink</a>"
    records = [
      liveblog_record(id: 'update-first', title: 'Initial response', time: '2026-09-27T09:00:00Z', body: update_body('initial')),
      liveblog_record(id: 'update-second', title: 'Bridge inspection complete', time: '2026-09-27T10:30:00Z', body: update_body('bridge inspection'), footer: bookmark)
    ].join
    html = liveblog_page(canonical: 'https://wire.example/live/dispatch', records: records)

    with_url_page(current, html) do |page|
      payload = extract_payload(page)
      expect(payload['title']).to eq('Bridge inspection complete')
      expect(payload['markdown']).to include('bridge inspection response', '/update-second.jpg')
      expect(payload['markdown']).not_to include('Initial response')
    end
  end

  it 'uses an exact structured update URL without inferring a query token' do
    current = 'https://wire.example/live/dispatch?update=second'
    records = [
      liveblog_record(id: 'update-first', title: 'Initial response', time: '2026-09-27T09:00:00Z', body: update_body('initial')),
      liveblog_record(id: 'update-second', title: 'Bridge inspection complete', time: '2026-09-27T10:30:00Z', body: update_body('bridge inspection'))
    ].join
    records = records.sub('<article class="live-update" id="update-second">',
                          "<article class='live-update' id='update-second' itemprop='liveBlogUpdate' itemid='#{current}'>")

    with_url_page(current, liveblog_page(canonical: 'https://wire.example/live/dispatch', records: records)) do |page|
      payload = extract_payload(page)

      expect(payload['title']).to eq('Bridge inspection complete')
      expect(payload['markdown']).to include('bridge inspection response', '/update-second.jpg')
      expect(payload['markdown']).not_to include('Initial response')
    end
  end

  it 'deduplicates nested page and article roots when they own the same liveblog records' do
    current = 'https://wire.example/live/dispatch'
    records = [
      liveblog_record(id: 'update-first', title: 'Initial response', time: '2026-09-27T09:00:00Z', body: update_body('initial')),
      liveblog_record(id: 'update-second', title: 'Bridge inspection complete', time: '2026-09-27T10:30:00Z', body: update_body('bridge inspection'))
    ].join
    parent = <<~JSON.strip
      <script type="application/ld+json">
        {"@type":"LiveBlogPosting","url":"#{current}","headline":"Regional response live updates","datePublished":"2026-09-26T08:15:00Z","author":{"@type":"Person","name":"News Desk"}}
      </script>
    JSON
    html = <<~HTML
      <html><head><title>Regional response live updates</title>
        <meta property="og:title" content="Regional response live updates">
        <link rel="canonical" href="#{current}">
        #{parent}
      </head><body><main id="page-main"><article class="liveblog-wrapper">
        <h1>Regional response live updates</h1><section class="live-updates">#{records}</section>
      </article></main></body></html>
    HTML

    with_url_page(current, html) do |page|
      payload = extract_payload(page)

      expect(payload['title']).to eq('Regional response live updates')
      expect(payload['publishedTime']).to eq('2026-09-26T08:15:00Z')
      expect(payload['byline']).to eq('News Desk')
      expect(payload['contentFormat']).to eq('liveblog')
      expect(payload['markdown']).to include('Initial response', 'Bridge inspection complete')
    end
  end

  it 'does not treat an ordinary dated article with a self-share link as a liveblog' do
    current = 'https://wire.example/articles/inspection-report'
    html = <<~HTML
      <html><head><title>Inspection report</title>
        <meta property="og:type" content="article">
        <meta property="og:title" content="Inspection report">
        <link rel="canonical" href="#{current}">
      </head><body><main><article class="article-content">
        <h1>Inspection report</h1><time datetime="2026-09-27">September 27, 2026</time>
        <p>Inspectors published the complete bridge report after reviewing the damaged support. The report describes the repair schedule, the public transit changes, and the next inspection planned for the following week.</p>
        <a class="share-button" href="#{current}">Share this report</a>
      </article></main></body></html>
    HTML

    with_url_page(current, html) do |page|
      payload = extract_payload(page)

      expect_content_type(payload, 'article')
      expect(payload['title']).to eq('Inspection report')
      expect(payload['contentFormat']).not_to eq('liveblog')
      expect(payload['markdown']).to include('complete bridge report', 'repair schedule')
    end
  end
end
