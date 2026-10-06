# frozen_string_literal: true

RSpec.describe 'FetchUtil Milliyet live extractor integration' do
  include_context 'extractor integration helpers'

  it 'extracts Milliyet live article bodies without false multi-topic warnings' do
    expect_fixture_article(
      url: 'https://www.milliyet.com.tr/dunya/live-tarihi-nato-zirvesi-basladi-trump-ankarada-7618835',
      fixture_path: File.expand_path('../../fixtures/milliyet_live_article.html', __dir__),
      includes: ['Tarihi NATO Zirvesi başladı', 'ABD Başkanı Trump Ankara Havalimanı', 'Milli Savunma Bakanı Yaşar Güler'],
      excludes: ['Günün en çok okunanları'],
      warning_excludes: %w[multi_topic_page empty_extraction short_extraction url_content_mismatch consent_interstitial]
    )
  end

  def declared_liveblog_html(url, ambiguous: false)
    declaration = { '@type' => 'LiveBlogPosting', 'headline' => 'Independent live report', 'mainEntityOfPage' => url }
    declarations = [declaration]
    declarations << declaration.merge('headline' => 'An unrelated live report', 'mainEntityOfPage' => "#{url}/other") if ambiguous
    updates = (1..2).map do |index|
      <<~HTML
        <div><time datetime="2026-10-06T12:0#{index}:00Z">12:0#{index}</time><h2>Owned update heading #{index}</h2>
        <p>Authored update paragraph #{index} with all of the source facts and supporting context preserved.</p></div>
      HTML
    end.join
    <<~HTML
      <html><head><title>Independent live report</title><script type="application/ld+json">#{declarations.to_json}</script></head><body>
      <article><div class="sticky-toolbar">Sharing controls</div><h1>Independent live report</h1>
      <p>Authored introduction to the same live report, including its source scope and factual context.</p>
      <div class="sticky-analysis"><p>This authored sticky analysis is part of the report and must remain with its full source wording.</p></div>
      #{updates}</article></body></html>
    HTML
  end

  it 'preserves a declared unknown-host parent liveblog and its authored sticky prose' do
    url = 'https://live-report.example/events/independent'
    with_url_page(url, declared_liveblog_html(url)) do |page|
      payload = FetchUtil::Extractor.new.extract(page)
      expect(payload).to include('contentType' => 'article', 'contentFormat' => 'liveblog', 'suspect' => false)
      expect(payload.fetch('warnings')).not_to include('multi_topic_page')
      expect(payload.fetch('excerpt')).to start_with('Authored introduction to the same live report')
      markdown = payload.fetch('markdown')
      expect(markdown).to include('This authored sticky analysis is part of the report')
      expect(markdown).not_to include('Sharing controls')
      offsets = (1..2).map do |index|
        expect(markdown).to include("Authored update paragraph #{index}", "12:0#{index}")
        markdown.index("Owned update heading #{index}")
      end
      expect(offsets).to all(be_a(Integer))
      expect(offsets).to eq(offsets.sort)
      expect(page.evaluate('document.querySelector("script[type=\'application/ld+json\']").textContent')).to include('LiveBlogPosting')
    end
  end

  it 'keeps the multi-topic warning when declared parent identity is ambiguous' do
    url = 'https://live-report.example/events/ambiguous'
    with_url_page(url, declared_liveblog_html(url, ambiguous: true)) do |page|
      payload = FetchUtil::Extractor.new.extract(page)
      expect(payload.fetch('warnings')).to include('multi_topic_page')
      expect(payload['suspect']).to be(true)
    end
  end
end
