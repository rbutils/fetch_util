# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'FetchUtil extractor integration - same-path query collections' do
  include_context 'extractor integration helpers'

  it 'preserves every source-owned query record, including short labels, in visible order' do
    labels = (1..30).map { |index| "Query #{index}" }
    labels[4] = 'AI'
    entries = labels.each_with_index.map do |label, index|
      %(<li><a href="/search/?text=#{index + 1}">#{label}</a></li>)
    end.join
    html = <<~HTML
      <html><head><title>Search history</title></head><body>
        <header><a href="/login">Log in</a></header>
        <main><h1>Search history</h1><h2>Previous queries</h2>
          <ul>#{entries}</ul>
        </main>
      </body></html>
    HTML

    with_url_page('https://search.example/search/', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = FetchUtil::Extractor.new.extract(page)
      markdown = payload.fetch('markdown')

      expect(payload['contentType']).to eq('list')
      positions = labels.each_with_index.map do |label, index|
        destination = "https://search.example/search/?text=#{index + 1}"
        expect(markdown.scan("](#{destination})").length).to eq(1)
        expect(markdown).to include("[#{label}](#{destination})")
        markdown.index("](#{destination})")
      end
      expect(positions).to eq(positions.sort)
      expect(markdown).not_to include('https://search.example/login')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'does not promote a navigation-only query list over a focal article' do
    navigation = (1..12).map { |index| %(<li><a href="/guide?search=#{index}">Topic #{index}</a></li>) }.join
    html = <<~HTML
      <html><head><title>Practical guide</title></head><body>
        <nav><h2>Quick search</h2><ul>#{navigation}</ul></nav>
        <main><article><h1>Practical guide</h1>
          <p>This detailed introduction explains the subject and provides durable context for readers.</p>
          <p>The second paragraph describes an independently verified example in useful detail.</p>
          <p>The third paragraph draws a conclusion from the two preceding examples.</p>
        </article></main>
      </body></html>
    HTML

    with_url_page('https://search.example/guide', html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload['contentType']).to eq('article')
      expect(payload.fetch('markdown')).to include('independently verified example')
      expect(payload.fetch('markdown')).not_to include('/guide?search=')
    end
  end
end
