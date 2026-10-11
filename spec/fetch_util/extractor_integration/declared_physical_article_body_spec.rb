require 'spec_helper'

RSpec.describe 'Complete declared physical article ownership' do
  include_context 'extractor integration helpers'

  let(:url) { 'https://publication.example.test/investigation' }
  let(:headline) { 'Independent investigation and its published findings' }
  let(:printed_heading) { 'A different printed heading for this investigation' }
  let(:lead) { 'The reporting lead explains the investigation and the evidence gathered from independently attributed sources.' }
  let(:paragraphs) do
    (1..15).map do |index|
      "Reporting paragraph #{index} records independently attributed findings and preserves the substantive context of this published investigation."
    end
  end

  def document(declaration_changes: {}, extra_declaration: nil, extra_body: '', hidden_body: false)
    sections = paragraphs.map.with_index do |text, index|
      "#{index == 5 ? "<h2>Evidence and context</h2>" : ""}<p>#{text}</p>"
    end.join
    entity = { '@type' => 'NewsArticle', 'headline' => headline, 'url' => url,
               'articleBody' => "#{paragraphs.take(5).join(" ")} Evidence and context #{paragraphs.drop(5).join(" ")}",
               'author' => { '@type' => 'Person', 'name' => 'Independent Reporter' },
               'datePublished' => '2026-10-10T13:20:26Z' }.merge(declaration_changes)
    declarations = extra_declaration ? [entity, entity.merge(extra_declaration)] : entity
    <<~HTML
      <html><head><title>#{headline}</title><link rel="canonical" href="#{url}">
        <meta name="description" content="#{lead}">
        <script type="application/ld+json">#{JSON.generate(declarations)}</script></head><body>
        <nav><h1>#{headline}</h1></nav>
        <main><article><header><h2>#{printed_heading}</h2>
          <p class="byline">Independent Reporter</p><time datetime="2026-10-10T13:20:26Z">10 October 2026</time>
          <figure><img src="/photo.jpg"><figcaption>A contextual media caption.</figcaption></figure><p>#{lead}</p>
        </header><div class="physical-body" #{hidden_body ? "hidden" : ""}>#{sections}
          <p>Source reference <a href="/evidence">published evidence</a>.</p>
          <pre><code>preserve_observations()</code></pre><table><tr><td>Material data value</td></tr></table>
        </div>#{extra_body}</article>
        <div><h2>Independent services</h2><p>Separate service information outside the reporting owner.</p>
          <div><h3><a href="/different-story">Another independently published story</a></h3><p>Secondary story summary.</p></div>
        </div></main></body></html>
    HTML
  end

  it 'keeps every declared block, the alternate printed header, lead and resources in source order' do
    with_url_page(url, document) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract(page)
      expect(payload.fetch('title')).to eq(headline)
      expect(payload.fetch('contentType')).to eq('article')
      expect(payload.fetch('excerpt')).to eq(lead)
      expect(payload.fetch('byline')).to eq('Independent Reporter')
      expect(payload.fetch('publishedTime')).to eq('2026-10-10T13:20:26Z')
      markdown = payload.fetch('markdown')
      paragraphs.each { |text| expect(markdown).to include(text) }
      positions = paragraphs.map { |text| markdown.index(text) }
      expect(positions).to eq(positions.sort)
      expect(markdown).to include(printed_heading, lead, 'Evidence and context', 'published evidence', 'preserve_observations()', 'Material data value')
      expect(payload.fetch('html')).to include('/photo.jpg', '/evidence')
      expect(markdown).not_to include('Separate service information', 'Secondary story summary')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'retains reporting and material replies not represented in the declaration' do
    reply = '<section class="comments"><article class="comment"><p>A published reply contributes independently authored context.</p></article></section>'
    with_url_page(url, document(extra_body: reply)) do |page|
      payload = extract(page)
      paragraphs.each { |text| expect(payload.fetch('markdown')).to include(text) }
      expect(payload.fetch('markdown')).to include('A published reply contributes independently authored context.')
    end
  end

  it 'does not render JSON-only material or hide reporting when a declaration is incomplete or conflicting' do
    [document(declaration_changes: { 'articleBody' => "#{paragraphs.first} Unmaterialized declaration-only text." }),
     document(declaration_changes: { 'url' => 'https://elsewhere.example.test/investigation' }),
     document(extra_declaration: { 'articleBody' => 'A conflicting body declaration.' }),
     document(declaration_changes: { 'mainEntityOfPage' => 'https://elsewhere.example.test/story' })].each do |html|
      with_url_page(url, html) do |page|
        payload = extract(page)
        paragraphs.each { |text| expect(payload.fetch('markdown')).to include(text) }
        expect(payload.fetch('markdown')).not_to include('Unmaterialized declaration-only text.', 'A conflicting body declaration.')
      end
    end
  end

  it 'does not reveal hidden declared paragraphs' do
    with_url_page(url, document(hidden_body: true)) do |page|
      payload = extract(page)
      expect(payload.fetch('markdown')).not_to include(paragraphs.first, paragraphs.last, 'preserve_observations()')
    end
  end

  it 'preserves material outside the proved body instead of silently narrowing an incomplete owner' do
    additional = '<p>Additional authored reporting remains outside the declared body and must survive.</p>'
    with_url_page(url, document(extra_body: additional)) do |page|
      payload = extract(page)
      expect(payload.fetch('markdown')).to include('Additional authored reporting remains outside the declared body and must survive.')
      paragraphs.each { |text| expect(payload.fetch('markdown')).to include(text) }
    end
  end
end
