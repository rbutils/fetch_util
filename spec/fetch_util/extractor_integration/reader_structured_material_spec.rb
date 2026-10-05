require "digest"
require "nokogiri"
require "uri"

RSpec.describe "Reader structured material fidelity" do
  include_context 'extractor integration helpers'

  def full_source
    fixture_contents(File.expand_path('../../fixtures/large_article_structured_material.html', __dir__))
  end

  def normalized_text(value)
    value.to_s.gsub(/\s+/, " ").strip
  end

  def ordered_table_rows(table)
    table.css("tr").map do |row|
      row.css("th, td").map { |cell| normalized_text(cell.text) }
    end
  end

  def expect_ordered_values(values, content)
    cursor = 0
    values.each do |value|
      position = content.index(value, cursor)
      expect(position).not_to be_nil, "missing or out-of-order content: #{value.inspect}"
      cursor = position + value.length
    end
  end

  def prose(marker)
    Array.new(12) do |index|
      "<p>#{marker}-PARAGRAPH-#{format("%02d", index + 1)} describes the field review, its recorded measurements, " \
        "the independent observations, and the reason each result remains part of this article.</p>"
    end.join
  end

  def synthetic_owner(order:)
    code = '<section><h2>Owned executable example</h2><pre><code>const ownedExample = "FD01-OWNED-CODE";</code></pre></section>'
    table = <<~HTML
      <section><h2>Owned measurements</h2><table>
        <thead><tr><th>Item</th><th>Value</th></tr></thead>
        <tbody><tr><td>FD01-OWNED-ROW-01</td><td>FD01-OWNED-CELL-01</td></tr>
        <tr><td>FD01-OWNED-ROW-02</td><td>FD01-OWNED-CELL-02</td></tr></tbody>
      </table></section>
    HTML
    blocks = {
      'code' => code,
      'narrative' => "<section><h2>Owned narrative</h2>#{prose("FD01-SYNTHETIC")}</section>",
      'table' => table
    }
    <<~HTML
      <!doctype html><html><head><title>FD01 synthetic article</title></head><body>
        <main><div itemprop="articleBody"><h1>FD01 synthetic article</h1>
          #{order.map { |part| blocks.fetch(part) }.join}
        </div></main>
      </body></html>
    HTML
  end

  it "recovers every structured region from the frozen original document" do
    source = full_source
    expect(source.bytesize).to eq(172_643)
    expect(Digest::SHA256.hexdigest(source)).to eq('6974878b74de879814ff2926d7883dad578134f7903f206625e94208db015d3b')

    page_url = "https://fd01.test/reviews/longitudinal"
    source_article = Nokogiri::HTML(source).at_css("article")
    expected_paragraphs = source_article.css("p").map { |paragraph| normalized_text(paragraph.text) }
    expected_code = source_article.at_css("pre").text
    expected_code_lines = expected_code.lines.map(&:chomp)
    expected_rows = ordered_table_rows(source_article.at_css("table"))
    expected_links = source_article.css("a[href]").map do |link|
      [normalized_text(link.text), URI.join(page_url, link["href"]).to_s]
    end

    with_url_page(page_url, source) do |page|
      payload = extract_payload(page, reader_mode: true)
      html = Nokogiri::HTML.fragment(payload.fetch('html'))
      markdown = payload.fetch('markdown')

      expect(payload['contentType']).to eq('article')
      expect(payload['title']).to eq('Longitudinal Field Review')
      expect(expected_paragraphs.length).to eq(501)
      expect(expected_code_lines.length).to eq(32)
      expect(expected_rows.length).to eq(41)
      expect(expected_links.length).to eq(25)
      expect(html.css("p").map { |paragraph| normalized_text(paragraph.text) }).to eq(expected_paragraphs)
      expect(html.css("pre").map(&:text)).to eq([expected_code])
      expect(ordered_table_rows(html.at_css("table"))).to eq(expected_rows)
      actual_links = html.css("a[href]").map { |link| [normalized_text(link.text), link["href"]] }
      expect(actual_links).to eq(expected_links)

      markdown_code = markdown.scan(/^```[^\n]*\n(.*?)^```[ \t]*$/m).flatten.map { |block| block.sub(/\n\z/, "") }
      expect(markdown_code).to eq([expected_code.sub(/\n+\z/, "")])
      expect(markdown_code.first.lines.map(&:chomp)).to eq(expected_code_lines)
      markdown_rows = markdown.lines.filter_map do |line|
        next unless line.match?(/^\|.*\|\s*$/)

        cells = line.strip.delete_prefix("|").delete_suffix("|").split("|").map(&:strip)
        next if cells.all? { |cell| cell.match?(/\A:?-+:?\z/) }

        cells
      end
      expect(markdown_rows).to eq(expected_rows)
      markdown_links = markdown.scan(/\[([^\]]+)\]\(([^)]+)\)/).map do |label, href|
        [normalized_text(label), href]
      end
      expect(markdown_links).to eq(expected_links)

      expected_html_order = expected_paragraphs + expected_code_lines + expected_rows.flatten + expected_links.map(&:first)
      expect_ordered_values(expected_html_order, normalized_text(html.text))
      expected_markdown_order = expected_paragraphs + expected_code_lines +
                                expected_rows.map { |row| "| #{row.join(" | ")} |" } +
                                expected_links.map { |label, href| "[#{label}](#{href})" }
      expect_ordered_values(expected_markdown_order, markdown)
      expected_text_order = expected_paragraphs + expected_code_lines + expected_rows.flatten + expected_links.map(&:first)
      expect_ordered_values(expected_text_order, payload.fetch("textContent"))
      (expected_code_lines + expected_rows.flatten + expected_links.map(&:first)).each do |value|
        expect(payload.fetch("textContent")).to include(value)
      end
    end
  end

  it "recovers code-first, interleaved, and table-after content under a different semantic body owner" do
    [
      %w[code narrative table],
      %w[narrative code table],
      %w[narrative table code]
    ].each do |order|
      with_url_page('https://fd01.test/synthetic', synthetic_owner(order: order)) do |page|
        payload = extract_payload(page, reader_mode: true)
        html = Nokogiri::HTML.fragment(payload.fetch('html'))
        expect(payload['contentType']).to eq('article')
        expect(html.text).to include('FD01-OWNED-CODE', 'FD01-OWNED-ROW-01', 'FD01-OWNED-CELL-02')
        expect(html.css('pre').length).to eq(1)
        expect(html.css('table tr').length).to eq(3)
        code_position = html.text.index('FD01-OWNED-CODE')
        row_position = html.text.index('FD01-OWNED-ROW-01')
        expect(code_position < row_position).to eq(order.index('code') < order.index('table'))
      end
    end
  end

  it "cleans plain navigation and furniture inside a recovered article owner" do
    source_document = Nokogiri::HTML(full_source)
    source_document.at_css("article").add_child(Nokogiri::HTML.fragment(<<~HTML))
      <nav><pre>FD01-INNER-NAV-CODE</pre></nav>
      <aside><table><tbody><tr><td>FD01-INNER-ASIDE-TABLE</td></tr></tbody></table></aside>
      <footer><pre>FD01-INNER-FOOTER-CODE</pre></footer>
      <form><table><tbody><tr><td>FD01-INNER-FORM-TABLE</td></tr></tbody></table></form>
      <section hidden><pre>FD01-HIDDEN-CODE</pre><table><tr><td>FD01-HIDDEN-TABLE</td></tr></table></section>
      <section aria-hidden="true"><pre>FD01-ARIA-HIDDEN-CODE</pre></section>
      <section style="opacity:0"><pre>FD01-OPAQUE-HIDDEN-CODE</pre></section>
      <demo-share>Share</demo-share>
      <x-related-article>أخبار ذات صلة</x-related-article>
      <supplement-share>Share the full field review, including its method, complete observations, and results.</supplement-share>
      <material-related-article><a href="/material-context">FD01 contextual field record</a></material-related-article>
    HTML
    source_document.at_css("main").add_child(Nokogiri::HTML.fragment(<<~HTML))
      <nav><pre>FD01-NAV-CODE</pre><a href="/nav">FD01 navigation</a></nav>
      <aside><h2>FD01-ASIDE</h2><table><tr><td>FD01-TABLE-AS-LIST</td></tr></table></aside>
      <article><h2><a href="/foreign">FD01-FOREIGN-ARTICLE</a></h2><p>FD01 foreign record</p></article>
      <section class="related-records"><article><h2>FD01 nested foreign article</h2><p>FD01-NESTED-FOREIGN-ARTICLE</p></article></section>
    HTML

    with_url_page("https://fd01.test/owner-isolation", source_document.to_html) do |page|
      payload = extract_payload(page, reader_mode: true)
      output = Nokogiri::HTML.fragment(payload.fetch("html"))
      expect(payload['contentType']).to eq('article')
      expect(output.text).to include("CODE-CELL-001", "TABLE-ROW-001")
      expect(output.css("demo-share, x-related-article")).to be_empty
      expect(output.text).to include("Share the full field review", "FD01 contextual field record")
      expect(output.at_css('a[href="https://fd01.test/material-context"]')).not_to be_nil
      expect(payload['markdown']).not_to include(
        'FD01-INNER-NAV-CODE', 'FD01-INNER-ASIDE-TABLE', 'FD01-INNER-FOOTER-CODE', 'FD01-INNER-FORM-TABLE',
        'FD01-HIDDEN-CODE', 'FD01-HIDDEN-TABLE', 'FD01-ARIA-HIDDEN-CODE',
        'FD01-OPAQUE-HIDDEN-CODE', 'FD01-NAV-CODE', 'FD01 navigation',
        'FD01-ASIDE', 'FD01-TABLE-AS-LIST', 'FD01-RELATED-RECORDS',
        'FD01 unrelated story', 'FD01-FOREIGN-ARTICLE', 'FD01-NESTED-FOREIGN-ARTICLE'
      )
    end
  end

  it "does not borrow code or table material from an unrelated rail when owned prose is complete" do
    html = <<~HTML
      <main>
        <article><div itemprop="articleBody"><h1>FD01 unchanged owner</h1>#{prose("FD01-UNCHANGED")}</div></article>
        <aside><pre><code>FD01-UNRELATED-CODE</code></pre><table><tr><td>FD01-UNRELATED-CELL</td></tr></table></aside>
      </main>
    HTML

    with_url_page("https://fd01.test/unchanged-owner", html) do |page|
      payload = extract_payload(page, reader_mode: true)
      output = Nokogiri::HTML.fragment(payload.fetch("html"))
      expected_paragraphs = Nokogiri::HTML(html).css("article p").map { |paragraph| normalized_text(paragraph.text) }

      expect(output.css("p").map { |paragraph| normalized_text(paragraph.text) }).to eq(expected_paragraphs)
      expect(output.css("pre, table")).to be_empty
      expect(payload.fetch("markdown")).not_to include("FD01-UNRELATED-CODE", "FD01-UNRELATED-CELL")
    end
  end

  it "does not treat empty owned structures as a reason to add unrelated rail material" do
    html = <<~HTML
      <main>
        <article><div itemprop="articleBody"><h1>FD01 empty structures</h1>#{prose("FD01-EMPTY")}
          <pre> \n </pre><table><tbody><tr><td> </td><td></td></tr></tbody></table>
        </div></article>
        <aside><pre><code>FD01-EMPTY-RAIL-CODE</code></pre>
          <table><tr><td>FD01-EMPTY-RAIL-ROW</td><td>FD01-EMPTY-RAIL-CELL</td></tr></table>
        </aside>
      </main>
    HTML

    with_url_page("https://fd01.test/empty-structures", html) do |page|
      payload = extract_payload(page, reader_mode: true)
      output = Nokogiri::HTML.fragment(payload.fetch("html"))
      expected_paragraphs = Nokogiri::HTML(html).css("article p").map { |paragraph| normalized_text(paragraph.text) }
      expect(output.css("p").map { |paragraph| normalized_text(paragraph.text) }).to eq(expected_paragraphs)
      expect(output.css("table")).to be_empty
      expect(payload.fetch("markdown")).not_to include(
        "FD01-EMPTY-RAIL-CODE", "FD01-EMPTY-RAIL-ROW", "FD01-EMPTY-RAIL-CELL"
      )
    end
  end

  it "keeps separate semantic owners and repeated source paragraphs distinct" do
    repeated = '<p>FD01-REPEATED-PARAGRAPH This identical observation remains twice because each occurrence belongs to the source article.</p>'
    html = <<~HTML
      <head><meta name="author" content="Ada Example"><meta name="description" content="FD01 source excerpt retained exactly for this article."></head>
      <main>
        <article><h1>FD01 primary headline</h1><p>FD01 byline: Ada Example</p>
          <section><h2>FD01 primary prose</h2>#{repeated}#{repeated}#{prose("FD01-PRIMARY")}
            <pre><code>FD01-PRIMARY-CODE</code></pre>
          </section>
        </article>
        <article><h2>FD01 competing owner</h2><p>FD01 competitor article</p></article>
      </main>
    HTML

    with_url_page('https://fd01.test/primary', html) do |page|
      payload = extract_payload(page, reader_mode: true)
      expect(payload['contentType']).to eq('article')
      expect(payload['title']).to eq('FD01 primary headline')
      expect(payload['byline']).to include('Ada Example')
      expect(payload['excerpt']).to eq(
        'FD01-REPEATED-PARAGRAPH This identical observation remains twice because each occurrence belongs to the source article.'
      )
      expect(payload['markdown']).to include('FD01 byline: Ada Example', 'FD01-PRIMARY-CODE')
      expect(payload['markdown'].scan('FD01-REPEATED-PARAGRAPH').length).to eq(2)
      expect(payload['markdown']).not_to include('FD01 competitor article')
    end
  end
end
