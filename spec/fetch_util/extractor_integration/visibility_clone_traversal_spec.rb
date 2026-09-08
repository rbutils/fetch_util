# frozen_string_literal: true

require "spec_helper"
require "support/extractor_integration_helpers"

RSpec.describe "Visibility clone traversal" do
  include_context "extractor integration helpers"

  def visibility_source
    root = File.expand_path("../../..", __dir__)
    files = File.readlines(File.join(root, "websieve/manifest.txt"), chomp: true).reject do |line|
      line.empty? || line.start_with?("#")
    end
    files.map { |file| File.read(File.join(root, "websieve", file)) }.join("\n").sub(
      "})(window);",
      "window.cloneVisibility = visibilityPrunedClone; window.pruneVisibility = pruneHiddenClone; })(window);"
    )
  end

  it "checks ancestor visibility once while retaining every deeply nested record in order" do
    records = (0...125).map { |index| "<p><a href='/record/#{index}'>Record #{index}</a></p>" }.join
    html = "<html><body><main>#{"<div>" * 40}#{records}#{"</div>" * 40}</main></body></html>"
    with_url_page("https://example.test/", html) do |page|
      page.add_script_tag(content: visibility_source)
      result = page.evaluate(<<~JS)
        (() => {
          const root = document.querySelector('main');
          const original = window.getComputedStyle;
          let calls = 0;
          window.getComputedStyle = function(node) { calls++; return original.call(window, node); };
          try {
            const clone = cloneVisibility(root);
            return { calls, nodes: root.querySelectorAll('*').length + 1,
              labels: Array.from(clone.querySelectorAll('a')).map(node => node.textContent) };
          } finally { window.getComputedStyle = original; }
        })()
      JS
      expect(result.fetch("labels")).to eq((0...125).map { |index| "Record #{index}" })
      expect(result.fetch("calls")).to be <= (result.fetch("nodes") * 2) + 8
    end
  end

  it "preserves visible descendants without leaking hidden ancestor text or attributes" do
    html = <<~HTML
      <html><body><main><section style="visibility:hidden" title="Hidden title">
        Hidden prose <a style="visibility:visible" href="/visible">Visible record</a>
        <span>Hidden child</span></section><div hidden><a href="/hidden">Hidden subtree</a></div>
        <div style="opacity:0"><a href="/transparent">Transparent subtree</a></div></main></body></html>
    HTML
    with_url_page("https://example.test/", html) do |page|
      page.add_script_tag(content: visibility_source)
      result = page.evaluate("cloneVisibility(document.querySelector('main')).outerHTML")
      expect(result).to include("Visible record", 'href="/visible"')
      expect(result).not_to include("Hidden title", "Hidden prose", "Hidden child", "Hidden subtree", "Transparent subtree")
      expect(page.evaluate("cloneVisibility(document.querySelector('[hidden] a')).textContent")).to eq("")
    end
  end

  it "keeps controlled roots explicit and checks each fresh clone after visibility changes" do
    with_url_page("https://example.test/", "<html><body><section hidden id='root'><p>Controlled text</p><p hidden>Hidden child</p></section></body></html>") do |page|
      page.add_script_tag(content: visibility_source)
      result = page.evaluate(<<~JS)
        (() => {
          const root = document.querySelector('#root');
          const clone = root.cloneNode(true);
          pruneVisibility(root, clone, [root]);
          const controlled = clone.textContent;
          const hidden = cloneVisibility(root).textContent;
          root.hidden = false;
          const visible = cloneVisibility(root).textContent;
          root.style.display = 'none';
          return { controlled, hidden, visible, changed: cloneVisibility(root).textContent };
        })()
      JS
      expect(result).to eq("controlled" => "Controlled text", "hidden" => "", "visible" => "Controlled text", "changed" => "")
    end
  end
end
