require 'spec_helper'

RSpec.describe 'Declared article regions across layout branches' do
  include_context 'extractor integration helpers'

  let(:url) { 'https://publication.example.test/dispatch' }
  let(:paragraphs) do
    (1..12).map do |index|
      "Reporting section #{index} preserves the evidence, the independently attributed observations and the context of this published investigation."
    end
  end

  def document(body, headline: 'Independent observations', entity_url: url, description: '')
    entity = { '@context' => 'https://schema.org', '@type' => 'NewsArticle', 'headline' => headline,
               'mainEntityOfPage' => { '@type' => 'WebPage', 'url' => entity_url } }
    <<~HTML
      <html><head><title>Independent observations</title><link rel="canonical" href="#{url}">
        <meta name="description" content="#{description}">
        <script type="application/ld+json">#{JSON.generate(entity)}</script></head><body>#{body}</body></html>
    HTML
  end

  def regions(extra = '', hidden: false)
    <<~HTML
      <div><div class="article--header"><header><h1>Independent observations</h1></header>
        <div class="article--content"><p>Authored introduction explains why this independent reporting matters.</p></div>
      </div></div>
      <div><div class="article--content" #{hidden ? "hidden" : ""}>
        #{paragraphs.map { |paragraph| "<p>#{paragraph}</p>" }.join}
        <h2>Source relationships</h2><p>Source citation <a href="/evidence">published evidence</a>.</p>
        <pre><code>preserve_observations()</code></pre>
      </div></div>#{extra}
    HTML
  end

  it 'retains the complete declared body and its header without selecting a later notice' do
    html = document(regions('<section><h2>Participation notice</h2><p>Separate service information is not primary reporting.</p></section>'))
    with_url_page(url, html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract(page)
      expect(payload.fetch('title')).to eq('Independent observations')
      expect(payload.fetch('contentType')).to eq('article')
      expect(payload.fetch('markdown')).to include('Authored introduction', 'Source relationships', 'published evidence', 'preserve_observations()')
      paragraphs.each { |paragraph| expect(payload.fetch('markdown')).to include(paragraph) }
      positions = paragraphs.map { |paragraph| payload.fetch('markdown').index(paragraph) }
      expect(positions).to eq(positions.sort)
      expect(payload.fetch('markdown')).not_to include('Separate service information')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'does not infer split ownership from foreign or conflicting declarations' do
    main = "<main><article><h1>Independent observations</h1>#{paragraphs.map { |text| "<p>#{text}</p>" }.join}</article></main>"
    unrelated = '<div class="article--header"><h1>A different publication</h1></div>' \
                '<div class="article--content"><p>Unrelated region does not belong to the selected primary investigation.</p></div>'
    [document(main + unrelated, headline: 'A different publication', entity_url: 'https://elsewhere.example.test/story'),
     document(main + unrelated, headline: 'A different publication')].each do |html|
      with_url_page(url, html) do |page|
        payload = extract(page)
        paragraphs.each { |paragraph| expect(payload.fetch('markdown')).to include(paragraph) }
        expect(payload.fetch('title')).to eq('Independent observations')
        expect(payload.fetch('excerpt')).to include(paragraphs.first)
      end
    end
  end

  it 'does not materialize a hidden body' do
    with_url_page(url, document(regions('', hidden: true))) do |page|
      payload = extract(page)
      expect(payload.fetch('markdown')).not_to include(paragraphs.first, 'preserve_observations()')
    end
  end

  it 'retains separately declared preview and full-body regions in source order' do
    standfirst = 'A published standfirst introduces the investigation and gives readers its source-backed context.'
    html = <<~HTML
      <div class="article--header"><h1>Independent observations</h1></div>
      <div><p class="text--lead">#{standfirst}</p></div>
      <div class="article--content article--content-free"><p>#{paragraphs.first}</p></div>
      <div>
        <div class="article--content article--content-paid">#{paragraphs.drop(1).map { |text| "<p>#{text}</p>" }.join}</div>
      </div>
      <section><h2>Participation notice</h2><p>Separate service information is not primary reporting.</p></section>
    HTML
    with_url_page(url, document(html, description: standfirst)) do |page|
      payload = extract(page)
      paragraphs.each { |paragraph| expect(payload.fetch('markdown')).to include(paragraph) }
      positions = paragraphs.map { |paragraph| payload.fetch('markdown').index(paragraph) }
      expect(positions).to eq(positions.sort)
      expect(payload.fetch('markdown')).to include(standfirst)
      expect(payload.fetch('markdown').index(standfirst)).to be < positions.first
      expect(payload.fetch('title')).to eq('Independent observations')
      expect(payload.fetch('markdown')).not_to include('Separate service information')
    end
  end
end
