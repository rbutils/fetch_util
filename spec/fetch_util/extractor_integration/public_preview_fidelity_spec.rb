# frozen_string_literal: true

RSpec.describe 'FetchUtil public preview fidelity' do
  include_context 'extractor integration helpers'

  it 'retains visible article material around the public teaser in source order only for its focal owner' do
    html = <<~HTML
      <html><head><title>Botash agreement suspended | Example News</title>
        <meta property="og:type" content="NewsArticle">
        <link rel="canonical" href="https://publisher.example/story/botash-123456">
        <script type="application/ld+json">
          {"@type":"NewsArticle","headline":"Botash agreement suspended","mainEntityOfPage":"https://publisher.example/story/botash-123456"}
        </script>
      </head>
      <body><main><article>
        <header><h2 itemprop="headline">Botash agreement suspended</h2></header>
        <div class="story-body">
          <p>The editorial desk introduced the public status of the pipeline agreement before the access-limited report.</p>
          <figure><img src="/pipeline-map.jpg" alt="Pipeline map"><figcaption>Map showing the public pipeline route.</figcaption></figure>
          <div class="paywall-short-content">
            <p>The two governments agreed to suspend the gas agreement for fifteen months.</p>
            <p>During that period, only the used capacity of the pipeline will be paid.</p>
          </div>
          <p>Editors added a final public note with <a href="/public-methodology">their source methodology</a> after the teaser.</p>
          <p class="byline-credit">Editorial credit: Regional desk.</p>
          <div class="paywall-content"><p>Full-access paragraph beyond the public preview.</p></div>
          <p hidden>This full-access paragraph is not visible in the captured page.</p>
          <aside><div class="public-preview"><p>Sidebar teaser is not the focal public article preview.</p></div></aside>
          <nav><div class="public-preview"><p>Navigation teaser is not the focal public article preview.</p></div></nav>
          <div class="public-preview" hidden><p>Hidden teaser is not visible in the captured page.</p></div>
        </div>
      </article><aside class="related-stories"><a href="/story/another-123456">Another agreement</a></aside></main></body></html>
    HTML

    with_url_page('https://publisher.example/story/botash-123456', html) do |page|
      payload = extract_payload(page)

      expect_content_type(payload, 'article')
      expect(payload['html']).to include('The two governments agreed')
      expect(payload['markdown']).to include('editorial desk introduced', '/pipeline-map.jpg',
                                             'public pipeline route', 'suspend the gas agreement',
                                             'only the used capacity', '/public-methodology', 'Editorial credit')
      expect(payload['markdown']).not_to include('full-access paragraph', 'Another agreement',
                                                 'Sidebar teaser', 'Navigation teaser', 'Hidden teaser')
      expect(payload['excerpt']).to include('suspend the gas agreement')
      expect_warnings(payload, include: 'paywall_partial_content')
      source_order = ['editorial desk introduced', 'public pipeline route', 'suspend the gas agreement',
                      'only the used capacity', 'final public note', 'Editorial credit']
      positions = source_order.map { |text| payload['markdown'].index(text) }
      expect(positions).to all(be_truthy)
      expect(positions).to eq(positions.sort)
    end
  end
end
