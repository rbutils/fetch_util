RSpec.describe 'FetchUtil liveblog parent metadata ownership' do
  include_context 'extractor integration helpers'

  def reduced_yle_fixture
    fixture_contents(File.expand_path('../../fixtures/yle_live_article.html', __dir__))
  end

  it 'keeps the full original reduced liveblog fixture without borrowing a child date or byline' do
    current = 'https://wire.example/live/reduced-yle-fixture'

    with_url_page(current, reduced_yle_fixture) do |page|
      payload = extract_payload(page)

      expect_content_type(payload, 'article')
      expect(payload['contentFormat']).to eq('liveblog')
      expect(payload['title']).to eq('Stubb: ”Meidän on tuettava Ukrainaa”')
      expect(payload['publishedTime']).to be_nil
      expect(payload['byline']).to be_nil
      expect(payload['markdown']).to include(
        'Yle seuraa tiistaina alkavaa Nato-kokousta',
        'Trump on saapunut Ankaraan',
        'Rutte: Naton ja EU:n tiivistettävä yhteistyötä'
      )
    end
  end

  it 'keeps the full parent when the requested update identifier is unknown' do
    current = 'https://wire.example/live/dispatch?update=missing'
    records = [
      '<article class="live-update" id="first"><time datetime="2026-09-27T09:00:00Z">09:00</time>' \
        '<h2>First update</h2><p>Officials published the complete inspection result and explained the repair schedule to residents.</p>' \
        '<a class="permalink" href="https://wire.example/live/dispatch?update=first">First update permalink</a></article>',
      '<article class="live-update" id="second"><time datetime="2026-09-27T10:00:00Z">10:00</time>' \
        '<h2>Second update</h2><p>Officials confirmed the bridge remains closed while engineers complete the second inspection.</p>' \
        '<a class="permalink" href="https://wire.example/live/dispatch?update=second">Second update permalink</a></article>'
    ].join
    html = <<~HTML
      <html><head><title>Bridge inspection live updates</title>
        <meta property="og:title" content="Bridge inspection live updates">
        <link rel="canonical" href="https://wire.example/live/dispatch">
        <script type="application/ld+json">{"@type":"LiveBlogPosting","headline":"Bridge inspection live updates"}</script>
      </head><body><main class="liveblog-page"><h1>Bridge inspection live updates</h1>
        <section class="live-updates">#{records}</section></main></body></html>
    HTML

    with_url_page(current, html) do |page|
      payload = extract_payload(page)

      expect_content_type(payload, 'article')
      expect(payload['contentFormat']).to eq('liveblog')
      expect(payload['publishedTime']).to be_nil
      expect(payload['markdown']).to include('First update', 'Second update')
    end
  end
end
