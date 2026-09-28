# frozen_string_literal: true

RSpec.describe 'FetchUtil liveblog source-link retention' do
  include_context 'extractor integration helpers'

  def update_record(id:, title:, link:, image:, report:)
    <<~HTML
      <article class="live-update" id="update-#{id}">
        <time datetime="2026-09-27T10:00:00Z">September 27, 2026 10:00</time>
        <h2><a rel="bookmark" href="#{link}">#{title}</a></h2>
        <div class="update-content">
          <p>Officials published the complete #{title.downcase} report and explained the inspection schedule for residents.</p>
          <figure>
            <a class="permalink" href="#{image.sub(/\.jpg\z/, "-large.jpg")}">
              <img src="#{image}" alt="#{title} site photograph">
            </a>
            <figcaption>Photograph documenting #{title.downcase} at the work site.</figcaption>
          </figure>
          <p>Read the <a rel="canonical" href="#{report}">full source report</a> for details.</p>
          <div class="share-controls">
            <a class="share-button" href="https://social.example/share?text=update">Share this update</a>
            <div class="share_icon">
              <a class="btn-share--facebook" href="https://social.example/share?text=icon"><img src="https://wire.example/icons/share.svg"></a>
            </div>
          </div>
        </div>
      </article>
    HTML
  end

  def parent_page(records)
    canonical = 'https://wire.example/live/dispatch'
    <<~HTML
      <html><head>
        <title>Regional response live updates</title>
        <meta property="og:title" content="Regional response live updates">
        <link rel="canonical" href="#{canonical}">
      </head><body><main class="liveblog-page">
        <h1>Regional response live updates</h1>
        <section class="live-updates">#{records.join}</section>
      </main></body></html>
    HTML
  end

  it 'retains authored heading, linked hero, caption and report links in a full parent' do
    current = 'https://wire.example/live/dispatch'
    records = [
      update_record(id: 'first', title: 'Initial response', link: '#update-first', image: '/media/first.jpg', report: '/reports/first'),
      update_record(id: 'second', title: 'Bridge inspection complete', link: '#update-second', image: '/media/second.jpg', report: '/reports/second')
    ]

    with_url_page(current, parent_page(records)) do |page|
      payload = extract_payload(page)
      markdown = payload.fetch('markdown')

      expect(payload['title']).to eq('Regional response live updates')
      expect(payload['contentFormat']).to eq('liveblog')
      expect(markdown).to include(
        '[Initial response](https://wire.example/live/dispatch#update-first)',
        'https://wire.example/media/first-large.jpg', 'https://wire.example/media/first.jpg',
        'Photograph documenting initial response at the work site.',
        '[full source report](https://wire.example/reports/first)',
        '[Bridge inspection complete](https://wire.example/live/dispatch#update-second)',
        '[full source report](https://wire.example/reports/second)'
      )
      expect(markdown).not_to include('Share this update', 'icons/share.svg')
      expect(payload['html']).not_to include('icons/share.svg')
    end
  end

  it 'retains linked material when a relative permalink addresses an update' do
    current = 'https://wire.example/live/dispatch?update=second'
    records = [
      update_record(id: 'first', title: 'Initial response', link: '#update-first', image: '/media/first.jpg', report: '/reports/first'),
      update_record(id: 'second', title: 'Bridge inspection complete', link: '?update=second', image: '/media/second.jpg', report: '/reports/second')
    ]

    with_url_page(current, parent_page(records)) do |page|
      payload = extract_payload(page)
      markdown = payload.fetch('markdown')

      expect(payload['title']).to eq('Bridge inspection complete')
      expect(payload['contentFormat']).to eq('liveblog')
      expect(markdown).to include(
        '[Bridge inspection complete](https://wire.example/live/dispatch?update=second)',
        'https://wire.example/media/second-large.jpg', 'https://wire.example/media/second.jpg',
        'Photograph documenting bridge inspection complete at the work site.',
        '[full source report](https://wire.example/reports/second)'
      )
      expect(markdown).not_to include('Initial response', 'Share this update', 'icons/share.svg')
      expect(payload['html']).not_to include('icons/share.svg')
    end
  end

  it 'does not infer a record URL from a bare query slug or counter' do
    {
      'https://wire.example/live/second' => %w[text second],
      'https://wire.example/live/742913' => %w[item 742913]
    }.each do |current, (key, value)|
      records = [
        update_record(id: 'first', title: 'Initial response', link: '#update-first', image: '/media/first.jpg', report: '/reports/first'),
        update_record(
          id: 'second', title: 'Bridge inspection complete', link: "https://social.example/share?#{key}=#{value}",
          image: '/media/second.jpg', report: '/reports/second'
        )
      ]

      with_url_page(current, parent_page(records)) do |page|
        payload = extract_payload(page)

        expect(payload['title']).to eq('Regional response live updates')
        expect(payload['contentFormat']).to eq('liveblog')
        expect(payload['markdown']).to include('Initial response', 'Bridge inspection complete')
      end
    end
  end
end
