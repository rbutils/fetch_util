# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'FetchUtil extractor integration - source-owned browse indexes' do
  include_context 'extractor integration helpers'

  it 'retains every alphabetic and year entry with the subsequent public notice in DOM order' do
    letters = ('A'..'Z').map do |letter|
      %(<a href="/records/toc-#{letter}.html">#{letter}</a>)
    end
    letters << '<a href="/records/toc-other.html">other</a>'
    years = (1890..2016).map do |year|
      %(<a href="/records/#{year}.html">#{year}</a>)
    end
    html = <<~HTML
      <html><head><title>Archived decisions</title></head><body>
        <header><a href="/login">Log in</a></header>
        <h1>Archived decisions</h1>
        <h3>Browse titles by letter <blockquote>#{letters.join(" ")}</blockquote></h3>
        <h3>Browse decisions by year <blockquote>#{years.join(" ")}</blockquote></h3>
        <h1>About this archive</h1>
        <blockquote><h2>IMPORTANT INFORMATION</h2>
          <p>These records document historical decisions and include the full text of each public ruling.</p>
          <p>The archive records the decisions in their original sequence and explains the source of the historical judgments available here.</p>
          <p>Researchers can consult the collection to identify a particular year, locate its individual decisions, and follow the published record.</p>
          <p>Each annual collection is an independent set of public judgments, including titles and the full text of the ruling where available.</p>
          <p>More recent decisions are available through the
            <a href="/recent">recent decisions collection</a>.</p>
        </blockquote>
      </body></html>
    HTML

    with_url_page('https://records.example/records/', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = FetchUtil::Extractor.new.extract(page)
      markdown = payload.fetch('markdown')
      urls = (('A'..'Z').to_a + ['other']).map { |name| "https://records.example/records/toc-#{name}.html" }
      urls += (1890..2016).map { |year| "https://records.example/records/#{year}.html" }

      expect(payload['contentType']).to eq('list')
      expect(payload['contentFormat']).to be_nil
      expect(payload['readerMode']).to eq(false)
      expect(payload.fetch('html')).to include('toc-A.html', '2016.html', 'IMPORTANT INFORMATION')
      positions = urls.map do |url|
        expect(markdown.scan("](#{url})").length).to eq(1), "missing #{url} from #{markdown.bytesize}-byte index: #{markdown.lines.first(12).join}"
        markdown.index("](#{url})")
      end
      expect(positions).to eq(positions.sort)
      expect(markdown).to include('IMPORTANT INFORMATION', 'full text of each public ruling')
      expect(markdown).to include('[recent decisions collection](https://records.example/recent)')
      expect(markdown.index('2016.html)')).to be < markdown.index('IMPORTANT INFORMATION')
      expect(markdown).not_to include('https://records.example/login')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'does not use a sidebar index to displace a focal article' do
    letters = ('A'..'Z').map { |letter| %(<a href="/story/toc-#{letter}">#{letter}</a>) }.join
    years = (1890..2016).map { |year| %(<a href="/story/#{year}">#{year}</a>) }.join
    html = <<~HTML
      <html><head><title>Public investigation</title></head><body>
        <main><article><h1>Public investigation</h1>
          <p>The central narrative explains the investigation and its primary findings in detail.</p>
          <p>Another paragraph describes the evidence behind the article and why it matters to readers.</p>
        </article></main>
        <aside><h3>Browse letters #{letters}</h3><h3>Browse years #{years}</h3></aside>
      </body></html>
    HTML

    with_url_page('https://records.example/story/public-investigation', html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload['contentType']).to eq('article')
      expect(payload.fetch('markdown')).to include('central narrative', 'primary findings')
      expect(payload.fetch('markdown')).not_to include('/story/toc-')
    end
  end
end
