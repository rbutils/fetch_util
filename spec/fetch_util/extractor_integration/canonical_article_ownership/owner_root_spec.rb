# frozen_string_literal: true

RSpec.describe 'Canonical article ownership boundaries' do
  include_context 'extractor integration helpers'

  it 'declines a narrow body when its owner contains a linked sibling story' do
    url = 'https://counter.example/articles/primary-story'
    html = fixture_contents('spec/fixtures/canonical_article_ownership/narrow_owner_sibling.html')

    with_url_page(url, html) do |page|
      payload = extract_payload(page)
      markdown = payload.fetch('markdown')

      expect(payload['contentType']).to eq('article')
      expect(payload['title']).to eq('Harbor repair plan')
      expect(payload['publishedTime']).to eq('2026-09-28T09:00:00Z')
      expect(payload['byline']).to eq('Harbor Desk')
      expect(markdown).to include(
        'Municipal engineers published the complete plan',
        'Crews will publish progress notices each morning',
        'A separate flood response story',
        'Emergency teams opened a separate flood response center',
        '/articles/other-story'
      )
    end
  end

  it 'does not treat an owned linked comment as a foreign story' do
    url = 'https://counter.example/articles/harbor-comment-record'
    html = <<~HTML
      <html><head>
        <title>Harbor inspection notes</title>
        <link rel="canonical" href="#{url}">
        <meta property="og:type" content="article">
        <meta property="og:title" content="Harbor inspection notes">
      </head><body><main><article class="article-record">
        <h1>Harbor inspection notes</h1>
        <div class="article-body">
          <p>Inspectors published the complete harbor inspection result and explained the repair schedule to residents in the affected neighborhood.</p>
        </div>
        <section class="comments"><article role="comment">
          <h2><a href="/profiles/harbor-reader">Harbor reader</a></h2>
          <p>The harbor office confirmed that residents can use the north entrance while the temporary route remains open.</p>
        </article></section>
      </article></main></body></html>
    HTML

    with_url_page(url, html) do |page|
      payload = extract_payload(page)

      expect(payload['title']).to eq('Harbor inspection notes')
      expect(payload['contentType']).to eq('article')
      expect(payload.fetch('markdown')).to include(
        'complete harbor inspection result', 'Harbor reader',
        'residents can use the north entrance', '/profiles/harbor-reader'
      )
    end
  end

  it 'retains the complete fallback when a broad owner contains a linked sibling' do
    url = 'https://counter.example/articles/primary-story'
    html = fixture_contents('spec/fixtures/canonical_article_ownership/broad_owner_with_sibling.html')

    with_url_page(url, html) do |page|
      payload = extract_payload(page)
      markdown = payload.fetch('markdown')

      expect(payload['title']).to eq('Harbor repair plan')
      expect(markdown).to include(
        'Municipal engineers published the complete plan',
        'A separate flood response story',
        'a separate flood response center',
        'Reader comment: the harbor office confirmed',
        '/articles/other-story'
      )
    end
  end
end
