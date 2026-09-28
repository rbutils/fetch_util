# frozen_string_literal: true

RSpec.describe 'FetchUtil canonical article body ownership' do
  include_context 'extractor integration helpers'

  it 'keeps the unique canonical body and visible media while excluding page chrome' do
    url = 'https://wire.example/news/story-742913'
    html = <<~HTML
      <html><head><title>Regional security agreement | Daily Wire</title>
        <meta property="og:type" content="article">
        <meta property="og:title" content="Regional security agreement | Daily Wire">
        <meta property="og:site_name" content="Daily Wire">
        <meta name="author" content="Sana Reporter">
        <link rel="canonical" href="#{url}">
      </head><body><section class="detail-page">
        <header><h1>Regional security agreement</h1>
          <div class="detail-time">Latest coverage</div><div class="detail-time">National news</div>
          <div class="detail-time">26 September, 2026</div>
        </header>
        <div class="detail-content"><div class="description-area">
          <div class="detail_view_content">
            <p>Officials signed a regional security agreement after the latest meeting in the capital. The public statement explains how the agreement will improve coordination and set out each agency's responsibilities.</p>
            <p>Representatives said the plan will include joint training, a published review schedule and a process for reporting progress to residents throughout the year.</p>
            <figure><img src="/agreement.jpg" alt="Officials signing the regional agreement">
              <figcaption>Officials sign the regional security agreement.</figcaption></figure>
            <figure class="embedRelatedStory"><a href="/reports/coordination-742914">
              <img src="/coordination.jpg" alt="Coordination report cover"><h2>Read the coordination report</h2>
            </a></figure>
            <p style="display:none">This hidden promotional text is not part of the visible report.</p>
          </div>
          <section class="comments"><article role="comment">
            <p>A reader reply adds a useful link to the public meeting record.</p>
            <a href="/minutes/742915">Meeting record</a>
          </article></section>
        </div></div>
        <aside class="latest-news"><a href="/news/other-742916">A separate latest story</a>
          <p>This unrelated recommendation must remain outside the article.</p>
          <form><label>Subscribe to the news list</label><input><button>Subscribe</button></form>
        </aside>
      </section></body></html>
    HTML

    with_url_page(url, html) do |page|
      payload = extract_payload(page)

      expect_content_type(payload, 'article')
      expect(payload['title']).to eq('Regional security agreement')
      expect(payload['publishedTime']).to eq('26 September, 2026')
      expect(payload['byline']).to eq('Sana Reporter')
      expect(payload['markdown']).to include(
        'Officials signed a regional security agreement', '/agreement.jpg',
        'Officials sign the regional security agreement.', 'Read the coordination report',
        '/coordination.jpg', 'A reader reply adds a useful link', '/minutes/742915'
      )
      expect(payload['markdown']).not_to include(
        'This hidden promotional text', 'A separate latest story',
        'unrelated recommendation', 'Subscribe to the news list'
      )
      expect_warnings(payload, exclude: %w[multi_topic_page empty_extraction short_extraction url_content_mismatch])
    end
  end
end
