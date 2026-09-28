# frozen_string_literal: true

RSpec.describe 'FetchUtil liveblog parent DOM metadata ownership' do
  include_context 'extractor integration helpers'

  def update_record(id:, title:, time:, metadata: '')
    <<~HTML
      <article class="live-update" id="#{id}">
        <time datetime="#{time}" itemprop="datePublished">#{time}</time>
        <h2>#{title}</h2>
        <meta itemprop="datePublished" content="#{time}">
        <meta itemprop="author" content="Update Reporter #{id}">
        <div class="update-content">
          <p>Officials published the complete #{title.downcase} report and explained the inspection schedule.</p>
        </div>
        #{metadata}
      </article>
    HTML
  end

  def parent_page(current, records, header:, before_main: '')
    <<~HTML
      <html><head>
        <title>Regional response live updates</title>
        <meta property="og:title" content="Regional response live updates">
        <link rel="canonical" href="#{current}">
      </head><body>
        #{before_main}
        <main class="liveblog-page">
          #{header}
          <section class="live-updates">#{records.join}</section>
        </main>
      </body></html>
    HTML
  end

  it 'uses only metadata in the parent header, excluding earlier footer and comment metadata' do
    current = 'https://wire.example/live/dispatch'
    records = [
      update_record(id: 'first', title: 'Initial response', time: '2026-09-27T09:00:00Z'),
      update_record(id: 'second', title: 'Bridge inspection complete', time: '2026-09-27T10:00:00Z')
    ]
    header = <<~HTML
      <header class="liveblog-header">
        <h1>Regional response live updates</h1>
        <time datetime="2026-09-26T08:15:00Z" itemprop="datePublished">September 26, 2026</time>
        <span itemprop="author">Parent News Desk</span>
      </header>
    HTML
    foreign_metadata = <<~HTML
      <footer><time datetime="2026-09-25T07:00:00Z" itemprop="datePublished">Footer date</time>
        <a rel="author" href="/authors/footer">Footer Reporter</a></footer>
      <section class="comments"><time datetime="2026-09-24T06:00:00Z" itemprop="datePublished">Comment date</time>
        <span itemprop="author">Commenter</span></section>
    HTML

    with_url_page(current, parent_page(current, records, header: header, before_main: foreign_metadata)) do |page|
      payload = extract_payload(page)

      expect(payload['publishedTime']).to eq('2026-09-26T08:15:00Z')
      expect(payload['byline']).to eq('Parent News Desk')
      expect(payload['contentFormat']).to eq('liveblog')
      expect(payload['markdown']).to include('Initial response', 'Bridge inspection complete')
    end
  end

  it 'does not borrow child microdata or footer/comment author and date values as parent metadata' do
    current = 'https://wire.example/live/dispatch'
    records = [
      update_record(id: 'first', title: 'Initial response', time: '2026-09-27T09:00:00Z'),
      update_record(id: 'second', title: 'Bridge inspection complete', time: '2026-09-27T10:00:00Z')
    ]
    header = '<header class="liveblog-header"><h1>Regional response live updates</h1></header>'
    foreign_metadata = <<~HTML
      <footer><time datetime="2026-09-25T07:00:00Z">Footer date</time>
        <a rel="author" href="/authors/footer">Footer Reporter</a></footer>
      <section class="comments"><time datetime="2026-09-24T06:00:00Z">Comment date</time>
        <span itemprop="author">Commenter</span></section>
    HTML

    with_url_page(current, parent_page(current, records, header: header, before_main: foreign_metadata)) do |page|
      payload = extract_payload(page)

      expect(payload['publishedTime']).to be_nil
      expect(payload['byline']).to be_nil
      expect(payload['contentFormat']).to eq('liveblog')
      expect(payload['markdown']).to include('Initial response', 'Bridge inspection complete')
    end
  end

  it 'does not treat a header inside a record as parent metadata ownership' do
    current = 'https://wire.example/live/dispatch'
    header = <<~HTML
      <header class="liveblog-header">
        <h1>Regional response live updates</h1>
        <time datetime="2026-09-26T08:15:00Z">Child wrapper date</time>
        <span itemprop="author">Child wrapper author</span>
      </header>
    HTML
    records = [
      update_record(id: 'first', title: 'Initial response', time: '2026-09-27T09:00:00Z', metadata: header),
      update_record(id: 'second', title: 'Bridge inspection complete', time: '2026-09-27T10:00:00Z')
    ]
    html = parent_page(current, records, header: '')

    with_url_page(current, html) do |page|
      payload = extract_payload(page)

      expect(payload['publishedTime']).to be_nil
      expect(payload['byline']).to be_nil
      expect(payload['contentFormat']).to eq('liveblog')
    end
  end
end
