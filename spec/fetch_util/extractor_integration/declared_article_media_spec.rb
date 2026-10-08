# frozen_string_literal: true

require 'json'

RSpec.describe 'FetchUtil declared article and media ownership' do
  include_context 'extractor integration helpers'

  def declared_article_html(hidden: false, headline: 'Measured storm conditions')
    body = 'Published measurements describe the observed electrical conditions and explain why existing protection does not eliminate every possible risk.'
    entity = { '@context' => 'https://schema.org', '@type' => 'NewsArticle', 'headline' => headline, 'articleBody' => body }
    <<~HTML
      <html><head><title>Measured storm conditions</title><meta property="og:type" content="video">
        <meta name="description" content="A short metadata description of the recorded conditions.">
        <script type="application/ld+json">#{JSON.generate(entity)}</script></head><body>
        <article><h1>Measured storm conditions</h1>
          <ul><li>Measurements distinguish the different electrical events.</li><li>The report records the limitations of existing protection.</li></ul>
          <p>The observers published a complete account explaining the measurements and the circumstances under which the observed electrical events occurred.</p>
        </article><main><article #{hidden ? "hidden" : ""}><div>#{body}</div></article></main>
      </body></html>
    HTML
  end

  it 'preserves an independent publisher summary and visible declared body ahead of a player teaser' do
    with_url_page('https://research.example/reports/storms', declared_article_html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload['contentType']).to eq('article')
      expect(payload['hostAware']).to be(false)
      expect(payload['markdown']).to include(
        'Measurements distinguish the different electrical events.',
        'The report records the limitations of existing protection.',
        'The observers published a complete account', 'Published measurements describe the observed electrical conditions'
      )
    end
  end

  it 'does not promote a hidden declared body over a visible media description' do
    with_url_page('https://research.example/reports/storms', declared_article_html(hidden: true)) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload['hostAware']).to be(true)
      expect(payload['markdown']).to include('A short metadata description')
      expect(payload['markdown']).not_to include('Published measurements describe')
    end
  end

  it 'does not borrow an article declaration with a conflicting headline' do
    with_url_page('https://research.example/reports/storms', declared_article_html(headline: 'Another reported event')) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload['hostAware']).to be(true)
      expect(payload['markdown']).to include('A short metadata description')
    end
  end

  it 'requires an explicit current canonical URL and unique owned headline before relaxing a stale slug' do
    url = 'https://journal.example/volcanic-eruption-forecast'
    [[url, false], ['https://journal.example/another-page', false], [url, true]].each do |canonical, competing|
      html = <<~HTML
        <html><head><title>Transport records updated</title><meta property="og:type" content="article">
          <link rel="canonical" href="#{canonical}"></head><body>#{"<h1>Competing report</h1>" if competing}<article><h1>Transport records updated</h1>
          <p>The council published detailed bus timetables and explained the revised routes, stop locations and connections with other public transport services.</p>
          <p>Readers can compare the complete schedules against the previous records, check the data collection method and inspect the decisions in their original context.</p>
        </article></body></html>
      HTML
      with_url_page(url, html) do |page|
        payload = FetchUtil::Extractor.new.extract(page)

        expect(payload['warnings'].include?('url_content_mismatch')).to eq(canonical != url || competing)
        expect(payload['warnings']).to eq(payload['warnings'].uniq)
        expect(payload['markdown']).to include('The council published detailed bus timetables', 'Readers can compare the complete schedules')
      end
    end
  end
end
