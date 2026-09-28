# frozen_string_literal: true

RSpec.describe 'Canonical article material coverage' do
  include_context 'extractor integration helpers'

  it 'declines canonical takeover when material narrative and a link follow the body' do
    url = 'https://counter.example/articles/harbor-plan-with-tail'
    html = fixture_contents('spec/fixtures/canonical_article_ownership/closing-material-after-body.html')

    with_url_page(url, html) do |page|
      payload = extract_payload(page)
      markdown = payload.fetch('markdown')

      expect(payload['contentType']).to eq('article')
      expect(payload['title']).to eq('Harbor repair plan')
      expect(payload['publishedTime']).to eq('2026-09-29T08:00:00Z')
      expect(payload['byline']).to eq('Harbor Desk')
      expect(markdown).to include(
        'Municipal engineers published the complete harbor repair plan',
        'Crews will begin structural work on Monday',
        'The harbor authority published the material closing update',
        'complete harbor support review', '/reports/harbor-support-review.pdf'
      )
      body_index = markdown.index('Crews will begin structural work on Monday')
      closing_update_index = markdown.index('The harbor authority published the material closing update')
      expect(body_index).to be < closing_update_index
    end
  end

  it 'retains an owned H2 subtitle between the H1 and body without a header wrapper' do
    url = 'https://counter.example/articles/bridge-notice-with-subtitle'
    html = fixture_contents('spec/fixtures/canonical_article_ownership/subtitle-before-body.html')

    with_url_page(url, html) do |page|
      payload = extract_payload(page)
      markdown = payload.fetch('markdown')

      expect(payload['contentType']).to eq('article')
      expect(payload['title']).to eq('Bridge inspection notice')
      expect(payload['publishedTime']).to eq('2026-09-29T09:00:00Z')
      expect(payload['byline']).to eq('Transit Desk')
      expect(markdown).to include(
        'Bridge inspection notice',
        'Engineers confirm the west bridge remains open',
        'City engineers completed the full bridge inspection'
      )
      title_index = markdown.index('Bridge inspection notice')
      subtitle_index = markdown.index('Engineers confirm the west bridge remains open')
      body_index = markdown.index('City engineers completed the full bridge inspection')
      expect(title_index).to be < subtitle_index
      expect(subtitle_index).to be < body_index
    end
  end

  it 'excludes a semantic menu and independently linked story collection outside the body' do
    url = 'https://counter.example/articles/coastal-repair-report'
    html = <<~HTML
      <html><head>
        <title>Coastal repair report</title>
        <link rel="canonical" href="#{url}">
        <meta property="og:type" content="article">
        <meta property="og:title" content="Coastal repair report">
        <meta property="article:published_time" content="2026-09-29T10:00:00Z">
        <meta name="author" content="Harbor Desk">
      </head><body><main><article class="article-record">
        <header><h1>Coastal repair report</h1></header>
        <div class="article-body">
          <p>Engineers completed the full coastal survey and published a repair schedule for the harbor, including the work sequence, public route, and next inspection date.</p>
        </div>
        <div class="detail-sidemenu-list"><ul>
          <li><a href="/category/coastal">Coastal news</a></li>
          <li><a href="/category/harbor">Harbor reports</a></li>
        </ul></div>
        <div class="latest-stories"><ul>
          <li><a href="/stories/flood-response"><h2>Separate flood response story</h2><p>Emergency teams opened a different support center for residents.</p></a></li>
          <li><a href="/stories/transit-update"><h2>Transit service update</h2><p>Operators published a separate service timetable for commuters.</p></a></li>
          <li><script>window.loadAdvertisement();</script></li>
        </ul></div>
      </article></main></body></html>
    HTML

    with_url_page(url, html) do |page|
      payload = extract_payload(page)
      markdown = payload.fetch('markdown')

      expect(payload['contentType']).to eq('article')
      expect(payload['title']).to eq('Coastal repair report')
      expect(payload['publishedTime']).to eq('2026-09-29T10:00:00Z')
      expect(payload['byline']).to eq('Harbor Desk')
      expect(markdown).to include('Engineers completed the full coastal survey')
      expect(markdown).not_to include('Coastal news', 'Harbor reports', 'Separate flood response story', 'Transit service update')
    end
  end
end
