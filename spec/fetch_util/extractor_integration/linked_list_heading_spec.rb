require "spec_helper"
require "nokogiri"

RSpec.describe "Physical linked-heading list-item ownership" do
  include_context "extractor integration helpers"

  def linked_heading_page
    @literal = "[\n\n### literal program heading\n\n](https://literal.publication.example.test/program)"
    cards = (1..2).map do |number|
      <<~HTML
        <li><a href="https://community.publication.example.test/discussion"><img src="/card-#{number}.png" alt="Discussion image #{number}"></a>
        <div><a href="https://community.publication.example.test/discussion"><p></p><h3>Discussion #{number}</h3><p></p></a></div>
        <p>Read the complete discussion description #{number} and retain its physical list ownership.</p></li>
      HTML
    end.join
    <<~HTML
      <!doctype html><html><head><title>Publication community reference</title></head>
      <body class="md-typeset"><main><article class="md-content__inner md-typeset">
      <h1>Publication community reference</h1>
      <p>Each independent image, heading destination and complete description belongs to its physical list item.</p>
      <ul>#{cards}</ul><pre><code class="language-text">#{@literal}</code></pre>
      <p>The final authored paragraph follows the complete reference list.</p>
      </article></main></body></html>
    HTML
  end

  it "keeps linked headings and complete descriptions indented inside their own list items" do
    with_url_page("https://docs.publication.example.test/community/", linked_heading_page) do |page|
      before = page.evaluate("document.body.innerHTML")
      payload = extract(page)
      native = Nokogiri::HTML5.fragment(payload.fetch("html"))
      items = native.css("ul > li")
      expect(items.length).to eq(2)
      expect(items.map { |item| item.at_css("h3").text }).to eq(["Discussion 1", "Discussion 2"])
      descriptions = (1..2).map do |number|
        "Read the complete discussion description #{number} and retain its physical list ownership."
      end
      expect(items.map { |item| item.css("p").map(&:text).reject(&:empty?).last }).to eq(descriptions)
      expect(items.map { |item| item.css("a[href]").map { |anchor| anchor["href"] } }).to eq(
        Array.new(2) { Array.new(2, "https://community.publication.example.test/discussion") }
      )
      markdown = payload.fetch("markdown")
      expect(markdown.lines.grep(/### \[Discussion [12]\]/).map(&:chomp)).to eq(
        (1..2).map { |number| "    ### [Discussion #{number}](https://community.publication.example.test/discussion)" }
      )
      expect(markdown.lines.grep(/Read the complete discussion description/).map(&:chomp)).to eq(
        descriptions.map { |description| "    #{description}" }
      )
      expect(page.evaluate("document.body.innerHTML")).to eq(before)
    end
  end

  it "preserves complete literal malformed-link text, independent image occurrences and source BODY" do
    with_url_page("https://docs.publication.example.test/community/", linked_heading_page) do |page|
      before = page.evaluate("document.body.innerHTML")
      payload = extract(page)
      native = Nokogiri::HTML5.fragment(payload.fetch("html"))
      expect(native.css("pre").map(&:text)).to eq([@literal])
      expect(native.css("img").map { |image| [image["src"], image["alt"]] }).to eq(
        (1..2).map { |number| ["https://docs.publication.example.test/card-#{number}.png", "Discussion image #{number}"] }
      )
      expect(payload.fetch("markdown")).to include("```\n#{@literal}\n```")
      expect(payload.fetch("markdown")).to include("The final authored paragraph follows the complete reference list.")
      expect(page.evaluate("document.body.innerHTML")).to eq(before)
    end
  end
end
