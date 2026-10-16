require "support/extractor_integration_helpers"

RSpec.describe FetchUtil::Extractor do
  include_context "extractor integration helpers"

  def render_mixed_table_cells(cells)
    root = File.expand_path("../../..", __dir__)
    source = File.readlines("#{root}/websieve/manifest.txt").map(&:strip)
                 .reject { |path| path.empty? || path.start_with?("#") }
                 .map { |path| File.read("#{root}/websieve/#{path}") }.join("\n")
    source = source.sub("})(window);", "global.__tableInline = tableCellMarkdown; })(window);")
    html = "<html><body><table><tr>#{cells.map { |cell| "<td>#{cell}</td>" }.join}</tr></table></body></html>"
    with_url_page("https://records.example/table", html) do |page|
      page.add_script_tag(content: source)
      page.evaluate(<<~JS)
        (() => {
          const table = document.querySelector('table'), original = table.outerHTML;
          const cells = Array.from(table.querySelectorAll('td')).map(__tableInline);
          const links = Array.from(table.querySelectorAll('a')).map(link => [link.textContent, link.href]);
          return {cells, links, unchanged: table.outerHTML === original};
        })()
      JS
    end
  end

  it "retains contiguous source words without extending reference labels or destinations" do
    result = render_mixed_table_cells(
      [
        "Refe<a href='/manual'>ren</a>ce",
        "<a href='/review'>Review</a>er",
        "A<span>l<span>p</span>h</span>a",
        "dé<em>jà</em>-<strong>vu</strong>",
        "pre<!-- source annotation --><a href='/fix'>fix</a>"
      ]
    )
    expect(result.fetch("cells")).to eq(
      [
        "Refe[ren](https://records.example/manual)ce",
        "[Review](https://records.example/review)er", "Alpha", "déjà-vu",
        "pre[fix](https://records.example/fix)"
      ]
    )
    expect(result.fetch("links")).to eq(
      [
        ["ren", "https://records.example/manual"], ["Review", "https://records.example/review"],
        ["fix", "https://records.example/fix"]
      ]
    )
    expect(result.fetch("unchanged")).to be(true)
  end

  it "preserves explicit edge whitespace on text, references and literal code" do
    result = render_mixed_table_cells(
      [
        "A<a href='/notes'> notes </a>B", "A <a href='/notes'>notes</a> B",
        "A<code> value </code>B", "Option<code>&lt;T&gt;</code>!",
        "A<code> \t </code>B", "A<code></code>B",
        "Read\n\t<a href='/query?mode=a|b'>[guide]</a>\u00a0today"
      ]
    )
    expect(result.fetch("cells")).to eq(
      [
        "A [notes](https://records.example/notes) B", "A [notes](https://records.example/notes) B",
        "A `value` B", "Option`<T>`!", "A B", "AB",
        "Read [\\[guide\\]](https://records.example/query?mode=a%7Cb) today"
      ]
    )
    expect(result.fetch("unchanged")).to be(true)
  end

  it "keeps semantic block boundaries and complete fenced values in mixed cells" do
    result = render_mixed_table_cells(
      [
        "<h3>Field</h3><span>value</span>", "<p>First</p><p>Second</p>", "first<br>second",
        "<ul><li>One</li><li>Two</li></ul><span>Three</span>",
        "<span>before</span><pre>value</pre><span>after</span>",
        "<blockquote>Quote</blockquote><span>detail</span>", "prefix<code>A``B</code>suffix", "A<pre></pre>B"
      ]
    )
    expect(result.fetch("cells")).to eq(
      [
        "Field value", "First Second", "first second", "One Two Three", "before `value` after",
        "Quote detail", "prefix```A``B```suffix", "A B"
      ]
    )
    expect(result.fetch("unchanged")).to be(true)
  end
end
