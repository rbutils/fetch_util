# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Source-owned Reader article headers' do
  include_context 'extractor integration helpers'

  def reader_header_body
    '<p>The river restoration team returned to measure the water.</p>' \
      '<p>Engineers recorded improved flow through the restored channel.</p>'
  end

  def reader_header_page(extra: '', lead: 'A complete guide to restoring the river.')
    <<~HTML
      <html><head><title>Restoring the river</title></head><body>
        <header>Unrelated site navigation</header>
        <main><article><header>
          <span><a href="/science">Science</a> · 4 min read</span>
          <span style="display:none"><a href="/hidden">Hidden promotion</a></span>
          <button>Share this story</button><h1>Restoring the river</h1><p>#{lead}</p>
        </header><section>#{reader_header_body}</section></article>#{extra}</main>
      </body></html>
    HTML
  end

  def reader_header_probe(page)
    extract_payload(page)
    root = File.expand_path('../../..', __dir__)
    source = File.readlines(File.join(root, 'websieve/manifest.txt'), chomp: true)
                 .reject { |path| path.empty? || path.start_with?('#') }
                 .map { |path| File.read(File.join(root, 'websieve', path)) }.join("\n")
    page.add_script_tag(content: source.sub('})(window);', 'window.__readerHeader = sourceOwnedReaderHeaderContent; })(window);'))
  end

  def reader_header_candidate(html = reader_header_body)
    { title: 'Restoring the river', html: html, readerMode: true, contentType: 'article', excerpt: 'A useful body lead.' }
  end

  it 'restores owned taxonomy, reading time, headline and lead without copying site or hidden controls' do
    with_url_page('https://reports.example/river', reader_header_page) do |page|
      original_body = page.evaluate('document.body.innerHTML')
      reader_header_probe(page)
      result = page.evaluate("window.__readerHeader(#{JSON.generate(reader_header_candidate)})")

      expect(result.fetch('html')).to include('<h1>Restoring the river</h1>', '4 min read', 'A complete guide to restoring the river.')
      expect(result.fetch('markdown')).to include('[Science](https://reports.example/science)')
      expect(result.fetch('markdown')).not_to include('Hidden promotion', 'Share this story', 'Unrelated site navigation')
      expect(result.fetch('excerpt')).to eq('A useful body lead.')
      expect(result.fetch('html').index('A complete guide')).to be < result.fetch('html').index('The river restoration')
      expect(page.evaluate('document.body.innerHTML')).to eq(original_body)
      expect(page.evaluate("window.__readerHeader(#{JSON.generate(result)})")).to eq(result)
    end
  end

  it 'keeps separate equal header and body paragraphs while avoiding duplicate restored header copies' do
    lead = 'The river restoration team returned to measure the water.'
    with_url_page('https://reports.example/river', reader_header_page(lead: lead)) do |page|
      reader_header_probe(page)
      [reader_header_body, "<p>#{lead}</p>#{reader_header_body}"].each do |selected|
        result = page.evaluate("window.__readerHeader(#{JSON.generate(reader_header_candidate(selected))})")
        expect(result.fetch('html').scan(lead).length).to eq(2)
        expect(result.fetch('html').scan('Engineers recorded improved flow').length).to eq(1)
      end
    end
  end

  it 'rejects foreign prose, conflicting article headings, hidden headers and competing owners' do
    with_url_page('https://reports.example/river', reader_header_page) do |page|
      original_body = page.evaluate('document.body.innerHTML')
      reader_header_probe(page)
      candidate = reader_header_candidate("<p>This report belongs to an unrelated publication.</p>#{reader_header_body}")
      expect(page.evaluate("window.__readerHeader(#{JSON.generate(candidate)})")).to eq(candidate.transform_keys(&:to_s))

      candidate = reader_header_candidate
      changes = [
        "document.querySelector('article').insertAdjacentHTML('beforeend', '<h1>A different report</h1>')",
        "document.querySelector('article > header').style.visibility = 'hidden'",
        "document.querySelector('main').appendChild(document.querySelector('article').cloneNode(true))"
      ]
      changes.each do |change|
        page.evaluate("document.body.innerHTML = #{JSON.generate(original_body)}")
        page.evaluate(change)
        expect(page.evaluate("window.__readerHeader(#{JSON.generate(candidate)})")).to eq(candidate.transform_keys(&:to_s))
      end
    end
  end

  it 'recovers the complete header through the ordinary generic article pipeline' do
    extract_from_url('https://reports.example/river', reader_header_page) do |payload|
      expect(payload['hostAware']).to be(false)
      expect(payload['html']).to include('<h1>Restoring the river</h1>', '4 min read', 'A complete guide to restoring the river.')
      expect(payload['markdown'].scan('# Restoring the river').length).to eq(1)
      expect(payload['markdown']).to include('[Science](https://reports.example/science)', 'Engineers recorded improved flow')
    end
  end

  it 'uses the complete, explicitly marked owned header lead as its excerpt' do
    details = 'Detailed reporting. ' * 18
    lead = "A complete guide to <a href='/rivers'>restoring rivers</a> explains the evidence. #{details}"
    %w[article-excerpt story-summary standfirst dek].each do |marker|
      html = reader_header_page(lead: lead).sub("<p>#{lead}</p>", "<p class='#{marker}'>#{lead}</p>")
      extract_from_url('https://reports.example/river', html) do |payload|
        expected = "A complete guide to restoring rivers explains the evidence. #{details}".strip
        expect(payload['excerpt']).to eq(expected)
        expect(payload['markdown']).to include('[restoring rivers](https://reports.example/rivers)')
        expect(payload['markdown']).to include('Engineers recorded improved flow')
      end
    end
  end

  it 'keeps the existing excerpt when marked header descriptions are hidden, ambiguous or before the headline' do
    lead = 'A complete guide to restoring the river.'
    variants = [
      "<p class='summary' hidden>#{lead}</p>",
      "<p class='summary'>#{lead}</p><p itemprop='description'>A different summary.</p>"
    ].map { |replacement| reader_header_page.sub("<p>#{lead}</p>", replacement) }
    variants << reader_header_page.sub('<h1>Restoring the river</h1>', '').sub(
      "<p>#{lead}</p>", "<p class='summary'>#{lead}</p><h1>Restoring the river</h1>"
    )
    variants.each do |html|
      with_url_page('https://reports.example/river', html) do |page|
        reader_header_probe(page)
        result = page.evaluate("window.__readerHeader(#{JSON.generate(reader_header_candidate)})")
        expect(result.fetch('excerpt')).to eq('A useful body lead.')
      end
    end
  end
end
