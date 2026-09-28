# frozen_string_literal: true

RSpec.describe 'FetchUtil liveblog title scope' do
  include_context 'extractor integration helpers'

  let(:parent_url) { 'https://wire.example/live/dispatch' }
  let(:parent_title) { 'Regional response live updates' }
  let(:update_title) { 'Bridge inspection complete' }

  def title_scope_page(heading:, headline:, description:)
    entity = {
      '@type' => 'LiveBlogPosting', 'url' => parent_url,
      'headline' => headline, 'description' => description,
      'datePublished' => '2026-09-26T08:15:00Z',
      'author' => { '@type' => 'Person', 'name' => 'News Desk' }
    }
    <<~HTML
      <html><head>
        <title>#{headline} | Daily Wire</title>
        <meta property="og:title" content="#{headline}">
        <meta property="og:site_name" content="Daily Wire">
        <link rel="canonical" href="#{parent_url}">
        <script type="application/ld+json">#{JSON.generate(entity)}</script>
      </head><body><main class="liveblog-page">
        <h1>#{heading}</h1>
        <section class="live-updates">
          <article class="live-update" id="bridge">
            <time datetime="2026-09-27T09:00:00Z">September 27, 2026</time>
            <h2>#{update_title}</h2><p class="byline">Bridge Reporter</p>
            <div class="update-content"><p>Inspectors completed the bridge review and published the full engineering report with the reopening schedule.</p></div>
            <a rel="bookmark" href="#{parent_url}?update=bridge">Update link</a>
          </article>
          <article class="live-update" id="detour">
            <time datetime="2026-09-27T10:00:00Z">September 27, 2026</time>
            <h2>Transit detour begins</h2><p class="byline">Transit Reporter</p>
            <div class="update-content"><p>The transit agency confirmed the detour route and explained the temporary stops for residents across the district.</p></div>
          </article>
        </section>
      </main></body></html>
    HTML
  end

  it 'keeps a visible parent heading corroborated by the parent description despite child headline metadata' do
    html = title_scope_page(heading: parent_title, headline: update_title, description: parent_title)

    with_url_page(parent_url, html) do |page|
      payload = extract_payload(page)

      expect(payload['title']).to eq(parent_title)
      expect(payload['byline']).to eq('News Desk')
      expect(payload['publishedTime']).to eq('2026-09-26T08:15:00Z')
      expect(payload['markdown']).to start_with("# #{parent_title}\n")
      expect(payload['markdown']).to include("## #{update_title}", 'Transit detour begins', 'full engineering report', 'temporary stops')
    end
  end

  it 'retains the declared parent title when the visible heading and description identify an update' do
    html = title_scope_page(heading: update_title, headline: parent_title, description: update_title)

    with_url_page(parent_url, html) do |page|
      payload = extract_payload(page)

      expect(payload['title']).to eq(parent_title)
      expect(payload['markdown']).to start_with("# #{parent_title}\n")
      expect(payload['markdown']).to include(update_title, 'Transit detour begins')
    end
  end

  it 'keeps an explicitly addressed update title and attribution separate from the parent heading' do
    html = title_scope_page(heading: parent_title, headline: update_title, description: parent_title)

    with_url_page("#{parent_url}?update=bridge", html) do |page|
      payload = extract_payload(page)

      expect(payload['title']).to eq(update_title)
      expect(payload['byline']).to eq('Bridge Reporter')
      expect(payload['publishedTime']).to eq('2026-09-27T09:00:00Z')
      expect(payload['markdown']).to start_with("# #{update_title}\n")
      expect(payload['markdown']).not_to include('Transit detour begins', 'temporary stops')
    end
  end
end
