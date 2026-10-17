require "support/extractor_integration_helpers"
require "nokogiri"

RSpec.describe FetchUtil::Extractor do
  include_context "extractor integration helpers"

  def canonical_data_page(records: 603)
    rows = (1..records).map do |index|
      "<tr data-record='#{index}'><td><a href='/series/#{index}.csv'>Series #{index}</a></td>" \
        "<td>#{index * 10}</td><td>2000-01-01</td><td>2025-12-31</td></tr>"
    end.join
    <<~HTML
      <!doctype html><html lang="en"><head><title>Complete measurements - Example Data</title>
      <link rel="canonical" href="https://records.example.test/measurements/"></head><body>
      <header><a href="/">Example Data</a></header><main><div><h1>Complete measurements</h1>
      <p>Daily measurements describe every published source record and its complete observation interval.</p>
      <p><a href="/collections/">Measurement collections</a></p><h3>Published worksheet</h3>
      <table><tr><th>Series</th><th>Observations</th><th>Start</th><th>End</th></tr>#{rows}</table>
      </div></main><footer><a href="/about/">About the data service</a></footer></body></html>
    HTML
  end

  def canonical_table_task(page, body)
    preparation = described_class.new.__send__(:owned_preparation_call)
    page.evaluate(<<~JS)
      (() => {
        const task = #{preparation};
        #{body}
      })()
    JS
  end

  it "owns every canonical table record before heavy preparation and preserves the complete ordinary payload" do
    with_url_page("https://records.example.test/measurements/", canonical_data_page) do |page|
      inject_standalone_extractor(page)
      before = page.evaluate("document.body.innerHTML")
      expect(canonical_table_task(page, "const owned = task.owned; task.dispose(); return owned;")).to be(true)
      ordinary = page.evaluate("window.FetchUtilExtract.extract({reader_mode: true})")
      calls = []
      allow(page).to receive(:command).and_wrap_original do |original, method, **parameters|
        calls << method
        original.call(method, **parameters)
      end
      actual = described_class.new.extract(page)
      expect(actual).to eq(ordinary)
      expect(calls.count("HeapProfiler.collectGarbage")).to eq(2)
      expect(actual).to include("title" => "Complete measurements", "contentType" => "list",
                                "byline" => nil, "publishedTime" => nil)
      html = Nokogiri::HTML5.fragment(actual.fetch("html"))
      expect(html.css("table tr").length).to eq(604)
      expect(html.css("table th,table td").length).to eq(2416)
      (1..603).each do |index|
        row = html.at_css("tr[data-record='#{index}']")
        expect(row.css("td").map(&:text)).to eq(["Series #{index}", (index * 10).to_s, "2000-01-01", "2025-12-31"])
        expect(row.at_css("a")["href"]).to eq("https://records.example.test/series/#{index}.csv")
        expect(actual.fetch("markdown")).to include(
          "| [Series #{index}](https://records.example.test/series/#{index}.csv) | #{index * 10} | 2000-01-01 | 2025-12-31 |"
        )
      end
      expect(actual.fetch("markdown")).to include("Daily measurements describe every published source record",
                                                  "[Measurement collections](https://records.example.test/collections/)")
      expect(page.evaluate("document.body.innerHTML")).to eq(before)
    end
  end

  it "invalidates prepared cells after source changes and consumes owned work once" do
    with_url_page("https://records.example.test/measurements/", canonical_data_page(records: 3)) do |page|
      inject_standalone_extractor(page)
      result = canonical_table_task(page, <<~JS)
        const owned = task.owned;
        task.prepare();
        document.querySelector('tr[data-record="3"] td:nth-child(2)').textContent = '987654';
        const payload = task.finish();
        let repeatedError = false;
        try { task.finish(); } catch (error) { repeatedError = /already been consumed/.test(error.message); }
        return {owned, payload, repeatedError};
      JS
      expect(result).to include("owned" => true, "repeatedError" => true)
      expect(result.fetch("payload").fetch("markdown")).to include("| 987654 | 2000-01-01 |")
      expect(result.fetch("payload").fetch("html")).to include("987654")
    end
  end

  it "declines ambiguous identity, irregular or hidden records and competing authored owners" do
    with_url_page("https://records.example.test/measurements/", canonical_data_page(records: 3)) do |page|
      inject_standalone_extractor(page)
      preparation = described_class.new.__send__(:owned_preparation_call)
      result = page.evaluate(<<~JS)
        (() => {
          const originalBody = document.body.innerHTML, originalTitle = document.title;
          const canonical = document.querySelector('link[rel="canonical"]'), originalUrl = canonical.href;
          const mutations = [
            () => document.body.insertAdjacentHTML('beforeend', '<main><p>A separate authored owner.</p></main>'),
            () => canonical.href = 'https://foreign.example.test/measurements/',
            () => document.title = 'A different publication',
            () => document.querySelectorAll('th')[1].textContent = 'Series',
            () => document.querySelector('tr[data-record="1"] td').setAttribute('colspan', '2'),
            () => document.querySelector('tr[data-record="2"] a').href = document.querySelector('tr[data-record="1"] a').href,
            () => document.querySelector('tr[data-record="2"] td:nth-child(2)').textContent = 'unavailable',
            () => document.querySelector('main').insertAdjacentHTML('beforeend', '<article><h2>Separate reporting</h2><p>Independent article material.</p></article>'),
            () => document.body.insertAdjacentHTML('beforeend', '<p>Independent authored material outside the table owner.</p>'),
            () => document.querySelector('tr[data-record="1"]').style.display = 'none',
            () => document.querySelector('main').insertAdjacentHTML('beforeend', '<form><input name="recipient"></form>'),
            () => document.body.insertAdjacentHTML('beforeend', '<figure><img alt="Independent published diagram" src="/diagram.svg"></figure>'),
            () => document.body.insertAdjacentHTML('beforeend', '<form><input name="independent-recipient"></form>')
          ];
          const outcomes = mutations.map(mutate => {
            document.body.innerHTML = originalBody; document.title = originalTitle; canonical.href = originalUrl;
            mutate();
            const task = #{preparation};
            const owned = task.owned; task.dispose(); return owned;
          });
          document.body.innerHTML = originalBody; document.title = originalTitle; canonical.href = originalUrl;
          const fresh = #{preparation};
          const restored = fresh.owned; fresh.dispose();
          return {outcomes, restored, unchanged: document.body.innerHTML === originalBody};
        })()
      JS
      expect(result).to include("outcomes" => Array.new(13, false), "restored" => true, "unchanged" => true)
    end
  end
end
