require 'spec_helper'

RSpec.describe 'Complete homepage ownership across shared adapters' do
  include_context 'extractor integration helpers'

  def stories(prefix, count)
    (1..count).map do |index|
      <<~HTML
        <article><a href="/#{prefix}-#{index}"><h3>#{prefix} reporting record #{index} retains its complete headline</h3></a>
          <p>#{prefix} summary #{index} preserves the independently authored context for this visible publication.</p>
        </article>
      HTML
    end.join
  end

  it 'keeps independent sections beside an eligible topic collection' do
    html = <<~HTML
      <html><head><title>Independent publications</title></head><body class="no-right-sidebar"><div class="layout has-sidebar">
        <section class="topic-list"><h2>Initial reporting</h2>#{stories("initial", 9)}</section>
        <section><h2>Further observations</h2>#{stories("additional", 5)}</section>
        <aside><h3><a href="/supplement">Published supplementary observation</a></h3>
          <p>This authored supplementary record preserves independently published context.</p></aside>
        <aside><p>Unrelated sidebar promotion</p></aside>
      </div></body></html>
    HTML
    with_url_page('https://publication.example.test/', html) do |page|
      payload = extract(page)
      %w[initial additional].each do |prefix|
        count = prefix == 'initial' ? 9 : 5
        (1..count).each do |index|
          expect(payload.fetch('markdown')).to include("#{prefix} reporting record #{index}", "/#{prefix}-#{index}")
        end
      end
      expect(payload.fetch('markdown')).to include('Further observations')
      expect(payload.fetch('markdown')).to include('Published supplementary observation', '/supplement', 'This authored supplementary record')
      expect(payload.fetch('markdown')).not_to include('Unrelated sidebar promotion')
    end
  end

  it 'does not reduce a generated homepage to its introduction field' do
    introduction = "Our authored introduction explains the foundation's public purpose and its independent research. " \
                   'It preserves the wider context for the published findings, the people who prepared them, and the evidence available to readers. ' \
                   'The separate reporting collection remains an equally substantive part of the public homepage.'
    html = <<~HTML
      <html><head><title>Independent foundation</title><meta name="generator" content="Drupal"></head><body>
        <h1>Independent foundation</h1><div class="field--name-body"><p>#{introduction}</p></div>
        <section><h2>Published research</h2>#{stories("research", 8)}</section>
      </body></html>
    HTML
    with_url_page('https://foundation.example.test/', html) do |page|
      payload = extract(page)
      (1..8).each { |index| expect(payload.fetch('markdown')).to include("research reporting record #{index}") }
      expect(payload.fetch('title')).to eq('Independent foundation')
      expect(payload.fetch('textContent')).to include(introduction)
    end
  end

  it 'preserves a self-contained CMS article at the root URL' do
    url = 'https://publication.example.test/'
    entity = { '@context' => 'https://schema.org', '@type' => 'NewsArticle', 'url' => url, 'headline' => 'One independently authored investigation' }
    html = <<~HTML
      <html><head><title>One independently authored investigation</title><link rel="canonical" href="#{url}">
        <script type="application/ld+json">#{JSON.generate(entity)}</script></head><body class="wp-theme-example">
        <main><article><h1>One independently authored investigation</h1><div class="entry-content">
          <p>This complete published investigation explains the evidence and retains its source-owned reporting.</p>
          <p>The second independently authored paragraph preserves the substantive findings and their context.</p>
        </div></article></main>
        <section><h2><a href="/related">An independently linked related publication</a></h2></section>
      </body></html>
    HTML
    with_url_page(url, html) do |page|
      payload = extract(page)
      expect(payload.fetch('title')).to eq('One independently authored investigation')
      expect(payload.fetch('contentType')).to eq('article')
      expect(payload.fetch('markdown')).to include('This complete published investigation', 'The second independently authored paragraph')
    end
  end

  it 'keeps the introduction and independent reporting around a CMS hero' do
    url = 'https://institution.example.test/'
    entity = { '@context' => 'https://schema.org', '@type' => 'Article', 'url' => url, 'headline' => 'Independent institution',
               'datePublished' => '2020-01-01T12:00:00Z' }
    html = <<~HTML
      <html><head><title>Independent institution</title><script type="application/ld+json">#{JSON.generate(entity)}</script></head><body class="wp-theme-example">
        <article><h1>One currently highlighted finding</h1><div class="entry-content">
          <p>This source-owned introduction retains the institution's public purpose and the context of its independently published work.</p>
          <p>Its second substantive paragraph explains the evidence available to readers and preserves the complete reporting context.</p>
        </div></article>
        <section><h2>Further publications</h2>#{stories("publication", 8)}</section>
      </body></html>
    HTML
    with_url_page(url, html) do |page|
      payload = extract(page)
      expect(payload.fetch('contentType')).to eq('list')
      expect(payload.fetch('markdown')).to include('This source-owned introduction', 'Its second substantive paragraph', 'Further publications')
      (1..8).each { |index| expect(payload.fetch('markdown')).to include("publication reporting record #{index}") }
      expect(payload['publishedTime']).to be_nil
    end
  end

  it 'does not mistake navigation and a hidden collection for primary reporting' do
    html = <<~HTML
      <html><head><title>One public institution</title></head><body class="wp-theme-example">
        <article><h1>One public institution</h1><div class="entry-content">
          <p>This complete source-owned article retains its independently authored discussion and the reporting evidence available to readers.</p>
          <p>Its second substantive paragraph supplies the conclusion and remains separate from navigation, hidden records, and peripheral links.</p>
        </div></article>
        <nav><h2><a href="/overview">A navigation destination</a></h2></nav>
        <aside><h3><a href="/peripheral">A peripheral destination</a></h3></aside>
        <section hidden><h2>Unavailable publications</h2>#{stories("hidden", 8)}</section>
      </body></html>
    HTML
    with_url_page('https://institution.example.test/', html) do |page|
      payload = extract(page)
      expect(payload.fetch('contentType')).to eq('article')
      expect(payload.fetch('markdown')).to include('This complete source-owned article', 'Its second substantive paragraph')
      expect(payload.fetch('markdown')).not_to include('Unavailable publications', 'hidden reporting record')
    end
  end

  it 'keeps a complete headingless publication index inside a CMS page body' do
    url = 'https://institute.example.test/'
    entity = { '@context' => 'https://schema.org', '@type' => 'Article', 'url' => url,
               'headline' => 'Independent institute', 'datePublished' => '2020-01-01T12:00:00Z' }
    records = (1..4).map do |index|
      <<~HTML
        <a href="/finding-#{index}"><p>Published finding #{index} retains its independently authored headline</p>
          <img src="/image-#{index}.jpg" alt="Evidence for finding #{index}"></a>
      HTML
    end.join
    html = <<~HTML
      <html><head><title>Independent institute</title><script type="application/ld+json">#{JSON.generate(entity)}</script></head>
      <body class="wp-theme-example"><main><article><div class="entry-content">
        <h2>A highlighted investigation</h2><p>This authored introduction retains the institute's public purpose and the evidence behind its independent research.</p>
        <p>The second source-owned paragraph supplies substantive context for the separately published reporting and its resources.</p>
        <section class="latest-news"><h2>Current observations</h2>#{records}</section>
      </div></article></main></body></html>
    HTML
    with_url_page(url, html) do |page|
      payload = extract(page)
      expect(payload.fetch('title')).to eq('Independent institute')
      expect(payload.fetch('contentType')).to eq('list')
      expect(payload['publishedTime']).to be_nil
      (1..4).each do |index|
        expect(payload.fetch('markdown')).to include("Published finding #{index}", "/finding-#{index}", "/image-#{index}.jpg")
      end
      expect(payload.fetch('markdown')).to include('This authored introduction', 'The second source-owned paragraph')
    end
  end
end
