# frozen_string_literal: true

require "spec_helper"
require "support/extractor_integration_helpers"

RSpec.describe "Named anchor card ownership" do
  include_context "extractor integration helpers"

  def named_anchor_records(count: 2)
    root = File.expand_path("../../..", __dir__)
    sources = File.readlines(File.join(root, "websieve/manifest.txt"), chomp: true).reject do |line|
      line.empty? || line.start_with?("#")
    end
    source = sources.map { |path| File.read(File.join(root, "websieve", path)) }.join("\n")
    source = source.sub(File.read(File.join(root, "websieve/99_outro.js")), <<~JS)
      window.__namedAnchorRecords = function() {
        var root = visibleListClone(document.querySelector("main"));
        var result = sectionedListExtraction(root);
        return result ? result.items.map(function(item) {
          return { text: item.text, url: item.url, detail: item.detail };
        }) : [];
      };
      window.__namedAnchorEvidence = function() {
        var root = visibleListClone(document.querySelector("main"));
        return Array.from(root.querySelectorAll("[data-probe]")).map(function(link) {
          return genericListDirectAnchorCard(link, link.parentElement);
        });
      };
      })(window);
    JS
    cards = count.times.map do |index|
      <<~HTML
        <a href="/tools/#{index}"><span class="tool-name">Tool number #{index}</span>
          <span class="tool-desc">Independent description for tool #{index}.</span></a>
      HTML
    end.join
    html = <<~HTML
      <html><head><title>Independent tools directory</title></head><body><main>
        <h1>Independent tools directory</h1>
        <section><h2>Image utilities</h2><div>#{cards}</div></section>
        <section><h2>Document utilities</h2><div>
          <a href="/merge"><span class="tool-name">Merge documents</span><span class="tool-desc">Keep every document page.</span></a>
          <a href="/split"><span class="tool-name">Split documents</span><span class="tool-desc">Separate selected document pages.</span></a>
        </div></section>
      </main></body></html>
    HTML

    with_url_page("https://publisher.example/tools", html) do |page|
      page.add_script_tag(content: source)
      yield page
    end
  end

  it "keeps paired span titles and descriptions in their own section records" do
    named_anchor_records do |page|
      records = JSON.parse(page.evaluate("JSON.stringify(window.__namedAnchorRecords())"))
      expect(records.map { |record| record.fetch("text") }).to eq(
        ["Tool number 0", "Tool number 1", "Merge documents", "Split documents"]
      )
      expect(records.map { |record| record.fetch("url") }).to eq(
        %w[https://publisher.example/tools/0 https://publisher.example/tools/1 https://publisher.example/merge https://publisher.example/split]
      )
      expect(records[0].fetch("detail")).not_to include("tool 1", "document page")
      expect(records[1].fetch("detail")).not_to include("tool 0", "document page")
    end
  end

  it "does not use empty, hidden or unsafe peers as independent record evidence" do
    named_anchor_records do |page|
      page.evaluate(<<~JS)
        document.querySelector("main").innerHTML = `
          <div><a data-probe href="/valid"><span class="tool-name">Valid title</span><span class="tool-desc">Local description.</span></a>
            <a href="/empty"><span class="tool-name">Empty description</span><span class="tool-desc"></span></a></div>
          <div><a data-probe href="/other"><span class="tool-name">Other title</span><span class="tool-desc">Other description.</span></a>
            <a href="https://user:secret@publisher.example/private"><span class="tool-name">Unsafe title</span><span class="tool-desc">Unsafe description.</span></a></div>
          <div><a data-probe href="/shown"><span class="tool-name">Visible title</span><span class="tool-desc">Visible description.</span></a>
            <a hidden href="/hidden"><span class="tool-name">Hidden title</span><span class="tool-desc">Hidden description.</span></a></div>`;
      JS
      expect(JSON.parse(page.evaluate("JSON.stringify(window.__namedAnchorEvidence())"))).to eq([false, false, false])
    end
  end

  it "retains every materialized record in DOM order without an item cap" do
    named_anchor_records(count: 125) do |page|
      records = JSON.parse(page.evaluate("JSON.stringify(window.__namedAnchorRecords())"))
      expect(records.length).to eq(127)
      expect(records.map { |record| record.fetch("url") }).to eq(
        125.times.map { |index| "https://publisher.example/tools/#{index}" } +
          %w[https://publisher.example/merge https://publisher.example/split]
      )
    end
  end
end
