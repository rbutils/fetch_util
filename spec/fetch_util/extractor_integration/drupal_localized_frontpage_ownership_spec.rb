require 'spec_helper'
require 'nokogiri'

RSpec.describe 'Explicit localized Drupal front-page ownership' do
  include_context 'extractor integration helpers'

  let(:introduction) do
    'This independently authored statistical introduction explains the complete published evidence and its public methods. ' \
      'Readers can consult the underlying observations, compare the published measurements, and retain every relevant qualification. ' \
      'The separate updates and resources are equally substantive parts of this public institutional front page.'
  end
  let(:program) { "printf '%s\\n' 'independent [observation]'" }

  def front_page_html(url)
    <<~HTML
      <html lang="en"><head><title>Open statistical portal</title>
        <meta name="generator" content="Drupal 10">
        <meta property="og:type" content="website">
        <meta property="og:title" content="Open statistical portal">
        <link rel="canonical" href="#{url}">
      </head><body class="path-frontpage">
        <header><a href="#{url}" data-drupal-link-system-path="&lt;front&gt;">Current language home</a></header>
        <main>
          <section><div class="field--name-body">
            <h2>Browse published statistics</h2><p>#{introduction}</p>
            <p>The complete introduction retains its own independently published source material and every substantive methodological qualification.</p>
            <ul><li><a href="/data-one">First independent dataset</a></li>
              <li><a href="/data-two">Second independent dataset</a></li>
              <li><a href="/method">Complete published methods</a></li></ul>
            <p><img src="/overview.png" alt="Overview evidence"></p>
          </div></section>
          <section><h2>Published updates <a href="/updates">View all updates</a></h2>
            <p>These independently authored updates preserve the current reporting and its complete source-owned context.</p>
            <ul><li><a href="/update">A separately published update</a></li></ul>
          </section>
          <section><h2>Research resources <a href="/resources">View all resources</a></h2>
            <p>The resource guide retains <a href="/package">the complete research package</a> and its explicit qualification.</p>
            <p>An independently repeated reference retains <a href="/data-one">the first dataset in this resource context</a>.</p>
            <pre><code>#{program}</code></pre>
            <p><img src="/support.png" alt="Supporting evidence"></p>
            <details><summary>Closed archival information</summary>
              <p>Closed archival answer must remain unavailable.</p><pre><code>hidden_archival_program()</code></pre>
            </details>
          </section>
          <section hidden><h2>Hidden reporting</h2><p>Hidden statistical answer must remain unavailable.</p></section>
        </main>
        <nav><a href="/navigation">Unrelated navigation destination</a></nav>
      </body></html>
    HTML
  end

  def article_html(url:, home_href:, entity: nil)
    declaration = entity ? "<script type=\"application/ld+json\">#{JSON.generate(entity)}</script>" : ''
    <<~HTML
      <html lang="en"><head><title>One independent statistical investigation</title>
        <meta name="generator" content="Drupal 10"><link rel="canonical" href="#{url}">#{declaration}
      </head><body class="path-frontpage">
        <header><a href="#{home_href}" data-drupal-link-system-path="&lt;front&gt;">Language home</a></header>
        <main><article class="node--view-mode-full"><h1>One independent statistical investigation</h1>
          <div class="field--name-body"><p>#{introduction}</p>
            <p>The second independently authored paragraph retains the complete investigation, the observed evidence, and its substantive conclusion.</p>
          </div>
        </article></main>
        <section><h2><a href="/related-one">One separately published related investigation</a></h2></section>
        <section><h2><a href="/related-two">Another separately published related investigation</a></h2></section>
      </body></html>
    HTML
  end

  %w[en pt-br].each do |locale|
    it "retains the complete explicitly declared #{locale} front page" do
      url = "https://statistics.publication.example.test/#{locale}/"
      with_url_page(url, front_page_html(url)) do |page|
        before = page.evaluate('document.body.outerHTML')
        payload = extract(page)
        markdown = payload.fetch('markdown')
        native = Nokogiri::HTML.fragment(payload.fetch('html'))
        expect(payload.fetch('title')).to eq('Open statistical portal')
        expect(payload.fetch('contentType')).to eq('list')
        expect(markdown).to include(introduction, 'Published updates', 'Research resources')
        expect(markdown).to include('These independently authored updates', 'its explicit qualification')
        expect(markdown).to include('the first dataset in this resource context', program)
        visible_programs = native.css('pre').reject do |node|
          node.ancestors('details').any? { |details| !details.key?('open') }
        end
        expect(visible_programs.map(&:text)).to eq([program])
        expect(native.at_css('details').key?('open')).to be(false)
        expect(native.at_css('details summary').text).to eq('Closed archival information')
        expect(native.css('img').map { |image| image['alt'] }).to eq(['Overview evidence', 'Supporting evidence'])
        expect(markdown).to include('Overview evidence', '/overview.png', 'Supporting evidence', '/support.png')
        expected_paths = %w[/data-one /data-two /method /updates /update /resources /package /data-one]
        expect(native.css('a[href]').map { |link| URI(link['href']).path }).to eq(expected_paths)
        destinations = markdown.scan(%r{\]\((https?://[^)]+)\)}).flatten.map { |value| URI(value).path }
        expect(destinations.reject { |path| %w[/overview.png /support.png].include?(path) }).to eq(expected_paths)
        expect(markdown).to include('Closed archival information')
        expect(markdown).not_to include('Closed archival answer', 'hidden_archival_program', 'Hidden statistical answer', 'Unrelated navigation destination')
        expect(page.evaluate('document.body.outerHTML')).to eq(before)
      end
    end
  end

  it 'does not infer a localized home from a front-page marker with a different declared home' do
    url = 'https://statistics.publication.example.test/en/investigation'
    with_url_page(url, article_html(url: url, home_href: '/en/')) do |page|
      before = page.evaluate('document.body.outerHTML')
      payload = extract(page)
      expect(payload.fetch('contentType')).to eq('article')
      expect(payload.fetch('title')).to eq('One independent statistical investigation')
      expect(payload.fetch('markdown')).to include(introduction, 'the complete investigation')
      expect(payload.fetch('markdown')).not_to include('separately published related investigation')
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
    end
  end

  it 'does not infer a localized home from a current front link without the body declaration' do
    url = 'https://statistics.publication.example.test/en/'
    html = article_html(url: url, home_href: url).sub('class="path-frontpage"', '')
    with_url_page(url, html) do |page|
      before = page.evaluate('document.body.outerHTML')
      payload = extract(page)
      expect(payload.fetch('contentType')).to eq('article')
      expect(payload.fetch('title')).to eq('One independent statistical investigation')
      expect(payload.fetch('markdown')).to include(introduction, 'the complete investigation')
      expect(payload.fetch('markdown')).not_to include('separately published related investigation')
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
    end
  end

  it 'preserves an explicitly focal article even when its current URL is declared a localized home' do
    url = 'https://statistics.publication.example.test/en/'
    entity = { '@context' => 'https://schema.org', '@type' => 'NewsArticle', 'url' => url,
               'headline' => 'One independent statistical investigation' }
    with_url_page(url, article_html(url: url, home_href: url, entity: entity)) do |page|
      before = page.evaluate('document.body.outerHTML')
      payload = extract(page)
      expect(payload.fetch('contentType')).to eq('article')
      expect(payload.fetch('title')).to eq('One independent statistical investigation')
      expect(payload.fetch('markdown')).to include(introduction, 'the complete investigation')
      expect(payload.fetch('markdown')).not_to include('separately published related investigation')
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
    end
  end
end
