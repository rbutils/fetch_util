require 'spec_helper'
require 'open3'

RSpec.describe 'Complete structured-table discovery work' do
  include_context 'extractor integration helpers'

  def ledger_rows
    (1..12).map do |number|
      "<tr><td>#{number}</td><td><a href='/entry/#{number}'>Published entry #{number}</a></td>" \
        "<td><a href='/evidence/#{number}?view=complete#record'>Evidence #{number}</a></td>" \
        "<td>Complete retained value #{number}</td></tr>"
    end.join
  end

  def ledger_page(extra = '', hidden: false)
    hidden_row = if hidden
                   '<tr hidden><td>Private unpublished row</td><td>Hidden entry</td>' \
                     '<td>Hidden evidence</td><td>Hidden value</td></tr>'
                 else
                   ''
                 end
    <<~HTML
      <title>Published data ledger</title>
      <link rel="canonical" href="https://publication.example.test/ledger.html">
      <main><article><h1>Published data ledger</h1>
      <p>The complete ledger preserves every source row, value and independent reference.</p>
      <table><thead><tr><th>Number</th><th>Entry</th><th>Evidence</th><th>Value</th></tr></thead>
      <tbody>#{ledger_rows}#{hidden_row}</tbody></table>#{extra}</article></main>
    HTML
  end

  def table_work_probe
    directory = File.expand_path('../../../websieve', __dir__)
    source = File.readlines(File.join(directory, 'manifest.txt'), chomp: true)
                 .reject { |line| line.empty? || line.start_with?('#') }
                 .map { |file| File.read(File.join(directory, file)) }.join("\n")
    source.sub('})(window);', <<~'JS')
      window.tableRecordWorkProbe = function() {
        return withInertDomWork(function() {
          return withComposedDomRead(function() {
            var source = document.querySelector('article');
            var before = document.body.outerHTML;
            var originalClone = Node.prototype.cloneNode;
            var originalFallback = extractFallbackHeadlineItems;
            var fallbackDepth = 0, rowCopies = 0, result, fallbackReferences = [];
            Node.prototype.cloneNode = function() {
              if (fallbackDepth && this.nodeType === 1 && this.tagName === 'TR' && this.closest('table')) rowCopies++;
              return originalClone.apply(this, arguments);
            };
            extractFallbackHeadlineItems = function() {
              fallbackDepth++;
              try {
                var fallback = originalFallback.apply(this, arguments);
                fallbackReferences.push(fallback.map(function(item) { return item.url; }));
                return fallback;
              }
              finally { fallbackDepth--; }
            };
            try {
              result = buildListExtraction(source, [document.title], {portalRoot: true});
              return {
                duplicateRowCopies: rowCopies,
                fallbackReferences: fallbackReferences,
                rows: Array.from(result.root.querySelectorAll('tbody > tr')).map(function(row) {
                  return Array.from(row.cells).map(function(cell) { return normalizeText(cell.textContent); });
                }),
                references: Array.from(result.root.querySelectorAll('a[href]')).map(function(link) {
                  return [link.getAttribute('href'), normalizeText(link.textContent)];
                }),
                items: result.items.map(function(item) { return [item.text, item.url]; }),
                sourceUnchanged: document.body.outerHTML === before
              };
            } finally {
              Node.prototype.cloneNode = originalClone;
              extractFallbackHeadlineItems = originalFallback;
              if (result && result.root) result.root.replaceChildren();
            }
          })({});
        })({});
      };
      })(window);
    JS
  end

  def run_table_work_probe(page)
    page.add_script_tag(content: table_work_probe)
    page.evaluate('tableRecordWorkProbe()')
  end

  it 'does not allocate duplicate row DOM after preserving all structured-table evidence' do
    with_url_page('https://publication.example.test/ledger.html', ledger_page) do |page|
      result = run_table_work_probe(page)
      expect(result.fetch('rows')).to eq((1..12).map do |number|
        [number.to_s, "Published entry #{number}", "Evidence #{number}", "Complete retained value #{number}"]
      end)
      expect(result.fetch('references').length).to eq(24)
      expect(result.fetch('items').length).to eq(12)
      expect(result.fetch('sourceUnchanged')).to be(true)
      expect(result.fetch('duplicateRowCopies')).to eq(0)
    end
  end

  it 'keeps an independent outside record even when its destination also belongs to the table' do
    extra = <<~HTML
      <article><h2><a href='/entry/1'>Independent contextual publication</a></h2>
      <p>This separate authored record and its complete explanation remain eligible beside the table.</p></article>
    HTML
    with_url_page('https://publication.example.test/ledger.html', ledger_page(extra)) do |page|
      result = run_table_work_probe(page)
      expect(result.fetch('rows').length).to eq(12)
      expect(result.fetch('items')).to include(
        ['Independent contextual publication', 'https://publication.example.test/entry/1']
      )
      expect(result.fetch('references').count { |url, _| url == 'https://publication.example.test/entry/1' }).to eq(2)
      expect(result.fetch('sourceUnchanged')).to be(true)
    end
  end

  it 'keeps the complete alternative headline inventory when admitted records are not all table-owned' do
    extra = <<~HTML
      <article><h2><a href='/entry/1'>Independent contextual publication</a></h2>
      <p>This separate authored record remains independently eligible beside the complete table.</p></article>
    HTML
    with_url_page('https://publication.example.test/ledger.html', ledger_page(extra)) do |page|
      result = run_table_work_probe(page)
      expect(result.fetch('rows').length).to eq(12)
      expect(result.fetch('references').length).to eq(25)
      expect(result.fetch('items')).to include(
        ['Independent contextual publication', 'https://publication.example.test/entry/1']
      )
      expect(result.fetch('sourceUnchanged')).to be(true)
      alternative = result.fetch('fallbackReferences').last
      expect(alternative).to include(*(1..12).map do |number|
        "https://publication.example.test/entry/#{number}"
      end)
    end
  end

  it 'still discovers real headline records in an unrepresented narrative table' do
    html = <<~HTML
      <title>Published data ledger</title><article><h1>Published data ledger</h1>
      <table><tr><td><h2><a href='/narrative'>Unstructured narrative publication</a></h2>
      <p>A complete independent narrative record remains discoverable without a data-table heading or row schema.</p>
      </td></tr></table></article>
    HTML
    with_url_page('https://publication.example.test/ledger.html', html) do |page|
      result = run_table_work_probe(page)
      expect(result.fetch('items')).to include(
        ['Unstructured narrative publication', 'https://publication.example.test/narrative']
      )
      expect(result.fetch('sourceUnchanged')).to be(true)
    end
  end

  it 'retains complete compiled HTML and Markdown values, references and programs with source visibility' do
    program = "first_value('<kept>')\n\nlast_value('&complete')"
    extra = "<pre><code>first_value('&lt;kept&gt;')\n\nlast_value('&amp;complete')</code></pre>"
    with_url_page('https://publication.example.test/ledger.html', ledger_page(extra, hidden: true)) do |page|
      before = page.evaluate('document.body.outerHTML')
      payload = extract_payload(page, reader_mode: true)
      rendered, errors, status = Open3.capture3(
        'python3', '-c', "from markdown_it import MarkdownIt; import sys; print(MarkdownIt('commonmark').enable('table').render(sys.stdin.read()))",
        stdin_data: payload.fetch('markdown')
      )
      raise errors unless status.success?
      [Nokogiri::HTML5.fragment(payload.fetch('html')), Nokogiri::HTML5.fragment(rendered)].each do |root|
        rows = root.css('table').first.css('tr').reject { |row| row.css('td').empty? }
        expect(rows.map { |row| row.css('td').map { |cell| cell.text.strip } }).to eq((1..12).map do |number|
          [number.to_s, "Published entry #{number}", "Evidence #{number}", "Complete retained value #{number}"]
        end)
        expect(root.css('a[href]').count { |link| link['href'].include?('/evidence/') }).to eq(12)
        expect(root.css('pre').map { |node| node.text.delete_suffix("\n") }).to eq([program])
        expect(root.text).not_to include('Private unpublished row', 'Hidden evidence')
      end
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
    end
  end
end
