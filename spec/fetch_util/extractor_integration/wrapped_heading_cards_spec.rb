# frozen_string_literal: true

require "spec_helper"
require "support/extractor_integration_helpers"

RSpec.describe "Wrapped heading card ownership" do
  include_context "extractor integration helpers"

  def wrapped_heading_items(html, url: "https://publisher.example/", fallback: false, flat: false)
    root = File.expand_path("../../..", __dir__)
    source = File.readlines(File.join(root, "websieve/manifest.txt"), chomp: true)
                 .reject { |line| line.empty? || line.start_with?("#") }
                 .map { |path| File.read(File.join(root, "websieve", path)) }.join("\n")
    outro = File.read(File.join(root, "websieve/99_outro.js"))
    export = <<~JS
      global.__wrappedHeadingItems = function(fallback, flat) {
        var clone = visibleListClone(document.querySelector('main'));
        if (flat) return listMarkdown(extractListItems(clone));
        if (fallback) return listMarkdown(extractFallbackHeadlineItems(clone));
        var extraction = sectionedListExtraction(clone);
        return extraction && extraction.items.map(function(item) {
          return { text: item.text, url: item.url, detail: item.detail };
        });
      };
    JS
    with_url_page(url, html) do |page|
      page.add_script_tag(content: source.delete_suffix(outro) + export + outro)
      JSON.parse(page.evaluate("JSON.stringify(window.__wrappedHeadingItems(#{fallback}, #{flat}))"))
    end
  end

  def wrapped_heading_page(count: 3, wrapped: true)
    sections = %w[Regional International].map do |section|
      cards = count.times.map do |index|
        title = "#{section} report number #{index}"
        heading = wrapped ? "<a href='/#{section}/#{index}'><h3>#{title}</h3></a>" : "<h3><a href='/#{section}/#{index}'>#{title}</a></h3>"
        "<div class='grid-item'><div class='index-card'>#{heading}</div></div>"
      end.join
      "<section><h2>#{section}</h2><div class='card-grid'>#{cards}</div></section>"
    end.join
    "<html><head><title>Regional daily reports</title></head><body><main><article>#{sections}</article></main></body></html>"
  end

  it "treats both heading/link arrangements as the same independent records" do
    wrapped = wrapped_heading_items(wrapped_heading_page)
    nested = wrapped_heading_items(wrapped_heading_page(wrapped: false))
    expect(wrapped).to eq(nested)
    expect(wrapped.map { |item| item.fetch("text") }).to eq(
      %w[Regional International].flat_map { |section| 3.times.map { |index| "#{section} report number #{index}" } }
    )
  end

  it "keeps local descriptions and excludes genuinely hidden records" do
    html = wrapped_heading_page.sub("</h3></a>", "</h3><p>Only the first regional record owns this description.</p></a>")
    html = html.sub("<div class='index-card'><a href='/Regional/1'", "<div class='index-card' style='display:none'><a href='/Regional/1'")
    html = html.sub("<a href='/Regional/0'>", "<a href='/Regional/0'><div class='Feature-styles__CardStyled-x'>")
               .sub("</p></a>", "</p></div></a>")
    items = wrapped_heading_items(html)
    expect(items.length).to eq(5)
    expect(items.first.fetch("detail")).to include("Only the first regional")
    expect(items.drop(1).map { |item| item.fetch("detail") }.join).not_to include("Only the first regional")
  end

  it "preserves every materialized record in DOM order without a presentation cap" do
    items = wrapped_heading_items(wrapped_heading_page(count: 125))
    expect(items.map { |item| item.fetch("url") }).to eq(
      %w[Regional International].flat_map { |section| 125.times.map { |index| "https://publisher.example/#{section}/#{index}" } }
    )
  end

  it "renders the owned description when the headline fallback selects the card" do
    html = wrapped_heading_page.sub("</h3></a>", "</h3><p>Only this record owns its complete local description.</p></a>")
    markdown = wrapped_heading_items(html, fallback: true)
    expect(markdown.scan("Only this record owns its complete local description.").length).to eq(1)
    expect(markdown.lines.first).to include("/Regional/0", "Only this record owns")
  end

  it "retains a short series heading and the longer episode heading in one record" do
    html = wrapped_heading_page.sub(
      "<h3>Regional report number 0</h3>",
      "<h2>Daily News</h2><h3>An independently named episode about public transit</h3>"
    )
    markdown = wrapped_heading_items(html, flat: true)
    expect(markdown.lines.first).to include(
      "[Daily News - An independently named episode about public transit](https://publisher.example/Regional/0)"
    )
    expect(markdown.lines.drop(1).join).not_to include("Daily News", "public transit")
    expect(markdown.scan("Daily News").length).to eq(1)
    expect(markdown.scan("public transit").length).to eq(1)
  end
end
