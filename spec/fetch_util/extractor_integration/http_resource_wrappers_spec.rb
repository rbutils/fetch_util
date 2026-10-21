require "spec_helper"
require "support/extractor_integration_helpers"
require "nokogiri"
require "uri"

RSpec.describe "Physical content-owned HTTP resource wrappers" do
  include_context "extractor integration helpers"

  def resource_wrapper_page(primary_heading:)
    heading = primary_heading ? "<h1>Published transport observations</h1>" : "<h2>Published transport observations</h2>"
    site_header = primary_heading ? "" : "<header><h1>Publication service</h1></header>"
    explanation = "The publisher provides complete historical observations and a machine-readable service feed. " \
      "Each destination belongs to this resource index and retains its own published label and physical source occurrence. "
    <<~HTML
      <html><head><title>Published transport observations - Publication service</title></head><body>
      #{site_header}<main id="publication-content">#{heading}
      <p>#{explanation * 4}</p>
      <section><h2>History</h2>
        <div class="record-row"><div><h3>2026</h3></div>
          <div class="resource-column"><a class="button button-primary" href="/data/2026.zip">Download (ZIP)</a></div>
        </div>
        <div class="record-row"><div><h3>2025</h3></div>
          <div class="resource-column"><a class="button button-primary" href="/data/2025.zip">Download (ZIP)</a></div>
        </div>
        <div class="record-row"><div><h3>2024</h3></div>
          <div class="resource-column"><a class="button button-primary" href="/data/2025.zip">Download (ZIP)</a></div>
        </div>
      </section>
      <section><h2>Live service</h2><p>The feed is an independently published current observation interface.</p>
        <div class="resource-actions"><a class="button" href="https://feed.publication.example.test/observations.json">Access machine feed</a></div>
      </section>
      <p>#{explanation}</p>
      <div hidden><div><a href="/hidden.zip">HIDDEN_RESOURCE_ONLY</a></div></div>
      <details><summary>Closed supplementary material</summary><div><a href="/closed.zip">CLOSED_RESOURCE_ONLY</a></div></details>
      </main>
      <nav><div><a href="/navigation.zip">NAVIGATION_RESOURCE_ONLY</a></div></nav>
      <form><div><a href="/account.zip">ACCOUNT_RESOURCE_ONLY</a></div></form>
      </body></html>
    HTML
  end

  [true, false].each do |primary_heading|
    it "retains all resource destinations, labels and independent occurrences with primary heading #{primary_heading}" do
      html = resource_wrapper_page(primary_heading: primary_heading)
      source = Nokogiri::HTML5(html)
      source.css("[hidden], details:not([open]), nav, form").remove
      expected_references = source.css("main a[href]").map do |anchor|
        [anchor.text, URI.join("https://resources.publication.example.test/observations/", anchor["href"]).to_s]
      end
      expected_programs = source.css("pre").map(&:text)
      expected_paragraphs = source.css("main p, main .resource-column, main .resource-actions").map(&:text)
      # Readability displays the complete physical H1 as an H2 beneath the title.
      expected_headings = source.css("main h1, main h2, main h3").map do |node|
        [node.name == "h1" ? "h2" : node.name, node.text]
      end
      with_url_page("https://resources.publication.example.test/observations/", html) do |page|
        before = page.evaluate("document.body.innerHTML")
        payload = extract(page)
        expect(payload.fetch("readerMode")).to be(true)
        native = Nokogiri::HTML5(payload.fetch("html"))
        native.css("nav, form, details:not([open])").remove
        expect(native.css("a[href]").map { |node| [node.text, node["href"]] }).to eq(expected_references)
        paragraphs = native.css("p").reject { |node| node.text.empty? && node.element_children.empty? }
        expect(paragraphs.map(&:text)).to eq(expected_paragraphs)
        expect(native.css("pre").map(&:text)).to eq(expected_programs)
        expect(native.css("h2, h3").map { |node| [node.name, node.text] }).to eq(expected_headings)
        expected_references.map(&:last).uniq.each do |url|
          expect(payload.fetch("markdown").scan(Regexp.new(Regexp.escape(url))).length)
            .to eq(expected_references.count { |reference| reference.last == url })
        end
        expected_programs.each { |program| expect(payload.fetch("markdown")).to include(program) }
        expect(payload.fetch("markdown")).not_to include("HIDDEN_RESOURCE_ONLY", "CLOSED_RESOURCE_ONLY", "NAVIGATION_RESOURCE_ONLY", "ACCOUNT_RESOURCE_ONLY")
        expect(page.evaluate("document.body.innerHTML")).to eq(before)
      end
    end
  end

  it "keeps genuine interface-owned and hidden resource groups outside the article result" do
    html = <<~HTML
      <html><head><title>Published reference</title></head><body>
      <main><h1>Published reference</h1>
      <p>This publication explains the complete physical source ownership of the current reference.
      Its visible text and literal example remain intact while independent account and navigation interfaces are excluded.</p>
      <pre>const published = "all literal text";</pre>
      <p>The final paragraph belongs to the same current reference and is independently visible.</p>
      <nav><div><a href="/navigation.zip">NAVIGATION_RESOURCE_ONLY</a></div></nav>
      <form><div><a href="/account.zip">ACCOUNT_RESOURCE_ONLY</a></div></form>
      <div role="dialog"><div><a href="/dialog.zip">DIALOG_RESOURCE_ONLY</a></div></div>
      <div style="display:none"><div><a href="/hidden.zip">HIDDEN_RESOURCE_ONLY</a></div></div>
      </main></body></html>
    HTML
    with_url_page("https://resources.publication.example.test/reference/", html) do |page|
      before = page.evaluate("document.body.innerHTML")
      payload = extract(page)
      native = Nokogiri::HTML5(payload.fetch("html"))
      expect(native.css("pre").map(&:text)).to eq(['const published = "all literal text";'])
      expect(native.text).to include("The final paragraph belongs to the same current reference and is independently visible.")
      expect(payload.fetch("markdown")).to include('const published = "all literal text";')
      expect(payload.fetch("markdown")).not_to include("NAVIGATION_RESOURCE_ONLY", "ACCOUNT_RESOURCE_ONLY", "DIALOG_RESOURCE_ONLY", "HIDDEN_RESOURCE_ONLY")
      expect(page.evaluate("document.body.innerHTML")).to eq(before)
    end
  end

  it "conserves a complete sibling file table and every authored resource occurrence" do
    rows = (1..8).map do |number|
      %(<tr><td><a href="https://data.publication.example.test/part-#{number}.csv">part-#{number}.csv</a></td><td>UTF-8</td><td>#{number} observations</td></tr>)
    end.join
    table = '<section><h2>Published data files</h2><p>Every complete file is independently available.</p>' \
      '<div class="overflow-hidden"><table><thead><tr><th>File</th><th>Encoding</th><th>Records</th></tr></thead>' \
      "<tbody>#{rows}</tbody></table></div></section>"
    html = resource_wrapper_page(primary_heading: true).sub('<main id="publication-content">', '<main id="publication-content"><article>')
    html = html.sub("</main>", "#{table}</article></main>")
    with_url_page("https://resources.publication.example.test/observations/", html) do |page|
      before = page.evaluate("document.body.innerHTML")
      expected_rows = page.evaluate("Array.from(document.querySelectorAll('main table tr')).map(row => Array.from(row.children).map(cell => cell.textContent))")
      expected_links = page.evaluate("Array.from(document.querySelectorAll('main .resource-column a[href], " \
        "main .resource-actions a[href], main table a[href]')).map(link => [link.textContent, link.href])")
      payload = extract(page)
      native = Nokogiri::HTML5(payload.fetch("html"))
      expect(payload.fetch("readerMode")).to eq(true)
      expect(native.css("table").length).to eq(1)
      expect(native.css("table tr").map { |row| row.element_children.map(&:text) }).to eq(expected_rows)
      expect(native.css("a[href]").map { |link| [link.text, link["href"]] }).to eq(expected_links)
      expected_links.each do |label, destination|
        expect(payload.fetch("markdown")).to include(label, destination)
      end
      expect(page.evaluate("document.body.innerHTML")).to eq(before)
    end
  end
end
