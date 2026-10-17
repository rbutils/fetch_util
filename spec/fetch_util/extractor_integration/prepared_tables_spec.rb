require "support/extractor_integration_helpers"

RSpec.describe FetchUtil::Extractor do
  include_context "extractor integration helpers"

  def with_prepared_table_converter
    root = File.expand_path("../../..", __dir__)
    source = File.readlines("#{root}/websieve/manifest.txt").map(&:strip)
                 .reject { |path| path.empty? || path.start_with?("#") }
                 .map { |path| File.read("#{root}/websieve/#{path}") }.join("\n")
    raise "ambiguous table preparation namespace" unless source.scan("})(window);").length == 1

    source = source.sub("})(window);", <<~'JS')
      global.__convertPreparedTable = function(markup, enabled, owned) {
        var root = document.implementation.createHTMLDocument('').createElement('div'), visits = 0;
        root.innerHTML = markup;
        var markdown = convertMarkdownRoot(root, false, true, true, function(service, input) {
          if (!enabled) service.options.fetchUtilPrepareRoot = null;
          service.addRule('countDiscardedCells', {
            filter: 'td',
            replacement: function(content) { visits++; return content; }
          });
          return owned ? service.turndownOwnedRoot(input) : service.turndown(input);
        });
        return {markdown: markdown, visits: visits};
      };
      })(window);
    JS
    with_url_page("https://records.example.test/series/", "<p>Unchanged public source.</p>") do |page|
      described_class.new.send(:inject_vendor_assets, page)
      page.add_script_tag(content: source)
      before = page.evaluate("document.body.innerHTML")
      yield page
      expect(page.evaluate("document.body.innerHTML")).to eq(before)
    end
  end

  it "renders every record once without converting discarded cell descendants" do
    rows = (1..603).map do |index|
      "<tr><td>Series #{index}</td><td><a href='/series/#{index}'>Record #{index}</a></td>" \
        "<td><code>&lt;Type#{index}&gt;</code></td><td>Value #{index}</td></tr>"
    end.join
    markup = "<table><tr><th>Series</th><th>Reference</th><th>Type</th><th>Value</th></tr>#{rows}</table>"
    with_prepared_table_converter do |page|
      result = page.evaluate("__convertPreparedTable(arguments[0], true)", markup)
      expected = (1..603).map do |index|
        "| Series #{index} | [Record #{index}](https://records.example.test/series/#{index}) | `<Type#{index}>` | Value #{index} |"
      end
      expect(result.fetch("markdown").lines.map(&:strip)).to eq(
        ["| Series | Reference | Type | Value |", "| --- | --- | --- | --- |"] + expected
      )
      expect(result.fetch("visits")).to eq(0)
    end
  end

  it "matches the original normalized vendor path for literals, resources and unsupported layouts" do
    fixtures = [
      "<table><tr><th>Code</th><th>Reference</th></tr><tr><td><code>  alpha   beta\n gamma  </code></td>" \
      "<td> before <a href='/one'>first</a> <a href='/two'>second</a> after </td></tr></table>",
      "<table><tr><th>Program</th></tr><tr><td><pre><code class='language-ruby'>first\n&lt;Type&gt;\nlast</code></pre></td></tr></table>",
      "<table><tr><td><img alt='Published diagram' src='/diagram.png'></td><td>a<br>b <em>word</em></td></tr></table>",
      "<table><tr><th>Field</th></tr><tr><td><div>Same<a href='/one'>source</a></div>" \
      "<section>Same<a href='/one'>source</a></section></td></tr></table>",
      "<table data-fetch-util-table='0'><tr><td>First</td></tr></table>" \
      "<table data-fetch-util-table-owned='0'><tr><td>Second</td></tr></table>",
      "<table><tr><td> </td><td></td></tr></table><table></table>",
      "<table><tr><td>Layout<table><tr><th>Inner</th></tr><tr><td>Complete nested value</td></tr></table></td></tr></table>",
      "<table><tr><th>Outer</th></tr><tr><td><table><tr><td>Nested data</td></tr></table></td></tr></table>"
    ]
    with_prepared_table_converter do |page|
      fixtures.each do |markup|
        result = page.evaluate(<<~JS, markup)
          (() => {
            var markup = arguments[0];
            return {original: __convertPreparedTable(markup, false), prepared: __convertPreparedTable(markup, true),
              ownedOriginal: __convertPreparedTable(markup, false, true), ownedPrepared: __convertPreparedTable(markup, true, true)};
          })()
        JS
        expect(result.fetch("prepared").fetch("markdown")).to eq(result.fetch("original").fetch("markdown")), markup
        expect(result.fetch("ownedPrepared").fetch("markdown")).to eq(result.fetch("original").fetch("markdown")), markup
        expect(result.fetch("ownedOriginal").fetch("markdown")).to eq(result.fetch("original").fetch("markdown")), markup
        if markup.include?("Nested") || markup.include?("nested")
          expect(result.fetch("prepared").fetch("visits")).to eq(result.fetch("original").fetch("visits")), markup
        end
      end
    end
  end
end
