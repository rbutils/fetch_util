# frozen_string_literal: true

require "spec_helper"
require "support/extractor_integration_helpers"

RSpec.describe "Mixed homepage product coverage" do
  include_context "extractor integration helpers"

  def mixed_homepage_products(count: 4, prose: true, path: "/")
    root = File.expand_path("../../..", __dir__)
    paths = File.readlines(File.join(root, "websieve/manifest.txt"), chomp: true).reject do |line|
      line.empty? || line.start_with?("#")
    end
    source = paths.map { |entry| File.read(File.join(root, "websieve", entry)) }.join("\n")
    source = source.sub(File.read(File.join(root, "websieve/99_outro.js")), <<~JS)
      window.__mixedProducts = function() {
        var metadata = { title: "Services and devices" };
        var result = mixedHomepageProductListContent(metadata, genericProductListContent(metadata));
        return result ? result.sectionMarkdownWithDescription || result.markdown : null;
      };
      })(window);
    JS
    services = 4.times.map do |index|
      description = prose ? "<p>Independent service description #{index} with all billing terms.</p>" : ""
      "<article><h2><a href='/services/#{index}'>Independent service offering #{index}</a></h2>#{description}</article>"
    end.join
    products = count.times.map do |index|
      "<article><a href='/products/#{index}'><img src='/images/#{index}.webp' alt='Independent device #{index}'></a></article>"
    end.join
    intro = prose ? "<p>Introductory service conditions remain before every record.</p>" : ""
    ending = prose ? "<p>Final repayment conditions remain after every device.</p>" : ""
    html = "<html><body><main><div><h1>Services and devices</h1>#{intro}#{services}" \
           "<div class='product-grid'>#{products}</div>#{ending}</div></main></body></html>"
    with_url_page("https://publisher.example#{path}", html) do |page|
      page.add_script_tag(content: source)
      JSON.parse(page.evaluate("JSON.stringify(window.__mixedProducts())"))
    end
  end

  it "retains narrative, product records and their descriptions in source order" do
    markdown = mixed_homepage_products
    expect(markdown).not_to be_nil
    expect(markdown.scan(%r{\]\((https?://[^)]+)\)}).flatten).to eq(
      4.times.map { |index| "https://publisher.example/services/#{index}" } +
        4.times.map { |index| "https://publisher.example/products/#{index}" }
    )
    expect(markdown.index("Introductory service conditions")).to be < markdown.index("/services/0")
    expect(markdown.index("Final repayment conditions")).to be > markdown.index("/products/3")
    4.times { |index| expect(markdown).to include("Independent service description #{index} with all billing terms.") }
  end

  it "does not promote label-only navigation or a non-homepage article route" do
    expect(mixed_homepage_products(prose: false)).to be_nil
    expect(mixed_homepage_products(path: "/articles/report")).to be_nil
  end

  it "preserves every product without a presentation cap" do
    markdown = mixed_homepage_products(count: 125)
    expect(markdown.scan(%r{\]\((https?://[^)]+)\)}).flatten).to eq(
      4.times.map { |index| "https://publisher.example/services/#{index}" } +
        125.times.map { |index| "https://publisher.example/products/#{index}" }
    )
  end
end
