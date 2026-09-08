# frozen_string_literal: true

require "spec_helper"
require "support/extractor_integration_helpers"

RSpec.describe "Product navigation ownership" do
  include_context "extractor integration helpers"

  def product_navigation_records(body)
    root = File.expand_path("../../..", __dir__)
    paths = File.readlines(File.join(root, "websieve/manifest.txt"), chomp: true).reject do |line|
      line.empty? || line.start_with?("#")
    end
    source = paths.map { |path| File.read(File.join(root, "websieve", path)) }.join("\n")
    source = source.sub(File.read(File.join(root, "websieve/99_outro.js")), <<~JS)
      window.__productRecords = function() {
        var result = genericProductListContent({ title: "Product collection" });
        return result ? result.markdown : "";
      };
      })(window);
    JS
    with_url_page("https://publisher.example/", "<html><body>#{body}</body></html>") do |page|
      page.add_script_tag(content: source)
      JSON.parse(page.evaluate("JSON.stringify(window.__productRecords())")).scan(%r{\]\((https?://[^)]+)\)}).flatten
    end
  end

  def product_navigation_links(count, prefix: "visible")
    count.times.map do |index|
      "<article><a href='/products/#{prefix}-#{index}'>Independent product #{prefix} #{index}</a></article>"
    end.join
  end

  it "does not count product links owned by semantic navigation, even behind list items" do
    %w[header footer nav aside].each do |tag|
      expect(product_navigation_records("<#{tag}><ul><li>#{product_navigation_links(7)}</li></ul></#{tag}>")).to eq([])
    end
    %w[navigation menu menubar complementary contentinfo].each do |role|
      expect(product_navigation_records("<div role='#{role}'><li>#{product_navigation_links(7)}</li></div>")).to eq([])
    end
  end

  it "does not use menu products to promote an otherwise insufficient main collection" do
    body = "<nav>#{product_navigation_links(7, prefix: "menu")}</nav><main>#{product_navigation_links(3)}</main>"
    expect(product_navigation_records(body)).to eq([])
  end

  it "retains the complete main collection in DOM order without counting hidden or menu records" do
    body = "<header>#{product_navigation_links(7, prefix: "menu")}</header><main>#{product_navigation_links(127)}" \
           "<div hidden>#{product_navigation_links(4, prefix: "hidden")}</div></main>"
    expect(product_navigation_records(body)).to eq(
      127.times.map { |index| "https://publisher.example/products/visible-#{index}" }
    )
  end

  it "keeps a product's own image header without admitting products inside a page menu" do
    records = 127.times.map do |index|
      <<~HTML
        <div itemscope itemtype="https://schema.org/Product">
          <header><a href="/listing/#{index}"><img src="/image-#{index}.jpg" alt="Independent product #{index}"></a></header>
          <div><h2><a href="/listing/#{index}">Independent product #{index}</a></h2></div>
        </div>
      HTML
    end.join
    expect(product_navigation_records("<main>#{records}</main>")).to eq(
      127.times.map { |index| "https://publisher.example/listing/#{index}" }
    )
    expect(product_navigation_records("<header>#{records}</header>")).to eq([])
    expect(product_navigation_records("<nav>#{records}</nav>")).to eq([])
    expect(product_navigation_records(records.gsub(%r{href="/listing/}, 'href="https://user:secret@publisher.example/listing/'))).to eq([])
  end
end
