# frozen_string_literal: true

require 'spec_helper'
require 'nokogiri'

RSpec.describe 'FetchUtil extractor integration - authored prose occurrences' do
  include_context 'extractor integration helpers'

  it 'retains each independently owned method description and its complete context' do
    description = 'Unwrap returns the next error in the error chain.'
    program = "next(record)\nnext(record)"
    methods = (1..4).map do |number|
      <<~HTML
        <section id="method-#{number}">
          <h2>Method #{number}</h2>
          <p>#{description}</p>
          <p>Method #{number} preserves its own return value and complete request context.</p>
          <a href="/methods/#{number}">Method #{number} reference</a>
        </section>
      HTML
    end.join
    html = <<~HTML
      <html><head><title>Owned method reference</title></head><body>
        <main class="md-main"><article class="md-content__inner md-typeset">
          <h1>Owned method reference</h1>
          <p>Each operation has a separate contract, source destination and documented return value.</p>
          #{methods}
          <pre><code class="language-python">#{program}</code></pre>
          <section style="display:none"><p>#{description}</p><p>Hidden method context.</p></section>
        </article></main>
      </body></html>
    HTML

    with_url_page('https://docs.publication.example.test/api/methods/', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract(page)
      public_html = Nokogiri::HTML5(payload.fetch('html'))
      expect(public_html.css('p').count { |node| node.text == description }).to eq(4)
      expect(payload.fetch('markdown').scan(Regexp.new(Regexp.escape(description))).length).to eq(4)
      expect(public_html.css('h2').map(&:text)).to eq((1..4).map { |number| "Method #{number}" })
      references = public_html.css('a[href]').map { |node| node['href'] }
      expect(references).to eq((1..4).map { |number| "https://docs.publication.example.test/methods/#{number}" })
      (1..4).each do |number|
        expect(payload.fetch('markdown')).to include("Method #{number} preserves its own return value and complete request context.")
      end
      expect(public_html.css('pre').map(&:text)).to eq([program])
      expect(payload.fetch('markdown')).to include("```python\n#{program}\n```")
      expect(payload.fetch('markdown')).not_to include('Hidden method context.')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'preserves the complete repeated sentences inside one authored article paragraph' do
    sentence = 'The documented operation returns the next available record without changing the original request.'
    paragraph = Array.new(4, sentence).join(' ')
    html = <<~HTML
      <html><head><title>Repeated field instructions</title></head><body><main><article>
        <h1>Repeated field instructions</h1>
        <p>These field instructions deliberately repeat the complete sentence without introducing a control or navigation element.</p>
        <p>#{paragraph}</p>
        <p>Keep every occurrence in its original order and retain the <a href="/procedure">complete procedure</a>.</p>
      </article></main></body></html>
    HTML

    with_url_page('https://publication.example.test/field-instructions', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract(page)
      public_html = Nokogiri::HTML5(payload.fetch('html'))
      expect(public_html.css('p').map(&:text)).to include(paragraph)
      expect(payload.fetch('markdown')).to include(paragraph)
      expect(payload.fetch('markdown').scan(Regexp.new(Regexp.escape(sentence))).length).to eq(4)
      expect(payload.fetch('markdown')).to include('[complete procedure](https://publication.example.test/procedure)')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end
end
