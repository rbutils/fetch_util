# frozen_string_literal: true

RSpec.describe 'source-owned material around nested records' do
  include_context 'extractor integration helpers'

  def nested_record_page(before:, after:, middle: false)
    child = <<~HTML
      <article class="inner-card">
        <img src="/inner.png" alt="Inner publication illustration">
        <h3><a href="/records/inner">Independent inner publication</a></h3>
        <p>A shared authored sentence.</p>
        <time datetime="2026-04-12">12 April 2026</time>
      </article>
    HTML
    child = "<article class=\"middle-card\"><p>Middle owner note.</p>#{child}<p>Middle later note.</p></article>" if middle
    peers = %w[second third fourth].map do |name|
      "<section><h2>#{name.capitalize} collection</h2><article><h3>" \
        "<a href=\"/records/#{name}\">Independent #{name} publication</a></h3>" \
        "<p>#{name.capitalize} record description.</p></article></section>"
    end.join
    <<~HTML
      <html lang="en"><head><title>Nested publication collections</title></head><body>
        <main><h1>Nested publication collections</h1>
          <section><h2>First collection</h2><article class="outer-card">
            #{before}
            #{child}
            #{after}
          </article></section>
          #{peers}
        </main>
      </body></html>
    HTML
  end

  it 'preserves the complete original parent without assigning it to its child' do
    html = fixture_contents(File.expand_path('../../fixtures/fidelity_generic_nested_card.html', __dir__))

    with_url_page('https://fidelity.test/', html) do |page|
      body = page.evaluate('document.body.innerHTML')
      markdown = extract_payload(page, reader_mode: false).fetch('markdown')
      values = %w[FID:outer-action FID:outer-image FID:outer-summary FID:inner-title FID:inner-summary FID:inner-image FID:inner-time]

      values.each { |value| expect(markdown.scan(value).length).to eq(1), value }
      expect(markdown).to include('[FID:outer-action](https://fidelity.test/action)')
      expect(markdown.index('FID:outer-action')).to be < markdown.index('FID:outer-image')
      expect(markdown.index('FID:outer-image')).to be < markdown.index('FID:outer-summary')
      expect(markdown.index('FID:outer-summary')).to be < markdown.index('FID:inner-title')
      blocks = markdown.split(/\n\n+/)
      inner_start = blocks.index('![FID:inner-image](https://fidelity.test/inner.jpg)')
      expect(inner_start).not_to be_nil
      inner = blocks.slice(inner_start, 4)
      expect(inner).to eq(
        [
          '![FID:inner-image](https://fidelity.test/inner.jpg)',
          '### [FID:inner-title](https://fidelity.test/story/inner)',
          'FID:inner-summary', 'FID:inner-time'
        ]
      )
      expect(inner.join("\n")).not_to include('FID:outer-action', 'FID:outer-summary', 'FID:outer-image')
      expect(page.evaluate('document.body.innerHTML')).to eq(body)
    end
  end

  it 'retains complete surrounding programs and references in physical order' do
    before = <<~HTML
      <a href="/guide">Guide</a><img src="/outer.png" alt="Outer publication illustration">
      <p>Outer summary.</p><pre><code>before("parent", 1);
      next_step();</code></pre>
    HTML
    after = '<p>Later outer note.</p><a href="/appendix">Appendix</a>'
    html = nested_record_page(before:, after:)

    with_url_page('https://publication.example.test/nested', html) do |page|
      body = page.evaluate('document.body.innerHTML')
      result = extract_payload(page, reader_mode: false)
      markdown = result.fetch('markdown')
      expected = [
        '[Guide](https://publication.example.test/guide)',
        '![Outer publication illustration](https://publication.example.test/outer.png)',
        'Outer summary.', "before(\"parent\", 1);\nnext_step();",
        'Independent inner publication', 'A shared authored sentence.',
        'Later outer note.', '[Appendix](https://publication.example.test/appendix)'
      ]

      expect(result.fetch('contentType')).to eq('list')
      expected.each { |value| expect(markdown.scan(value).length).to eq(1), value }
      positions = expected.map { |value| markdown.index(value) }
      expect(positions).to eq(positions.sort)
      expect(page.evaluate('document.body.innerHTML')).to eq(body)
    end
  end

  it 'keeps independent equal prose, nested owner notes, and disclosure visibility' do
    before = <<~HTML
      <p>A shared authored sentence.</p>
      <div hidden><p>HIDDEN OUTER PARAGRAPH</p><pre>HIDDEN OUTER PROGRAM</pre></div>
    HTML
    after = <<~HTML
      <details><summary>Declared outer resources</summary><p>CLOSED OUTER PARAGRAPH</p><pre>CLOSED OUTER PROGRAM</pre></details>
      <p>Final outer note.</p>
    HTML
    html = nested_record_page(before:, after:, middle: true)

    with_url_page('https://publication.example.test/nested', html) do |page|
      body = page.evaluate('document.body.innerHTML')
      markdown = extract_payload(page, reader_mode: false).fetch('markdown')

      expect(markdown.scan('A shared authored sentence.').length).to eq(2)
      ['Middle owner note.', 'Middle later note.', 'Declared outer resources', 'Final outer note.'].each do |value|
        expect(markdown.scan(value).length).to eq(1), value
      end
      expect(markdown.index('Middle owner note.')).to be < markdown.index('Independent inner publication')
      expect(markdown.index('Middle later note.')).to be > markdown.index('Independent inner publication')
      expect(markdown).not_to include('HIDDEN OUTER PARAGRAPH', 'HIDDEN OUTER PROGRAM', 'CLOSED OUTER PARAGRAPH', 'CLOSED OUTER PROGRAM')
      expect(page.evaluate('document.body.innerHTML')).to eq(body)
    end
  end
end
