# frozen_string_literal: true

require "spec_helper"
require "support/extractor_integration_helpers"

RSpec.describe "Deferred homepage record reveals" do
  include_context "extractor integration helpers"

  def deferred_reveal_result(body, path: "/")
    root = File.expand_path("../../..", __dir__)
    sources = File.readlines(File.join(root, "websieve/manifest.txt"), chomp: true).reject do |line|
      line.empty? || line.start_with?("#")
    end
    source = sources.map { |file| File.read(File.join(root, "websieve", file)) }.join("\n")
    source = source.sub(File.read(File.join(root, "websieve/99_outro.js")), <<~JS)
      window.__deferredReveal = function() {
        var node = document.querySelector("#candidate");
        var root = visibleListClone(document.querySelector("main"));
        return {
          qualified: deferredRevealContentNode(node),
          hidden: elementSubtreeHidden(node),
          urls: root ? Array.from(root.querySelectorAll("a[href]")).map(function(link) {
            return materializedHttpUrl(link.getAttribute("href"));
          }).filter(Boolean) : [],
          text: root ? normalizeText(root.textContent) : ""
        };
      };
      })(window);
    JS
    html = <<~HTML
      <html><head><title>Public services directory</title>
        <style>.reveal { opacity: 0; transform: translateY(14px); }</style></head>
      <body><main><h1>Public services directory</h1>#{body}</main></body></html>
    HTML
    with_url_page("https://publisher.example#{path}", html) do |page|
      page.add_script_tag(content: source)
      JSON.parse(page.evaluate("JSON.stringify(window.__deferredReveal())"))
    end
  end

  def reveal_records
    <<~HTML
      <a href="/first"><h3>First service</h3><p>Independent first description.</p></a>
      <a href="/second"><h3>Second service</h3><p>Independent second description.</p></a>
    HTML
  end

  it "recovers CSS reveal collections and preserves their independent descriptions" do
    result = deferred_reveal_result("<section id='candidate' class='reveal'>#{reveal_records}</section>")
    expect(result.fetch("qualified")).to be(true)
    expect(result.fetch("hidden")).to be(false)
    expect(result.fetch("urls")).to eq(%w[https://publisher.example/first https://publisher.example/second])
    expect(result.fetch("text")).to include("Independent first description.", "Independent second description.")
  end

  it "recovers translated press records whose titles and dates use paragraphs" do
    result = deferred_reveal_result(<<~HTML)
      <section id="candidate" style="opacity:0;will-change:transform;transform:translateY(100px)">
        <a href="/press/first"><p>Press release</p><p>September 1, 2026</p><p>First announcement</p></a>
        <a href="/press/second"><p>Press release</p><p>September 2, 2026</p><p>Second announcement</p></a>
      </section>
    HTML
    expect(result.fetch("hidden")).to be(false)
    expect(result.fetch("urls")).to eq(%w[https://publisher.example/press/first https://publisher.example/press/second])
    expect(result.fetch("text")).to include("September 1, 2026", "September 2, 2026")
  end

  it "recovers independently animated media and prose records without headings" do
    result = deferred_reveal_result(<<~HTML)
      <div>
        <div id="candidate" data-w-id="first" style="opacity:0"><img alt="First company">
          <div>Verify a public business profile.</div><a href="/first">Learn more</a></div>
        <div data-w-id="second" style="opacity:0"><img alt="Second company">
          <div>Verify a rental reservation.</div><a href="/second">Learn more</a></div>
      </div>
    HTML
    expect(result.fetch("hidden")).to be(false)
    expect(result.fetch("urls")).to eq(%w[https://publisher.example/first https://publisher.example/second])
  end

  it "keeps dialogs, inactive panels, navigation, access controls and truly hidden content excluded" do
    wrappers = [
      'role="dialog"', 'aria-hidden="true"', "inert", "hidden", 'data-state="closed"',
      'style="display:none"', 'style="visibility:hidden"', 'class="w-slide"',
      'class="tab-pane"', 'class="paywall"', 'role="navigation"', 'class="cookie-consent"',
      'class="protectedContent"', 'class="members-only"', 'class="subscriber-only"', 'data-state="locked"'
    ]
    wrappers.each do |attrs|
      result = deferred_reveal_result("<div #{attrs}><section id='candidate' class='reveal'>#{reveal_records}</section></div>")
      expect(result.fetch("qualified")).to be(false), attrs
      expect(result.fetch("urls")).to be_empty, attrs
    end
  end

  it "does not recover arbitrary opacity-zero containers or article-page animation states" do
    result = deferred_reveal_result("<section id='candidate' style='opacity:0'>#{reveal_records}</section>")
    expect(result.fetch("qualified")).to be(false)
    expect(result.fetch("urls")).to be_empty
    article = deferred_reveal_result("<section id='candidate' class='reveal'>#{reveal_records}</section>", path: "/article/story")
    expect(article.fetch("qualified")).to be(false)
    expect(article.fetch("urls")).to be_empty
  end

  it "does not qualify a collection using hidden, unsafe or duplicate-destination peers" do
    peers = [
      '<a hidden href="/hidden">', '<a href="javascript:alert(1)">',
      '<a href="https://user:secret@publisher.example/private">', '<a href="/first">'
    ]
    peers.each do |peer|
      result = deferred_reveal_result(<<~HTML)
        <div><a id="candidate" class="reveal" href="/first"><h3>First service</h3><p>Local description.</p></a>
          #{peer}<h3>Other service</h3><p>Other description.</p></a></div>
      HTML
      expect(result.fetch("qualified")).to be(false), peer
      expect(result.fetch("urls")).not_to include("https://publisher.example/first") unless peer.include?('href="/first"')
      expect(result.fetch("urls").join).not_to include("javascript:", "secret", "/hidden")
    end
  end

  it "retains all revealed records in DOM order while excluding hidden siblings" do
    cards = 125.times.map do |index|
      "<a href='/record/#{index}' #{"hidden" if index == 20}><h3>Record #{index}</h3><p>Record description #{index}.</p></a>"
    end.join
    result = deferred_reveal_result("<section id='candidate' class='reveal'>#{cards}</section>")
    expect(result.fetch("urls")).to eq(
      125.times.reject { |index| index == 20 }.map { |index| "https://publisher.example/record/#{index}" }
    )
  end
end
