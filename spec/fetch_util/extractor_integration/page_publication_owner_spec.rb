require 'spec_helper'

RSpec.describe 'Publication dates of page-owned and linked headings' do
  include_context 'extractor integration helpers'

  def publication_page(destination:, explicit_date: nil)
    declaration = JSON.generate('@context' => 'https://schema.org', '@type' => 'WebPage',
                                'url' => 'https://institution.example.test/', 'name' => 'Research Institute',
                                'datePublished' => '2020-02-03T08:00:00Z', 'dateModified' => '2026-10-09T08:00:00Z')
    paragraphs = (1..5).map do |index|
      "<p>Observation #{index} describes a current research initiative with substantive reporting, findings and useful public context.</p>"
    end.join
    explicit = explicit_date ? "<meta property='article:published_time' content='#{explicit_date}'>" : ''
    <<~HTML
      <html><head><title>Research Institute</title>#{explicit}
      <script type="application/ld+json">#{declaration}</script></head><body>
      <main><section><a href="#{destination}"><h1>Current research initiative</h1></a>#{paragraphs}</section></main>
      </body></html>
    HTML
  end

  it 'does not borrow the page creation date for a heading that identifies another publication' do
    with_url_page('https://institution.example.test/', publication_page(destination: '/reports/current')) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract(page)
      expect(payload['publishedTime']).to be_nil
      expect(payload.fetch('markdown')).to include('Observation 1', 'Observation 5')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'keeps a page publication date when its heading link identifies the current document' do
    with_url_page('https://institution.example.test/', publication_page(destination: '/#overview')) do |page|
      expect(extract(page).fetch('publishedTime')).to eq('2020-02-03T08:00:00Z')
    end
  end

  it 'retains stronger explicit article publication metadata independently of the page date' do
    html = publication_page(destination: '/reports/current', explicit_date: '2026-10-09T09:00:00Z')
    with_url_page('https://institution.example.test/', html) do |page|
      expect(extract(page).fetch('publishedTime')).to eq('2026-10-09T09:00:00Z')
    end
  end
end
