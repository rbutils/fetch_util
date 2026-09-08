# frozen_string_literal: true

RSpec.describe "FetchUtil extractor integration - inline list descriptions" do
  include_context "extractor integration helpers"

  def inline_description_source
    root = File.expand_path("../../..", __dir__)
    source = File.readlines(File.join(root, "websieve/manifest.txt"), chomp: true).reject(&:empty?).map do |entry|
      File.read(File.join(root, "websieve", entry))
    end.join("\n")
    source.sub(
      "})(window);",
      "global.FetchUtilInlineDescriptionTest = { description: listDescriptionMarkdown, " \
        "clone: visibilityPrunedClone, render: listMarkdownWithInlineDescriptions }; })(window);"
    )
  end

  it "retains visible inline-only introductions and answers in a catalog" do
    introduction = "Explore practical learning pathways with support from experienced local teachers."
    answer = "Choose a suitable workshop and contact the teaching team to discuss your learning goals."
    html = <<~HTML
      <html><head><title>Training catalog</title></head><body><main>
        <h1>Training catalog</h1>
        <div><span>#{introduction}</span></div>
        <h4>How do I get started?</h4>
        <div><strong>#{answer}</strong></div>
        <h2>Available workshops</h2>
        <ul>
          #{(1..4).map do |index|
            "<li><h3><a href='/learn/#{index}'>Explore practical workshop #{index}</a></h3>" \
              "<p>Study local project #{index} with guided exercises and constructive feedback.</p></li>"
          end.join}
        </ul>
      </main></body></html>
    HTML
    with_url_page("https://learning.example/catalog", html) do |page|
      payload = extract(page)

      expect(payload["contentType"]).to eq("list")
      [introduction, answer].each { |text| expect(payload["markdown"].scan(text)).to eq([text]) }
      (1..4).each { |index| expect(payload["markdown"]).to include("https://learning.example/learn/#{index}") }
    end
  end

  it "preserves uncapped prose once without promoting controls or changing scoring" do
    long_prose = (1..80).map { |index| "Learning step #{index} connects careful observation with practical community research." }.join(" ")
    represented = "This summary already appears in the retained workshop record."
    short_prose = "Learn at your own pace."
    html = <<~HTML
      <html><head><title>Training catalog</title></head><body><main>
        <div><div><span>#{short_prose}</span></div></div>
        <div><strong>#{long_prose}</strong></div>
        <div>#{represented}</div>
        <div aria-hidden="true"><span>Accessibility-hidden duplicate prose must not appear.</span></div>
        <section inert><div>Inert copy must not become visible page prose.</div></section>
        <div>Unpublished content: <span aria-hidden="true">Hidden nested instructions must not appear.</span></div>
        <section class="cookie-modal"><div>Diese Einstellungen bestimmen die Verwendung Ihrer Daten.</div></section>
        <div class="ad-disclaimer">Advertisement - Continue Reading Below</div>
        <div class="nested-card"><span class="author">Nested author metadata</span><time>Nested time metadata</time>
          <span class="score">Nested score metadata</span><span class="reply-count">Nested replies metadata</span>
          <span class="community">Nested community metadata</span></div>
        <div><video>Your browser does not support the video tag.</video></div>
        <div><a href="/learn/one">Long linked workshop title number one</a>
          <a href="/learn/two">Long linked workshop title number two</a></div>
        <div><a href="/learn/maps">Explore cartography workshops</a> 96% (2026)</div>
        <div><span><a href="/learn/maps">Explore cartography workshops</a> 500K 17 hours ago</span></div>
        <div><a href="/learn/maps">Explore cartography workshops</a><time datetime="2026-09-06">September 6, 2026</time></div>
        <div hidden>Hidden instructions must not appear in the visible description.</div>
        <button><div>This interaction label must remain outside description prose.</div></button>
        <div>This input instruction must not become description prose.<input></div>
        <ul><li><div>This list-owned text must not become description prose.</div></li></ul>
        <div class="story-card"><a href="/learn/maps">Explore cartography workshops</a></div>
      </main></body></html>
    HTML
    with_url_page("https://learning.example/catalog", html) do |page|
      page.add_script_tag(content: inline_description_source)
      result = page.evaluate(<<~JAVASCRIPT)
        (() => {
          const root = FetchUtilInlineDescriptionTest.clone(document.querySelector('main'), document);
          const card = root.querySelector('.story-card');
          const items = [{ card, text: 'Explore cartography workshops', url: '/learn/maps', summary: #{represented.to_json} }];
          return {
            scoring: FetchUtilInlineDescriptionTest.description(root),
            empty: FetchUtilInlineDescriptionTest.description(root, []),
            ordinary: FetchUtilInlineDescriptionTest.description(root, items),
            description: FetchUtilInlineDescriptionTest.description(root, items, { includeInlineProse: true })
          };
        })()
      JAVASCRIPT

      expect(result.values_at("scoring", "empty", "ordinary")).to eq(["", "", ""])
      expect(result["description"]).to eq("#{short_prose}\n\n#{long_prose}")
    end
  end

  it "keeps prose around inline links and ignores empty accessibility decoration" do
    html = <<~HTML
      <html><body><main>
        <div>Learn with <a href="/learn/maps">experienced teachers</a> in small groups.</div>
        <div><span aria-hidden="true"></span>Explore local history at your own pace.</div>
        <div>Learn from <span class="author">Jane Example</span> about field research.</div>
        <div class="story-card"><a href="/learn/maps">Explore cartography workshops</a></div>
      </main></body></html>
    HTML
    with_url_page("https://learning.example/catalog", html) do |page|
      page.add_script_tag(content: inline_description_source)
      description = page.evaluate(<<~JAVASCRIPT)
        (() => {
          const root = FetchUtilInlineDescriptionTest.clone(document.querySelector('main'), document);
          const items = [{ card: root.querySelector('.story-card'), text: 'Explore cartography workshops', url: '/learn/maps' }];
          return FetchUtilInlineDescriptionTest.description(root, items, { includeInlineProse: true });
        })()
      JAVASCRIPT

      expect(description).to eq("Learn with [experienced teachers](https://learning.example/learn/maps) in small groups.\n\n" \
                                "Explore local history at your own pace.\n\nLearn from Jane Example about field research.")
    end
  end

  it "interleaves recovered prose with records that have no retained card node" do
    html = <<~HTML
      <html><body><main>
        <div>Begin with local geography and observation.</div>
        <a href="/learn/maps">Explore cartography workshops</a>
        <div>Continue into outdoor research and collaboration.</div>
        <a href="/learn/fieldwork">Explore practical fieldwork</a>
        <div>Contact the teaching team after choosing a workshop.</div>
      </main></body></html>
    HTML
    with_url_page("https://learning.example/catalog", html) do |page|
      page.add_script_tag(content: inline_description_source)
      result = page.evaluate(<<~JAVASCRIPT)
        (() => {
          const root = FetchUtilInlineDescriptionTest.clone(document.querySelector('main'), document);
          const items = Array.from(root.querySelectorAll('a')).map(link => ({ text: link.textContent, url: link.href }));
          const markdown = FetchUtilInlineDescriptionTest.render({ root, items });
          root.querySelectorAll('div').forEach(node => node.remove());
          return { markdown, unchanged: FetchUtilInlineDescriptionTest.render({ root, items }) };
        })()
      JAVASCRIPT

      expected = ["Begin with local geography", "/learn/maps)", "Continue into outdoor research", "/learn/fieldwork)", "Contact the teaching team"]
      positions = expected.map { |text| result["markdown"].index(text) }
      expect(positions).not_to include(nil)
      expect(positions).to eq(positions.sort)
      expect(result["unchanged"]).to eq("")
    end
  end
end
