require "spec_helper"
require "support/extractor_integration_helpers"
require "nokogiri"

RSpec.describe "Complete source-owned nested resource tables" do
  include_context "extractor integration helpers"

  def nested_provider_page
    <<~HTML
      <html><head><title>Publication provider plans</title>
      <meta property="og:type" content="article"></head><body>
      <article itemprop="articleBody"><h1>Publication provider plans</h1>
      <p>This publication describes the complete provider offerings and the independently
      selectable plans. Readers can compare every published option and follow its own
      destination without losing the surrounding explanation.</p>
      <p>Provider descriptions and their nested plan groups belong to this document.
      The following comparison is authored material, including every repeated destination.</p>
      <div><p>Choose a provider.</p><table id="providers"><tbody>
      <tr><td>North provider</td><td><table><tbody><tr>
      <td><a href="https://provider.example.test/north/">Standard north</a></td>
      <td><a href="https://provider.example.test/shared/">Shared north</a></td>
      </tr></tbody></table></td></tr>
      <tr><td>South provider</td><td><table><tbody><tr>
      <td><a href="https://provider.example.test/south/">Standard south</a></td>
      <td><a href="https://provider.example.test/shared/">Shared south</a></td>
      </tr><tr style="display:none"><td>Hidden plan</td>
      <td><a href="https://provider.example.test/private/">Hidden destination</a></td>
      </tr></tbody></table></td></tr>
      </tbody></table></div>
      <p>The complete comparison ends here. This paragraph remains in its original
      position after both providers and all four visible plan references.</p>
      <pre><code>if (provider) {\n  publish("all plans");\n}</code></pre>
      </article>
      <nav><table><tbody><tr><td>Navigation owner</td><td><table><tbody>
      <tr><td><a href="https://interface.example.test/">Account interface</a></td></tr>
      </tbody></table></td></tr></tbody></table></nav>
      </body></html>
    HTML
  end

  def nested_provider_reader(page)
    inject_standalone_extractor(page)
    root = File.expand_path("../../..", __dir__)
    paths = File.readlines(File.join(root, "websieve/manifest.txt"), chomp: true).reject do |line|
      line.empty? || line.start_with?("#")
    end
    source = paths.map { |path| File.read(File.join(root, "websieve", path)) }.join("\n")
    outro = File.read(File.join(root, "websieve/99_outro.js"))
    source = source.delete_suffix(outro) + <<~JS + outro
      window.__nestedProviderReader = function() {
        var result = readabilityContent({});
        if (result) result.markdown = contentBodyMarkdown(result);
        return JSON.stringify(result);
      };
    JS
    page.add_script_tag(content: source)
    JSON.parse(page.evaluate("window.__nestedProviderReader()"))
  end

  it "preserves every visible nested cell and independent reference" do
    with_url_page("https://publication.example.test/provider-plans/", nested_provider_page) do |page|
      before = page.evaluate("document.body.outerHTML")
      result = nested_provider_reader(page)
      native = Nokogiri::HTML5.fragment(result.fetch("html"))
      table = native.at_css("#providers")

      expect(native.css("p").map(&:text)).to include("Choose a provider.")
      expect(table).not_to be_nil
      expect(table.css("table").length).to eq(2)
      expected_cells = [
        "North provider", "Standard north Shared north", "Standard north", "Shared north",
        "South provider", "Standard south Shared south", "Standard south", "Shared south"
      ]
      expected_references = [
        ["Standard north", "https://provider.example.test/north/"],
        ["Shared north", "https://provider.example.test/shared/"],
        ["Standard south", "https://provider.example.test/south/"],
        ["Shared south", "https://provider.example.test/shared/"]
      ]
      expect(table.css("td").map { |cell| cell.text.gsub(/\s+/, " ").strip }).to eq(expected_cells)
      expect(table.css("a[href]").map { |link| [link.text.strip, link["href"]] }).to eq(expected_references)
      expect(result.fetch("markdown")).to include("North provider", "South provider", "Shared north", "Shared south")
      expect(page.evaluate("document.body.outerHTML")).to eq(before)
    end
  end

  it "retains complete programs and excludes hidden and independently owned interfaces" do
    with_url_page("https://publication.example.test/provider-plans/", nested_provider_page) do |page|
      before = page.evaluate("document.body.outerHTML")
      result = nested_provider_reader(page)
      native = Nokogiri::HTML5.fragment(result.fetch("html"))

      expect(native.css("pre").map(&:text)).to eq(["if (provider) {\n  publish(\"all plans\");\n}"])
      expect(result.fetch("markdown")).to include("if (provider) {\n  publish(\"all plans\");\n}")
      expect(result.fetch("html")).not_to include("Hidden plan", "Hidden destination", "Account interface")
      expect(result.fetch("markdown")).not_to include("Hidden plan", "Hidden destination", "Account interface")
      expect(native.css("p").map(&:text).join(" ")).to include("The complete comparison ends here.")
      expect(page.evaluate("document.body.outerHTML")).to eq(before)
    end
  end

  {
    "span" => "<span>Choose a provider.</span>",
    "strong" => "<strong>Choose a provider.</strong><br>"
  }.each do |tag, introduction|
    it "preserves the complete catalogue introduced by authored #{tag} prose" do
      html = nested_provider_page.sub("<p>Choose a provider.</p>", introduction)
      with_url_page("https://publication.example.test/provider-plans/", html) do |page|
        before = page.evaluate("document.body.outerHTML")
        result = nested_provider_reader(page)
        native = Nokogiri::HTML5.fragment(result.fetch("html"))
        table = native.at_css("#providers")
        expected_cells = [
          "North provider", "Standard north Shared north", "Standard north", "Shared north",
          "South provider", "Standard south Shared south", "Standard south", "Shared south"
        ]
        expected_references = [
          ["Standard north", "https://provider.example.test/north/"],
          ["Shared north", "https://provider.example.test/shared/"],
          ["Standard south", "https://provider.example.test/south/"],
          ["Shared south", "https://provider.example.test/shared/"]
        ]

        expect(table).not_to be_nil
        expect(table.css("table").length).to eq(2)
        expect(table.css("td").map { |cell| cell.text.gsub(/\s+/, " ").strip }).to eq(expected_cells)
        expect(table.css("a[href]").map { |link| [link.text.strip, link["href"]] }).to eq(expected_references)
        expect(native.css(tag).map(&:text)).to include("Choose a provider.")
        expect(native.css("pre").map(&:text)).to eq(["if (provider) {\n  publish(\"all plans\");\n}"])
        expect(result.fetch("markdown")).to include("Choose a provider.", "Shared north", "Shared south")
        expect(result.fetch("html")).not_to include("Hidden plan", "Hidden destination", "Account interface")
        expect(page.evaluate("document.body.outerHTML")).to eq(before)
      end
    end
  end

  it "preserves the physical single-cell tables within an owned nested catalogue" do
    original_link = '<a href="https://provider.example.test/shared/">Shared north</a>'
    wrapped_link = "<table id=\"single-plan\"><tbody><tr><td>#{original_link}</td></tr></tbody></table>"
    html = nested_provider_page.sub(original_link, wrapped_link)
    with_url_page("https://publication.example.test/provider-plans/", html) do |page|
      before = page.evaluate("document.body.outerHTML")
      result = nested_provider_reader(page)
      native = Nokogiri::HTML5.fragment(result.fetch("html"))
      source = Nokogiri::HTML5(html).at_css("#providers")
      source.css('[style="display:none"]').remove
      table = native.at_css("#providers")

      expect(table.at_css("#single-plan")).not_to be_nil
      source_cells = source.css("td,th").map { |cell| [cell.name, cell.text.gsub(/\s+/, " ").strip] }
      expect(table.css("td,th").map { |cell| [cell.name, cell.text.gsub(/\s+/, " ").strip] }).to eq(source_cells)
      expect(table.css("table").length).to eq(source.css("table").length)
      references = source.css("a[href]").map { |link| [link.text.strip, link["href"]] }
      expect(table.css("a[href]").map { |link| [link.text.strip, link["href"]] }).to eq(references)
      expect(native.css("pre").map(&:text)).to eq(["if (provider) {\n  publish(\"all plans\");\n}"])
      expect(result.fetch("html")).not_to include("Hidden plan", "Hidden destination", "Account interface")
      expect(page.evaluate("document.body.outerHTML")).to eq(before)
    end
  end

  it "keeps every nested plan cell as data when no header is declared" do
    with_url_page("https://publication.example.test/provider-plans/", nested_provider_page) do |page|
      before = page.evaluate("document.body.outerHTML")
      result = nested_provider_reader(page)
      tables = result.fetch("markdown").scan(/\|[^\n]*(?:\n\|[^\n]*)+/)
      expected_data = [
        "| [Standard north](https://provider.example.test/north/) | [Shared north](https://provider.example.test/shared/) |",
        "| [Standard south](https://provider.example.test/south/) | [Shared south](https://provider.example.test/shared/) |"
      ]

      expect(tables.map { |table| table.lines.first.strip }).to eq(["|  |  |", "|  |  |"])
      expect(tables.flat_map { |table| table.lines.drop(2).map(&:strip) }).to eq(expected_data)
      expect(result.fetch("markdown")).to include("if (provider) {\n  publish(\"all plans\");\n}")
      expect(result.fetch("markdown")).not_to include("Hidden plan", "Hidden destination", "Account interface")
      expect(page.evaluate("document.body.outerHTML")).to eq(before)
    end
  end
end
