require "support/extractor_integration_helpers"

RSpec.describe FetchUtil::Extractor do
  include_context "extractor integration helpers"

  def table_header_scope_probe(table, expression)
    root = File.expand_path("../../..", __dir__)
    source = File.readlines("#{root}/websieve/manifest.txt").map(&:strip)
                 .reject { |path| path.empty? || path.start_with?("#") }
                 .map { |path| File.read("#{root}/websieve/#{path}") }.join("\n")
    source = source.sub("})(window);", "global.__tableScope = { reader: tableIndexHeaderReader, " \
                                        "headers: tableIndexHeaders, detail: listTableRowDetail }; })(window);")
    with_url_page("https://registry.example/collection", "<html><body>#{table}</body></html>") do |page|
      page.add_script_tag(content: source)
      page.evaluate(expression)
    end
  end

  def scoped_record_rows(count)
    count.times.map do |index|
      "<tr><td><a href='/records/#{index}'>Registered record #{index}</a></td>" \
        "<td>See <a href='/evidence/#{index}'>document #{index}</a>.</td><td>confirmed</td></tr>"
    end.join
  end

  it "reads the full header grid once while retaining every row and mixed-cell reference" do
    table = "<table><tr><th>Record</th><th>Evidence</th><th>Status</th></tr>#{scoped_record_rows(603)}</table>"
    result = table_header_scope_probe(table, <<~JS)
      (() => {
        const table = document.querySelector('table'), original = table.outerHTML;
        const query = table.querySelectorAll.bind(table);
        let scans = 0;
        table.querySelectorAll = selector => { if (selector === 'thead tr') scans++; return query(selector); };
        const read = __tableScope.reader();
        const details = Array.from(query('tr')).slice(1).map((row, index) =>
          __tableScope.detail(row, `Registered record ${index}`, null,
            {url: `https://registry.example/records/${index}`}, read));
        return {details, scans, unchanged: table.outerHTML === original};
      })()
    JS
    expect(result["details"]).to eq(603.times.map do |index|
      "Evidence: See [document #{index}](https://registry.example/evidence/#{index}). | Status: confirmed"
    end)
    expect(result["scans"]).to eq(1)
    expect(result["unchanged"]).to be(true)
  end

  it "shares an empty header result without dropping unlabelled field values" do
    result = table_header_scope_probe("<table>#{scoped_record_rows(80)}</table>", <<~JS)
      (() => {
        const table = document.querySelector('table'), query = table.querySelectorAll.bind(table);
        let scans = 0;
        table.querySelectorAll = selector => { if (selector === 'thead tr') scans++; return query(selector); };
        const read = __tableScope.reader();
        const details = Array.from(query('tr')).map((row, index) =>
          __tableScope.detail(row, `Registered record ${index}`, null, null, read));
        return {details, scans};
      })()
    JS
    expect(result["details"]).to eq(80.times.map { |index| "See document #{index}. | confirmed" })
    expect(result["scans"]).to eq(1)
  end

  it "keeps spanning labels table-local and observes changed labels and visibility in fresh passes" do
    table = "<table><thead><tr><th rowspan='2'>Record</th><th colspan='2'>Review</th></tr>" \
            "<tr><th>Status</th><th>Evidence</th></tr></thead>#{scoped_record_rows(2)}</table>"
    result = table_header_scope_probe(table, <<~JS)
      (() => {
        const table = document.querySelector('table'), copy = table.cloneNode(true);
        document.body.appendChild(copy);
        copy.querySelector('th').textContent = 'Other record';
        const read = __tableScope.reader(), first = read(table), other = read(copy);
        table.querySelector('th').textContent = 'Updated record';
        const updated = __tableScope.reader()(table);
        table.querySelector('thead').hidden = true;
        const hidden = __tableScope.reader()(table);
        table.querySelector('thead').hidden = false;
        return {first, other, updated, hidden, direct: __tableScope.headers(table)};
      })()
    JS
    expect(result["first"]).to eq(["Record", "Review / Status", "Review / Evidence"])
    expect(result["other"]).to eq(["Other record", "Review / Status", "Review / Evidence"])
    expect(result["updated"]).to eq(["Updated record", "Review / Status", "Review / Evidence"])
    expect(result["hidden"]).to eq([])
    expect(result["direct"]).to eq(result["updated"])
  end
end
