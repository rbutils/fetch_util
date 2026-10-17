require "support/extractor_integration_helpers"

RSpec.describe FetchUtil::Extractor do
  include_context "extractor integration helpers"

  def inspect_table_cell_reads(rows)
    root = File.expand_path("../../..", __dir__)
    source = File.readlines("#{root}/websieve/manifest.txt").map(&:strip)
                 .reject { |path| path.empty? || path.start_with?("#") }
                 .map { |path| File.read("#{root}/websieve/#{path}") }.join("\n")
    raise "ambiguous table renderer namespace" unless source.scan("})(window);").length == 1

    source = source.sub("})(window);", "global.__readTableCell = tableCellMarkdown; })(window);")
    table = rows.map { |cells| "<tr>#{cells.map { |cell| "<td>#{cell}</td>" }.join}</tr>" }.join
    with_url_page("https://records.example.test/series/", "<html><body><table>#{table}</table></body></html>") do |page|
      page.add_script_tag(content: source)
      page.evaluate(<<~JS)
        (() => {
          const table = document.querySelector('table'), before = table.outerHTML;
          let clones = 0;
          const cells = Array.from(table.querySelectorAll('td'));
          cells.forEach(cell => {
            const original = cell.cloneNode;
            Object.defineProperty(cell, 'cloneNode', {
              configurable: true,
              value: function(deep) { clones++; return original.call(this, deep); }
            });
          });
          try {
            return {values: cells.map(__readTableCell), clones, unchanged: table.outerHTML === before};
          } finally {
            cells.forEach(cell => { delete cell.cloneNode; });
          }
        })()
      JS
    end
  end

  it "reads every cell without cloning when no adjacent element pair can exist" do
    rows = (1..603).map do |index|
      [
        "Series #{index}", "<a href='/series/#{index}'>Record #{index}</a>",
        "<span>part<strong>#{index}</strong><em>value</em></span>", "before<code>&lt;#{index}&gt;</code>after"
      ]
    end
    result = inspect_table_cell_reads(rows)
    expected = (1..603).flat_map do |index|
      [
        "Series #{index}", "[Record #{index}](https://records.example.test/series/#{index})",
        "part#{index}value", "before`<#{index}>`after"
      ]
    end
    expect(result.fetch("values")).to eq(expected)
    expect(result.fetch("clones")).to eq(0)
    expect(result.fetch("unchanged")).to be(true)
  end

  it "keeps the existing isolated duplicate-block cleanup when adjacent elements exist" do
    result = inspect_table_cell_reads(
      [
        [
          "<div>Same<a href='/first'>source</a></div><section>Same<a href='/first'>source</a></section>",
          "<div>Same<a href='/first'>source</a></div><div>Same<a href='/second'>source</a></div>",
          "<div>First</div><div>Second</div>"
        ]
      ]
    )
    expect(result.fetch("values")).to eq(
      [
        "Same[source](https://records.example.test/first)",
        "Same[source](https://records.example.test/first) Same[source](https://records.example.test/second)",
        "First Second"
      ]
    )
    expect(result.fetch("clones")).to eq(3)
    expect(result.fetch("unchanged")).to be(true)
  end
end
