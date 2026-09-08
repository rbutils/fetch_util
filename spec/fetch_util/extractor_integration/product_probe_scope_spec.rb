# frozen_string_literal: true

RSpec.describe "FetchUtil product probe scope" do
  include_context "extractor integration helpers"

  def product_probe_source
    root = File.expand_path("../../..", __dir__)
    source = File.readlines(File.join(root, "websieve/manifest.txt"), chomp: true)
                 .reject { |line| line.empty? || line.start_with?("#") }
                 .map { |path| File.read(File.join(root, "websieve", path)) }.join("\n")
    source.sub("})(window);", <<~JAVASCRIPT)
      global.probeProducts = function() {
        var scans = 0;
        var original = Element.prototype.querySelectorAll;
        Element.prototype.querySelectorAll = function(selector) {
          if (selector === "a[href][class*='title' i], [class*='title' i] a[href]") scans += 1;
          return original.call(this, selector);
        };
        try {
          var result = genericProductListContent({title: document.title});
          return {scans: scans, items: result && result.productListItems};
        } finally {
          Element.prototype.querySelectorAll = original;
        }
      };
      })(window);
    JAVASCRIPT
  end

  it "rejects unrelated records before searching their shared container for product titles" do
    links = (0...125).map { |index| "<span><a href='/news/#{index}'>Independent research story #{index}</a></span>" }.join
    html = "<html><head><title>Research portal</title></head><body><main><div>#{links}</div></main></body></html>"
    with_url_page("https://research.example/", html) do |page|
      page.add_script_tag(content: product_probe_source)
      expect(page.evaluate("probeProducts()")).to eq("scans" => 0, "items" => nil)
    end
  end

  it "keeps every eligible product's preferred title, destination and local price" do
    records = (0...125).map do |index|
      "<article class='product'><a href='/p/#{index}'><img src='/image/#{index}.jpg' alt='Catalog art #{index}'></a>" \
        "<h2 class='title'><a href='/p/#{index}'>Detailed instrument model #{index}</a></h2>" \
        "<span class='price'>$#{index + 1}.00</span></article>"
    end.join
    html = "<html><head><title>Instrument catalog</title></head><body><main>#{records}</main></body></html>"
    with_url_page("https://research.example/", html) do |page|
      page.add_script_tag(content: product_probe_source)
      items = page.evaluate("probeProducts().items")
      expect(items.map { |item| item.fetch("text") }).to eq((0...125).map { |index| "Detailed instrument model #{index}" })
      expect(items.map { |item| item.fetch("url") }).to eq((0...125).map { |index| "https://research.example/p/#{index}" })
      items.each_with_index { |item, index| expect(item.fetch("detail")).to include("$#{index + 1}.00") }
    end
  end
end
