require "spec_helper"
require "support/extractor_integration_helpers"

RSpec.describe FetchUtil::Extractor do
  include_context "extractor integration helpers"

  def shared_context_records(html, url: "https://publisher.example/")
    root = File.expand_path("../../..", __dir__)
    source = File.readlines(File.join(root, "websieve/manifest.txt"), chomp: true)
                 .reject { |line| line.empty? || line.start_with?("#") }
                 .map { |path| File.read(File.join(root, "websieve", path)) }.join("\n")
    outro = File.read(File.join(root, "websieve/99_outro.js"))
    source = source.delete_suffix(outro) + <<~JS + outro
      window.__sharedContextRecords = function () {
        var root = visibleListClone(document.querySelector("main"));
        cleanupListRoot(root);
        var items = extractListItems(root, ["Material collection"]);
        var content = listContent({title: "Material collection"});
        return JSON.stringify({
          records: items.map(function(item) { return {url: item.url, markdown: listMarkdown([item]), owner: item.card.className}; }),
          markdown: content && content.markdown
        });
      };
    JS
    with_url_page(url, html) do |page|
      page.add_script_tag(content: source)
      JSON.parse(page.evaluate("window.__sharedContextRecords()"))
    end
  end

  it "keeps product prices and images inside their own tiles" do
    tiles = Array.new(6) do |index|
      <<~HTML
        <div class="product"><div class="product-tile">
          <a href="/goods/#{index}"><img src="/image-#{index}.jpg" alt="Own product image #{index}"></a>
          <a href="?wishlist=#{index}" title="Wishlist"></a>
          <a href="/goods/#{index}">Independently described product number #{index}</a>
          <span>Own price token #{index}</span>
        </div></div>
      HTML
    end.join
    result = shared_context_records("<main><h1>Material collection</h1><section class='newItemSlider'>#{tiles}</section></main>")
    expect(result.fetch("records").map { |record| record.fetch("url") }).to eq(
      Array.new(6) { |index| "https://publisher.example/goods/#{index}" }
    )
    result.fetch("records").each_with_index do |record, index|
      expect(record.fetch("markdown")).to include("Own price token #{index}", "Own product image #{index}")
      (0...6).reject { |other| other == index }.each do |other|
        expect(record.fetch("markdown")).not_to include("Own price token #{other}", "Own product image #{other}")
      end
    end
  end
end
