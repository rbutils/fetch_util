# frozen_string_literal: true

require 'nokogiri'

RSpec.describe 'Complete physical manual authored repetition' do
  include_context 'extractor integration helpers'

  it 'retains every independently authored field reference and version clause in Markdown' do
    fields = (1..160).map do |number|
      "<dt>FIELD_#{number}</dt><dd><p>Published definition #{number}.</p>" \
        '<p>See the <a href="#builder">Package builder</a>.</p><p>New in version 4.4</p></dd>'
    end.join
    body = '<article role="main"><h1>Example Language Reference Manual</h1><h2>Published fields</h2>' \
           '<p>The complete reference records every separately published definition and example.</p>' \
           "<dl>#{fields}</dl><h2 id=\"builder\">Package builder</h2>" \
           '<pre><code class="language-example">build(example);</code></pre></article>'
    with_url_page('https://publication.example.test/reference/manual', body) do |page|
      page.evaluate('document.title = "Example Language Reference Manual"')
      payload = FetchUtil::Extractor.new.extract(page)
      markdown = payload.fetch('markdown')
      expect(markdown.scan('New in version 4.4').size).to eq(160)
      expect(markdown.scan('Package builder').size).to eq(161)
      (1..160).each { |number| expect(markdown).to include("Published definition #{number}.") }
    end
  end

  it 'retains literal angle prose and adjoining inline code across a destination-less named anchor' do
    body = '<article role="main"><h1>Example Language Reference Manual</h1><h2>Published literals</h2>' \
           '<p>An include statement uses #include &lt;Fmwk/Header.h&gt; and keeps its complete argument.</p>' \
           '<p><a name="contact">The published contact is <code class="email">&lt;</code></a>' \
           '<code class="email"><a class="email">person@publication.example.test</a>&gt;</code>.</p>' \
           '<pre><code class="language-example">include(example);</code></pre></article>'
    with_url_page('https://publication.example.test/reference/literals', body) do |page|
      page.evaluate('document.title = "Example Language Reference Manual"')
      payload = FetchUtil::Extractor.new.extract(page)
      expect(payload.fetch('markdown')).to include('\\<Fmwk/Header.h>')
      expect(payload.fetch('markdown')).to include('`<person@publication.example.test>`')
      expect(payload.fetch('html')).to include('name="contact"', '&lt;Fmwk/Header.h&gt;')
    end
  end

  it 'preserves source whitespace, distinct code attributes and genuine references between code fragments' do
    body = '<article role="main"><h1>Example Language Reference Manual</h1><h2>Published boundaries</h2>' \
           '<p>Separate expressions are <code>left</code> <code>right</code> and retain their source spacing.</p>' \
           '<p>Different expressions are <code class="one">alpha</code> <code class="two">beta</code>.</p>' \
           '<p>Published references are <code>term</code><a href="https://publication.example.test/definitions">definition</a>' \
           '<code>suffix</code> and keep their destination.</p>' \
           '<pre><code class="language-example">read(example);</code></pre></article>'
    with_url_page('https://publication.example.test/reference/boundaries', body) do |page|
      page.evaluate('document.title = "Example Language Reference Manual"')
      markdown = FetchUtil::Extractor.new.extract(page).fetch('markdown')
      expect(markdown).to include('`left` `right`', '`alpha` `beta`', 'https://publication.example.test/definitions')
    end
  end

  it 'retains nested literal placeholders and adjacent presentation-only code classes as complete expressions' do
    body = '<article role="main"><h1>Example Language Reference Manual</h1><h2>Published expressions</h2>' \
           '<p>The default filename is <code class="filename"><code class="variable">$DOMAIN</code>.pot</code>.</p>' \
           '<p>The search expression is <code class="variable">env</code><code class="literal">[\'ENV\'][\'PATH\']</code>.</p>' \
           '<p>The replacement expression is <code class="literal">${<em><code>expression</code></em>}</code>.</p>' \
           '<pre><code class="language-example">read(example);</code></pre></article>'
    with_url_page('https://publication.example.test/reference/expressions', body) do |page|
      page.evaluate('document.title = "Example Language Reference Manual"')
      payload = FetchUtil::Extractor.new.extract(page)
      expect(payload.fetch('markdown')).to include('`$DOMAIN.pot`', '`env[\'ENV\'][\'PATH\']`', '`${expression}`')
      expect(payload.fetch('html')).to include('class="filename"', 'class="variable"', '<em><code>expression</code></em>')
    end
  end

  it 'retains complete literal programs inside table cells and ordinary comparison signs' do
    rows = (1..160).map do |number|
      "<tr><td>Example #{number}</td><td><pre><code>vector&lt;T&gt; value_#{number}; consume(value_#{number});</code></pre></td></tr>"
    end.join
    body = '<article role="main"><h1>Example Language Reference Manual</h1><h2>Published table programs</h2>' \
           '<p>The published lineage is <code>Root &gt; Branch &gt; Leaf</code>.</p>' \
           '<table><tr><th>Example</th><th>Program</th></tr>' + rows + '</table>' \
           '<pre><code class="language-example">read(example);</code></pre></article>'
    with_url_page('https://publication.example.test/reference/table-programs', body) do |page|
      page.evaluate('document.title = "Example Language Reference Manual"')
      before_html = page.evaluate('document.body.innerHTML')
      payload = FetchUtil::Extractor.new.extract(page)
      markdown = payload.fetch('markdown')
      rendered = Nokogiri::HTML.fragment(markdown)
      expect(rendered.css('table').length).to eq(1)
      table = rendered.at_css('table')
      expect(table.css('tr').length).to eq(161)
      expect(table.css('th').map(&:text)).to eq(%w[Example Program])
      expect(table.css('td').length).to eq(320)
      expect(table.css('pre').length).to eq(160)
      expect(table.css('code').length).to eq(160)
      expect(table.css('a, img')).to be_empty
      programs = (1..160).map { |number| "vector<T> value_#{number}; consume(value_#{number});" }
      table.css('tr').drop(1).each_with_index do |row, index|
        expect(row.element_children.map(&:name)).to eq(%w[td td])
        expect(row.element_children.first.text).to eq("Example #{index + 1}")
        expect(row.element_children.last.element_children.map(&:name)).to eq(['pre'])
        expect(row.css('pre code').map(&:text)).to eq([programs.fetch(index)])
      end
      native = Nokogiri::HTML.fragment(payload.fetch('html'))
      expect(native.css('pre code').map(&:text)).to eq(programs + ['read(example);'])
      expect(markdown.scan('read(example);').length).to eq(1)
      expect(markdown).to match(/(?:^|\n)(`{3,}|~{3,})[^\n]*\nread\(example\);\n\1(?:\n|$)/)
      expect(markdown).to include('`Root > Branch > Leaf`')
      expect(payload.fetch('html')).to include('vector&lt;T&gt; value_160;', 'Root &gt; Branch &gt; Leaf')
      expect(page.evaluate('document.body.innerHTML')).to eq(before_html)
    end
  end
end
