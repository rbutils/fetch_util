require "support/extractor_integration_helpers"

RSpec.describe FetchUtil::Extractor do
  include_context "extractor integration helpers"

  def list_noise_prefix_probe(expression)
    root = File.expand_path("../../..", __dir__)
    source = File.readlines("#{root}/websieve/manifest.txt").map(&:strip)
                 .reject { |path| path.empty? || path.start_with?("#") }
                 .map { |path| File.read("#{root}/websieve/#{path}") }.join("\n")
    source = source.sub("})(window);", "global.__noiseText = { prefix: normalizedElementTextPrefix, " \
                                        "normalize: normalizeText }; })(window);")
    with_url_page("https://records.example/collection", "<html><body></body></html>") do |page|
      page.add_script_tag(content: source)
      page.evaluate(expression)
    end
  end

  it "matches complete-text normalization across whitespace, node and UTF-16 prefix boundaries" do
    result = list_noise_prefix_probe(<<~'JS')
      (() => {
        const doc = document.implementation.createHTMLDocument('Prefix records');
        const samples = [[], [' \n\t'], ['alpha', 'beta'], ['a'.repeat(279), ' \t', 'z'],
          ['a'.repeat(279), ' \n'], ['a'.repeat(279), '\u{1f4d6}z'],
          ['\u00a0\ufeff', 'a\u200bb', '\u2028\u3000', 'c\u0085d'],
          ['a', ' ', ' ', 'b'], ['a'.repeat(280), '  ', 'tail']];
        for (let index = 0; index < 64; index++) {
          samples.push([' \t', 'word'.repeat(index), '\u00a0', '章節', '\n', 'x'.repeat(280 - index), '  ']);
        }
        const widths = [0, 1, 2, 17, 279, 280, 281, 400], mismatches = [];
        for (const chunks of samples) {
          const root = doc.createElement('div');
          chunks.forEach((text, index) => {
            root.appendChild(doc.createComment('Not authored text'));
            const span = doc.createElement(index % 2 ? 'em' : 'span');
            span.textContent = text;
            root.appendChild(span);
          });
          const original = root.outerHTML;
          for (const width of widths) {
            const expected = __noiseText.normalize(root.textContent).slice(0, width);
            const actual = __noiseText.prefix(root, width);
            if (actual !== expected) mismatches.push({chunks, width, expected, actual});
          }
          if (root.outerHTML !== original) mismatches.push({mutation: true});
        }
        const xml = new DOMParser().parseFromString('<root>a<![CDATA[ \t b]]><!--ignore--> c</root>', 'application/xml');
        const cdata = __noiseText.prefix(xml.documentElement, 280);
        return {mismatches, checked: samples.length * widths.length, cdata};
      })()
    JS
    expect(result["mismatches"]).to eq([])
    expect(result["checked"]).to eq(584)
    expect(result["cdata"]).to eq("a b c")
  end

  it "classifies every large-table record without reading the complete shared text or unused tail" do
    result = list_noise_prefix_probe(<<~'JS')
      (() => {
        const doc = document.implementation.createHTMLDocument('Registry');
        const table = doc.createElement('table');
        table.innerHTML = '<tbody>' + Array.from({length: 603}, (_, index) =>
          `<tr><td><a href="/record/${index}">${'a'.repeat(300)} Record ${index}</a></td>` +
          `<td><a href="/evidence/${index}">Evidence ${index}</a></td></tr>`).join('') + '</tbody>';
        const root = table.tBodies[0], original = table.outerHTML;
        const expected = __noiseText.normalize(root.textContent).slice(0, 280);
        const tail = root.lastElementChild.lastElementChild.firstElementChild.firstChild;
        let tailReads = 0;
        Object.defineProperty(root, 'textContent', {get() { throw new Error('Whole table text read'); }});
        Object.defineProperty(tail, 'nodeValue', {get() { tailReads++; throw new Error('Unused tail read'); }});
        const values = Array.from(root.rows, () => __noiseText.prefix(root, 280));
        return {allEqual: values.every(value => value === expected), count: values.length, tailReads,
          rows: root.rows.length, links: root.querySelectorAll('a').length, unchanged: table.outerHTML === original};
      })()
    JS
    expect(result).to eq("allEqual" => true, "count" => 603, "tailReads" => 0,
                         "rows" => 603, "links" => 1206, "unchanged" => true)
  end

  it "reads current DOM text on every call and trims trailing whitespace only when it is trailing" do
    result = list_noise_prefix_probe(<<~'JS')
      (() => {
        const root = document.createElement('div');
        root.innerHTML = '<span> alpha </span><em> \n </em>';
        const first = __noiseText.prefix(root, 280);
        root.lastElementChild.appendChild(document.createTextNode('beta'));
        const second = __noiseText.prefix(root, 280);
        root.firstElementChild.textContent = ' \t updated';
        return [first, second, __noiseText.prefix(root, 280)];
      })()
    JS
    expect(result).to eq(["alpha", "alpha beta", "updated beta"])
  end
end
