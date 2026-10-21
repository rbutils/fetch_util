require "spec_helper"
require "support/extractor_integration_helpers"
require "nokogiri"

RSpec.describe "Physical card-owned action references" do
  include_context "extractor integration helpers"

  def card_action_page
    cards = (1..3).map do |number|
      <<~HTML
        <li class="card-list"><div class="card-wrapper"><div class="card-container">
          <a href="/community/#{number}"><img src="/community-#{number}.png" alt="Community illustration #{number}"></a>
          <div><a href="/community/#{number}"><h3>Independent community #{number}</h3></a>
          <p>Community #{number} publishes independently described discussions, practical examples, and contributor guidance.
          This complete explanation belongs to this physical card and remains associated with its three references.</p></div>
          <div class="card-footer"><div><a class="button stretched-link" href="/community/#{number}">
            <span>Participate in community #{number}</span><svg aria-hidden="true"><path d="M0 0"></path></svg>
          </a></div></div>
        </div></div></li>
      HTML
    end.join
    <<~HTML
      <html><head><title>Community reference - Publication service</title>
      <link rel="canonical" href="https://communities.publication.example.test/reference/"></head><body>
      <main><article itemprop="articleBody"><h1>Community reference</h1>
      <p>The publisher describes independent communities and their complete published destinations.
      Each image, heading and separately labelled action has its own physical source occurrence.</p>
      <ul>#{cards}</ul>
      <pre>const literal = '&lt;div class="card-footer"&gt;program text&lt;/div&gt;';</pre>
      <p>The final paragraph belongs to this publication and remains visible after all card references.</p></article>
      <nav><div class="card-footer"><a href="/navigation">NAVIGATION_ACTION_ONLY</a></div></nav>
      <form><div class="card-footer"><a href="/account">ACCOUNT_ACTION_ONLY</a></div></form>
      <div hidden><div class="card-footer"><a href="/hidden">HIDDEN_ACTION_ONLY</a></div></div>
      </main></body></html>
    HTML
  end

  def card_action_stage(page, reader:)
    inject_standalone_extractor(page) if reader
    root = File.expand_path("../../..", __dir__)
    paths = File.readlines(File.join(root, "websieve/manifest.txt"), chomp: true).reject do |line|
      line.empty? || line.start_with?("#")
    end
    source = paths.map { |path| File.read(File.join(root, "websieve", path)) }.join("\n")
    outro = File.read(File.join(root, "websieve/99_outro.js"))
    source = source.delete_suffix(outro) + <<~JS + outro
      window.__cardActionStage = function () {
        if (#{reader.to_json}) {
          var content = readabilityContent({});
          if (content) content.markdown = contentBodyMarkdown(content);
          return JSON.stringify(content);
        }
        var root = visibleListClone(document.querySelector("main"));
        cleanupListRoot(root);
        return JSON.stringify({html: root.innerHTML});
      };
    JS
    page.add_script_tag(content: source)
    JSON.parse(page.evaluate("window.__cardActionStage()"))
  end

  [true, false].each do |reader|
    it "retains all physical image, heading and action references with Reader #{reader}" do
      with_url_page("https://communities.publication.example.test/reference/", card_action_page) do |page|
        before = page.evaluate("document.body.innerHTML")
        expected = page.evaluate("Array.from(document.querySelectorAll('main article > ul a[href]')).map(a => [a.textContent.trim(), a.href])")
        programs = page.evaluate("Array.from(document.querySelectorAll('pre')).map(pre => pre.textContent)")
        payload = card_action_stage(page, reader: reader)
        native = Nokogiri::HTML5(payload.fetch("html"))
        actual = (reader ? native.css("a[href]") : native.css("li a[href]")).map { |a| [a.text.strip, a["href"]] }
        expect(actual).to eq(expected)
        3.times do |index|
          expect(native.text).to include("Community #{index + 1} publishes independently described discussions, practical examples, and contributor guidance.")
        end
        expect(native.css("pre").map(&:text)).to eq(programs)
        expect(native.text).not_to include("NAVIGATION_ACTION_ONLY", "ACCOUNT_ACTION_ONLY", "HIDDEN_ACTION_ONLY")
        if reader
          expect(payload.fetch("readerMode")).to be(true)
          3.times do |index|
            expect(payload.fetch("markdown")).to include("Participate in community #{index + 1}")
            expect(payload.fetch("markdown").scan("https://communities.publication.example.test/community/#{index + 1}").length).to eq(3)
          end
          programs.each { |program| expect(payload.fetch("markdown")).to include(program) }
        end
        expect(page.evaluate("document.body.innerHTML")).to eq(before)
      end
    end
  end

  it "excludes semantic interfaces and unowned groups while retaining complete programs" do
    html = <<~HTML
      <html><head><title>Independent control material</title></head><body><main>
      <h1>Independent control material</h1><ul><li><h3>Local publication</h3>
      <p>The complete local explanation remains associated with this physical record.</p>
      <footer><a href="/semantic">SEMANTIC_FOOTER_ONLY</a></footer>
      <form><div class="card-footer"><a href="/account">ACCOUNT_ACTION_ONLY</a></div></form>
      <nav><div class="card-footer"><a href="/navigation">NAVIGATION_ACTION_ONLY</a></div></nav>
      <div hidden><div class="card-footer"><a href="/hidden">HIDDEN_ACTION_ONLY</a></div></div>
      </li></ul><div class="card-footer"><a href="/orphan">UNOWNED_ACTION_ONLY</a></div>
      <pre>const literal = "card-footer and independent program text";</pre>
      </main></body></html>
    HTML
    with_url_page("https://communities.publication.example.test/controls/", html) do |page|
      before = page.evaluate("document.body.innerHTML")
      result = card_action_stage(page, reader: false).fetch("html")
      expect(result).to include("Local publication", "The complete local explanation remains", 'const literal = "card-footer and independent program text";')
      expect(result).not_to include("SEMANTIC_FOOTER_ONLY", "ACCOUNT_ACTION_ONLY", "NAVIGATION_ACTION_ONLY", "HIDDEN_ACTION_ONLY", "UNOWNED_ACTION_ONLY")
      expect(page.evaluate("document.body.innerHTML")).to eq(before)
    end
  end

  it "retains every concise card and independent reference through conditional cleanup" do
    description = "Independent instructions for every community."
    pattern = Regexp.new(
      "Community \\d publishes independently described discussions, practical examples, and contributor guidance\\." \
      "\\s+This complete explanation belongs to this physical card and remains associated with its three references\\."
    )
    html = card_action_page.gsub(pattern, description)
    expect(html.scan(description).length).to eq(3)
    with_url_page("https://communities.publication.example.test/reference/", html) do |page|
      before = page.evaluate("document.body.innerHTML")
      expected = page.evaluate("Array.from(document.querySelectorAll('main article > ul a[href]')).map(a => [a.textContent.trim(), a.href])")
      images = page.evaluate("Array.from(document.querySelectorAll('main article img')).map(i => [i.alt, i.src])")
      programs = page.evaluate("Array.from(document.querySelectorAll('pre')).map(pre => pre.textContent)")
      result = card_action_stage(page, reader: true)
      native = Nokogiri::HTML5(result.fetch("html"))
      expect(native.css("a[href]").map { |a| [a.text.strip, a["href"]] }).to eq(expected)
      expect(native.css("p").count { |p| p.text.strip == description }).to eq(3)
      expect(native.css("img").map { |i| [i["alt"], i["src"]] }).to eq(images)
      expect(native.css("pre").map(&:text)).to eq(programs)
      3.times do |index|
        expect(result.fetch("markdown").scan("https://communities.publication.example.test/community/#{index + 1}").length).to eq(3)
      end
      programs.each { |program| expect(result.fetch("markdown")).to include(program) }
      expect(page.evaluate("document.body.innerHTML")).to eq(before)
    end
  end
end
