# frozen_string_literal: true

require 'json'

RSpec.describe 'FetchUtil press release extraction' do
  include_context 'extractor integration helpers'

  def declared_wire_release(publisher:, site_name: 'PR Newswire', canonical_url: nil)
    title = 'Example Robotics announces a research platform'
    schema = { '@context' => 'https://schema.org', '@type' => 'PressRelease',
               'headline' => title, 'publisher' => publisher }
    canonical = canonical_url ? %(<link rel="canonical" href="#{canonical_url}">) : ''
    <<~HTML
      <html><head><title>#{title}</title><meta property="og:site_name" content="#{site_name}">
      #{canonical}<script type="application/ld+json">#{JSON.generate(schema)}</script></head>
      <body><main><article class="release-body"><h1>#{title}</h1>
        <p>This press release was distributed by PRNewswire. Example Robotics announced a research
        platform that documents the measurements, sources, and operating assumptions behind each result.</p>
        <p>The platform retains the original measurements and publishes reproducible methods so that
        independent researchers can inspect the evidence and compare the results with earlier studies.</p>
      </article></main></body></html>
    HTML
  end

  it 'recognizes a declared wire publisher on an unknown host without treating the issuer as publisher' do
    html = declared_wire_release(publisher: { 'name' => 'PR Newswire' })
    with_url_page('https://wire.example/releases/research-platform', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract_payload(page)
      expect_content_type(payload, 'press_release')
      expect(payload.fetch('warnings')).not_to include('syndicated_repost')
      expect(payload.fetch('markdown')).to include('original measurements', 'independent researchers')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'does not exempt a republisher or issuing company just because its hostname belongs to a wire service' do
    cases = [
      { publisher: { 'name' => 'Independent Journal' }, site_name: 'Independent Journal' },
      { publisher: { 'name' => 'Example Robotics' } },
      { publisher: { 'name' => 'Business Wire' }, site_name: 'Business Wire' },
      { publisher: [{ 'name' => 'PR Newswire' }, { 'name' => 'Another publisher' }] }
    ]
    cases.each do |declarations|
      extract_from_url('https://www.prnewswire.com/releases/research-platform', declared_wire_release(**declarations)) do |payload|
        expect(payload.fetch('warnings')).to include('syndicated_repost')
        expect(payload.fetch('markdown')).to include('original measurements')
      end
    end
  end

  it 'declines contradictory canonical or publisher origins despite matching declared names' do
    declarations = [
      { publisher: { 'name' => 'PR Newswire', 'url' => 'https://other.example/' } },
      { publisher: { 'name' => 'PR Newswire' }, canonical_url: 'https://other.example/releases/original' }
    ]
    declarations.each do |record|
      extract_from_url('https://wire.example/releases/research-platform', declared_wire_release(**record)) do |payload|
        expect(payload.fetch('warnings')).to include('syndicated_repost')
      end
    end
  end

  it 'extracts PR Newswire release bodies instead of category lists or repost warnings' do
    html = fixture_contents(File.expand_path('../../fixtures/prnewswire_press_release.html', __dir__))

    extract_from_url('https://www.prnewswire.com/news-releases/example-robotics-announces-new-fleet-platform-302500001.html', html) do |payload|
      expect_content_type(payload, 'press_release')
      expect(payload['markdown']).to include('Example Robotics release fixture: a depot board groups robot')
      expect(payload['markdown']).to include('Example Robotics labels the synthetic platform')
      expect(payload['markdown']).not_to include('Other Company Announces Update')
      expect(payload['warnings']).not_to include('syndicated_repost')
      expect(payload['warnings']).not_to include('stale_content')
    end
  end

  it 'keeps Google company-news articles as body content instead of category lists' do
    html = fixture_contents(File.expand_path('../../fixtures/google_company_news_article.html', __dir__))

    extract_from_url('https://blog.google/company-news/google-shares-new-tools-for-small-businesses/', html) do |payload|
      expect_content_type(payload, 'article')
      expect(payload['markdown']).to include('Google company-news fixture: a sample merchant workspace')
      expect(payload['markdown']).to include('The synthetic controls enter a staged regional rollout')
      expect(payload['markdown']).not_to include('Search update expands')
    end
  end

  it 'classifies strong corporate newsroom releases as press releases without stale warnings' do
    html = fixture_contents(File.expand_path('../../fixtures/apple_newsroom_press_release.html', __dir__))

    urls = [
      'https://www.apple.com/newsroom/2021/05/apple-introduces-new-accessibility-features/',
      'https://organization.example/newsroom/2021/05/accessibility-features/',
      'https://organization.example/press'
    ]
    urls.each do |url|
      extract_from_url(url, html) do |payload|
        expect_content_type(payload, 'press_release')
        expect(payload['markdown']).to include('Apple accessibility fixture: the sample release groups mobility')
        expect(payload['warnings']).not_to include('stale_content')
        expect(payload['warnings']).not_to include('multi_topic_page')
      end
    end
  end

  it 'extracts Amazon Freight newsroom article bodies' do
    html = fixture_contents(File.expand_path('../../fixtures/amazon_freight_newsroom_article.html', __dir__))

    extract_from_url('https://freight.amazon.com/newsroom/amazon-freight-expands-shipping-options', html) do |payload|
      expect_content_type(payload, 'press_release')
      expect(payload['markdown']).to include('Amazon Freight announced a synthetic lane-record update')
      expect(payload['markdown']).to include('A portal workflow exposes booking')
      expect(payload['warnings']).not_to include('stale_content')
    end
  end

  it 'does not bypass Business Wire access walls' do
    html = <<~HTML
      <html>
        <head><title>Access Error</title></head>
        <body><main><h1>Access Error</h1><p>The request was declined before the page could load.</p></main></body>
      </html>
    HTML

    extract_from_url('https://www.businesswire.com/news/home/20260709000001/en/example-release', html) do |payload|
      expect_content_type(payload, 'interstitial')
      expect(payload['warnings']).to include('access_error_interstitial')
      expect(payload['markdown']).to include('Access Error')
    end
  end

  it 'excludes hidden press release body content while preserving restored visibility' do
    html = <<~HTML
      <html><head><title>Example Systems announces visibility update</title></head><body><main>
        <article class="press-release"><h1>Example Systems announces visibility update</h1>
          <p>PRESS:Visible opening describes the synthetic release, its documented rollout, and the operating practices used by the example team across every supported region.</p>
          <p>PRESS:Visible detail provides enough substantive release context for deterministic body qualification while explaining the example launch schedule and support model.</p>
          <p style="display:none">PRESS:Display-none body must not appear in public output.</p>
          <div style="visibility:hidden">
            PRESS:Inherited-hidden body must not appear in public output.
            <p style="visibility:visible">PRESS:Restored body remains available as substantive release context for every reader.</p>
          </div>
        </article>
      </main></body></html>
    HTML

    extract_from_url('https://company.example.test/newsroom/press-release/visibility-update', html) do |payload|
      expect_content_type(payload, 'press_release')
      expect(payload['markdown']).to include('PRESS:Visible opening', 'PRESS:Restored body')
      expect(payload['markdown']).not_to include('PRESS:Display-none body', 'PRESS:Inherited-hidden body')
      expect(payload['html']).not_to include('PRESS:Display-none body', 'PRESS:Inherited-hidden body')
    end
  end

  it 'leaves a dated press release index to generic list extraction' do
    html = <<~HTML
      <html><head><title>Press releases</title></head><body><main><h1>Press releases</h1>
        <article class="release"><a href="#archive">Jump to archive</a><time>June 28, 2026</time></article>
        <article class="release"><a href="javascript:openRelease()">Open release dialog</a><time>June 29, 2026</time></article>
        <article class="release"><a href="mailto:news@example.test">Email the newsroom</a><time>June 30, 2026</time></article>
        <article class="release"><a href="/news/one">Launches new service</a><time>July 1, 2026</time></article>
        <article class="release"><a href="/news/two">Reports results</a><time>July 2, 2026</time></article>
        <article class="release"><a href="/news/three">Announces expansion</a><time>July 3, 2026</time></article>
        <article class="release"><a href="/news/four">Opens new office</a><time>July 4, 2026</time></article>
        <article class="release"><a href="/news/latest">Publishes first recurring update</a><time>July 5, 2026</time></article>
        <article class="release"><a href="/news/latest">Publishes second recurring update</a><time>July 6, 2026</time></article>
        <article class="release responsive-copy"><a href="/news/latest">Publishes first recurring update</a><time>July 5, 2026</time></article>
        <article class="release" style="display:none"><a href="/news/hidden">Hidden release</a><time>July 5, 2026</time></article>
        <article class="release" style="visibility:hidden"><a style="visibility:visible" href="/news/restored">Restored release</a><time style="visibility:visible">July 6, 2026</time></article>
        <article class="release"><a style="visibility:hidden" href="/news/restored-child"><span style="visibility:visible">Child-restored release</span></a><time>July 7, 2026</time></article>
      </main></body></html>
    HTML

    extract_from_url('https://news.example.test/press-releases', html) do |payload|
      expect_content_type(payload, 'list')
      expect(payload['markdown']).to include('Launches new service')
      expect(payload['markdown']).to include('Restored release', 'Child-restored release')
      expect(payload['markdown']).not_to include('Jump to archive', 'Open release dialog', 'Email the newsroom')
      expect(payload['markdown']).not_to include('Hidden release')
      expect(payload['markdown']).not_to include('javascript:', 'mailto:', '#archive')
      expect(payload['markdown']).not_to include('Price:')
      expect(payload['markdown'].scan('Publishes first recurring update').length).to eq(1)
      expect(payload['markdown'].scan('Publishes second recurring update').length).to eq(1)
      expect(payload['markdown'].index('Publishes first recurring update')).to be < payload['markdown'].index('Publishes second recurring update')
    end
  end
end
