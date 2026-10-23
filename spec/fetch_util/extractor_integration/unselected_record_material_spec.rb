# frozen_string_literal: true

require 'nokogiri'
require 'uri'

RSpec.describe 'Complete unselected physical record material' do
  include_context 'extractor integration helpers'

  def publication_record(number, extra = '')
    <<~HTML
      <article><a href="/publications/#{number}"><h3>Primary publication report #{number}</h3></a>#{extra}</article>
    HTML
  end

  def publication_collection(middle, outside = '')
    <<~HTML
      <html><head><title>Independent publication collections</title></head><body><main>
        <h1>Independent publication collections</h1>
        <section><h2>Opening publications</h2>#{publication_record(1)}#{publication_record(2)}</section>
        <div class="alternate-layout">#{middle}</div>
        <section><h2>Later publications</h2>#{publication_record(3)}#{publication_record(4)}</section>
      </main>#{outside}</body></html>
    HTML
  end

  def materialized_references(markdown)
    markdown.scan(%r{\]\((https?://[^)]+)\)|href="(https?://[^"]+)"}).flatten.compact
  end

  it 'retains every independent article and rich table between named sections in source order' do
    middle = publication_record(1, '<span class="byline"><a rel="author" href="/authors/ari">Ari Reader</a></span>') +
             publication_record(1, '<span class="byline"><a rel="author" href="/authors/bo">Bo Editor</a></span>') +
             '<table><tr><td><a href="/publications/2"><h5>Primary publication report 2</h5></a></td>' \
             '<td><a rel="author" href="/authors/cy">Cy Writer</a></td></tr></table>'
    html = publication_collection(middle)
    url = 'https://collections.publication.example.test/archive'

    with_url_page(url, html) do |page|
      before = page.evaluate('document.body.outerHTML')
      result = extract_payload(page)
      markdown = result.fetch('markdown')
      source = Nokogiri::HTML5(html)
      native = Nokogiri::HTML5.fragment(result.fetch('html'))
      table = Nokogiri::HTML5.fragment(markdown).at_css('table')

      expect(result['contentType']).to eq('list')
      expect(markdown.scan(/^### \[Primary publication report (\d)\]/).flatten).to eq(%w[1 2 1 1 3 4])
      expect(table.at_css('h5').text).to eq('Primary publication report 2')
      expect(table.css('td').map(&:text)).to eq(['Primary publication report 2', 'Cy Writer'])
      expect(materialized_references(markdown)).to eq(source.css('a[href]').map { |link| URI.join(url, link['href']).to_s })
      expect(native.css('h1,h2,h3,h5').map(&:text)).to eq(source.css('h1,h2,h3,h5').map(&:text))
      expect(markdown.index('Bo Editor')).to be < markdown.index('<table>')
      expect(markdown.index('</table>')).to be < markdown.index('## Later publications')
      expect(result.values_at('byline', 'publishedTime')).to eq([nil, nil])
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
    end
  end

  it 'keeps two independently materialized identical articles rather than deduplicating their text or URI' do
    copy = publication_record(1, '<p>The independently owned complete explanation.</p><a rel="author" href="/authors/ari">Ari Reader</a>')

    with_url_page('https://collections.publication.example.test/archive', publication_collection(copy + copy)) do |page|
      before = page.evaluate('document.body.outerHTML')
      result = extract_payload(page)
      markdown = result.fetch('markdown')

      expect(markdown.scan('The independently owned complete explanation.').length).to eq(2)
      expect(markdown.scan('[Ari Reader](https://collections.publication.example.test/authors/ari)').length).to eq(2)
      expect(markdown.scan(/^### \[Primary publication report 1\]/).length).to eq(3)
      expect(result.values_at('byline', 'publishedTime')).to eq([nil, nil])
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
    end
  end

  it 'retains complete programs, linked media and visible time declarations without opening hidden material' do
    first = publication_record(1, <<~HTML)
      <p>The complete separately owned explanation remains visible.</p>
      <time datetime="2026-10-23"><em>Friday morning</em></time>
      <pre><code>const record = "&lt;p&gt;literal&lt;/p&gt;";
      next(record);</code></pre>
      <a href="/covers/first"><img src="/images/first.png" alt="Independent publication illustration"></a>
      <a href="/guides/first">Complete publication guide</a>
      <details><summary>Supplementary publication material</summary><p>Closed publication body stays hidden.</p></details>
    HTML
    hidden = '<article hidden><h3><a href="/hidden">Hidden publication title</a></h3><pre>Hidden program</pre></article>'
    middle = first + hidden + publication_record(2, '<p>Second independent complete explanation.</p>')

    with_url_page('https://collections.publication.example.test/archive', publication_collection(middle)) do |page|
      before = page.evaluate('document.body.outerHTML')
      result = extract_payload(page)
      markdown = result.fetch('markdown')

      expect(markdown).to include('The complete separately owned explanation remains visible.', 'Second independent complete explanation.')
      expect(markdown.scan('Friday morning').length).to eq(1)
      expect(markdown.scan('2026-10-23').length).to eq(1)
      expect(markdown).to include("const record = \"<p>literal</p>\";\nnext(record);")
      expect(markdown.scan('const record').length).to eq(1)
      expect(markdown).to include(
        '[![Independent publication illustration](https://collections.publication.example.test/images/first.png)](https://collections.publication.example.test/covers/first)',
        '[Complete publication guide](https://collections.publication.example.test/guides/first)', 'Supplementary publication material'
      )
      expect(markdown).not_to include('Hidden publication title', 'Hidden program', 'Closed publication body stays hidden.')
      expect(result.values_at('byline', 'publishedTime')).to eq([nil, nil])
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
    end
  end

  it 'keeps articles owned by explicit interface regions outside the retained publications' do
    interfaces = '<aside><article><h3><a href="/aside">Unrelated aside publication</a></h3></article></aside>' \
                 '<nav><article><h3><a href="/navigation">Navigation publication</a></h3></article></nav>'
    outside = '<nav><article><h3><a href="/outside">Outside main publication</a></h3></article></nav>'

    with_url_page('https://collections.publication.example.test/archive', publication_collection(interfaces, outside)) do |page|
      before = page.evaluate('document.body.outerHTML')
      result = extract_payload(page)

      expect(result['markdown']).to include('Primary publication report 1', 'Primary publication report 4')
      expect(result['markdown']).not_to include('Unrelated aside publication', 'Navigation publication', 'Outside main publication')
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
    end
  end

  it 'retains complete records when a separately titled author record activates supplemental section coverage' do
    first = publication_record(1, '<span class="byline"><a rel="author" href="/authors/ari">Ari Reader</a></span>')
    distinct = publication_record(2, '<span class="byline"><a rel="author" href="/authors/nia">Nia Writer</a></span>')
               .sub('Primary publication report 2', 'Independent report sharing publication 2')
    table = '<table><tr><td><a href="/publications/2"><h5>Primary publication report 2</h5></a></td>' \
            '<td><a rel="author" href="/authors/cy">Cy Writer</a></td></tr></table>'
    html = publication_collection(first + distinct + table)
    url = 'https://collections.publication.example.test/archive'

    with_url_page(url, html) do |page|
      before = page.evaluate('document.body.outerHTML')
      result = extract_payload(page)
      markdown = result.fetch('markdown')
      source = Nokogiri::HTML5(html)
      retained_table = Nokogiri::HTML5.fragment(markdown).at_css('table')

      expect(markdown.scan(/^### \[([^\]]+)\]/).flatten).to eq(source.css('h3').map(&:text))
      expect(materialized_references(markdown)).to eq(source.css('a[href]').map { |link| URI.join(url, link['href']).to_s })
      expect(retained_table.at_css('h5').text).to eq('Primary publication report 2')
      expect(retained_table.css('td').map(&:text)).to eq(['Primary publication report 2', 'Cy Writer'])
      expect(markdown.index('Ari Reader')).to be < markdown.index('Independent report sharing publication 2')
      expect(markdown.index('Nia Writer')).to be < markdown.index('<table>')
      expect(markdown.index('</table>')).to be < markdown.index('## Later publications')
      expect(result.values_at('byline', 'publishedTime')).to eq([nil, nil])
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
    end
  end

  it 'keeps a heading and its independently authored sibling text within their one physical anchor' do
    middle = publication_record(1, '<a rel="author" href="/authors/ari">Ari Reader</a>')
             .sub('</h3></a>', '</h3><span>Bulletin</span></a>')

    with_url_page('https://collections.publication.example.test/archive', publication_collection(middle)) do |page|
      before = page.evaluate('document.body.outerHTML')
      result = extract_payload(page)
      rich = Nokogiri::HTML5.fragment(result.fetch('markdown')).at_css('article a[href="https://collections.publication.example.test/publications/1"]')

      expect(rich).not_to be_nil
      expect(rich.element_children.map(&:name)).to eq(%w[h3 span])
      expect(rich.text).to eq('Primary publication report 1Bulletin')
      expect(rich.at_css('h3').text).to eq('Primary publication report 1')
      expect(rich.at_css('span').text).to eq('Bulletin')
      expect(materialized_references(result.fetch('markdown'))).to eq(
        [
          'https://collections.publication.example.test/publications/1',
          'https://collections.publication.example.test/publications/2',
          'https://collections.publication.example.test/publications/1',
          'https://collections.publication.example.test/authors/ari',
          'https://collections.publication.example.test/publications/3',
          'https://collections.publication.example.test/publications/4'
        ]
      )
      expect(result.values_at('byline', 'publishedTime')).to eq([nil, nil])
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
    end
  end

  it 'keeps an independently authored attribution inside its complete raw article across blank HTML lines' do
    body = "\n\n<span class=\"byline\"><a rel=\"author\" href=\"/authors/ari\">Ari Reader</a></span>"
    middle = publication_record(1, body).sub('</h3></a>', '</h3><span>Bulletin</span></a>')

    with_url_page('https://collections.publication.example.test/archive', publication_collection(middle)) do |page|
      before = page.evaluate('document.body.outerHTML')
      result = extract_payload(page)
      raw = Nokogiri::HTML5.fragment(result.fetch('markdown')).at_css('article')

      expect(raw).not_to be_nil
      expect(raw.css('[rel="author"]').map(&:text)).to eq(['Ari Reader'])
      expect(raw.at_css('a[href="https://collections.publication.example.test/publications/1"]').text)
        .to eq('Primary publication report 1Bulletin')
      expect(result.fetch('markdown').split('</article>', 2).last)
        .to match(/\A(?:&#(?:10|13);|[ \t])*\n\n\#{1,6} /)
      expect(materialized_references(result.fetch('markdown')).length).to eq(6)
      expect(result.values_at('byline', 'publishedTime')).to eq([nil, nil])
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
    end
  end
end
