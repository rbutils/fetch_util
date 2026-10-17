# frozen_string_literal: true

require "spec_helper"
require "support/extractor_integration_helpers"

RSpec.describe "Record metadata and page chrome" do
  include_context "extractor integration helpers"

  def metadata_card_records(count: 4, wrapper: "div", unrelated: false, rail: false, path: "/", aria_label: nil, byline: false, author_record: false)
    root = File.expand_path("../../..", __dir__)
    paths = File.readlines(File.join(root, "websieve/manifest.txt"), chomp: true).reject do |line|
      line.empty? || line.start_with?("#")
    end
    source = paths.map { |path| File.read(File.join(root, "websieve", path)) }.join("\n")
    source = source.sub(File.read(File.join(root, "websieve/99_outro.js")), <<~JS)
      window.__metadataRecords = function() {
        var clone = visibleListClone(document.body);
        cleanupListRoot(clone);
        return listMarkdown(extractFallbackHeadlineItems(clone));
      };
      })(window);
    JS
    cards = count.times.map do |index|
      heading = "<a href='/stories/#{index}' aria-label='#{aria_label}' #{"rel='author'" if author_record}><h3>Independent report number #{index}</h3></a>"
      heading = "<a href='/stories/#{index}'>Independent report number #{index}</a>" if byline
      metadata = unrelated ? "<a href='/share/#{index}'>Share this report</a>" : "#{heading}<p>Owned description for report #{index}.</p>"
      metadata = "<h4><a rel='author' href='/authors/#{index}'>Report author number #{index}</a></h4>" if byline
      "<div class='content-card'><img src='/image/#{index}.jpg' alt='Preview #{index}'>" \
        "#{heading if unrelated || byline}<div class='meta'>#{metadata}</div>" \
        "#{"<p>Owned description for report #{index}.</p>" if byline}</div>"
    end.join
    feed = "<#{wrapper} class='#{rail ? "video-collection" : "main-feed"}'>#{cards}</#{wrapper}>"
    feed = "<div class='right-rail'>#{feed}</div>" if rail
    html = "<html><body><section><h1>Independent reports</h1>#{feed}" \
           "<a href='/channel' aria-label='Follow us'>Social channel</a>" \
           "<div class='meta'><a href='/login'>Account settings</a></div></section></body></html>"
    with_url_page("https://publisher.example#{path}", html) do |page|
      page.add_script_tag(content: source)
      JSON.parse(page.evaluate("JSON.stringify(window.__metadataRecords())"))
    end
  end

  def represented_metadata_reference_deltas(independent: false)
    root = File.expand_path("../../..", __dir__)
    paths = File.readlines(File.join(root, "websieve/manifest.txt"), chomp: true).reject do |line|
      line.empty? || line.start_with?("#")
    end
    source = paths.map { |path| File.read(File.join(root, "websieve", path)) }.join("\n")
    outro = File.read(File.join(root, "websieve/99_outro.js"))
    raise "source-module test boundary changed" unless source.scan(outro).size == 1

    source = source.sub(outro, <<~JS)
      window.__representedMetadataReferences = function() {
        var root = document.querySelector('main'), card = document.querySelector('article');
        var primary = card.querySelector('h3 a'), before = document.body.innerHTML;
        var extraction = {root: root, items: [{card: card, sourceNode: primary, url: primary.href, text: primary.textContent}]};
        var descriptions = [{node: card, markdown: markdownFor(card.innerHTML)}];
        var references = listUnrepresentedMetadataReferences(extraction, descriptions);
        return {
          references: references.map(function(part) { return {id: part.node.id, markdown: part.markdown}; }),
          represented: descriptions[0].markdown,
          unchanged: before === document.body.innerHTML
        };
      };
      })(window);
    JS
    outside = '<p>A separate authored use of <a id="independent" rel="tag" ' \
              'href="/categories/research(v2)?scope=local#methods">Research classification</a> ' \
              'belongs to this other paragraph.</p>'
    outside = "" unless independent
    html = <<~HTML
      <html><head><title>Publication reports</title></head><body><main>
      <article><h3><a href="/reports/physical-record">Independent complete report</a></h3>
      <p>The complete owned report retains its original evidence and concluding explanation.</p>
      <p class="story-tags"><a id="represented" rel="tag" href="/categories/research(v2)?scope=local#methods">Research classification</a></p></article>
      #{outside}</main></body></html>
    HTML
    with_url_page("https://publication.example.test/", html) do |page|
      before = page.evaluate("document.body.innerHTML")
      inject_standalone_extractor(page)
      page.add_script_tag(content: source)
      result = page.evaluate("window.__representedMetadataReferences()")
      expect(page.evaluate("document.body.innerHTML")).to eq(before)
      result
    end
  end

  it "keeps primary headlines and their owned metadata rather than deleting the record" do
    markdown = metadata_card_records
    4.times do |index|
      expect(markdown).to include("Independent report number #{index}", "Owned description for report #{index}.")
    end
    expect(markdown).not_to include("Account settings")
  end

  it "still removes semantic navigation and unrelated metadata controls" do
    expect(metadata_card_records(wrapper: "nav")).not_to include("/stories/")
    markdown = metadata_card_records(unrelated: true)
    expect(markdown).to include("/stories/0")
    expect(markdown).not_to include("Share this report", "/share/")
  end

  it "keeps all materialized records in DOM order" do
    markdown = metadata_card_records(count: 125)
    expect(markdown.scan(%r{\]\((https?://[^)]+)\)}).flatten).to eq(
      125.times.map { |index| "https://publisher.example/stories/#{index}" }
    )
  end

  it "keeps structured homepage media collections without restoring article sidebars or menus" do
    markdown = metadata_card_records(count: 125, rail: true)
    expect(markdown.scan(%r{\]\((https?://[^)]+)\)}).flatten).to eq(
      125.times.map { |index| "https://publisher.example/stories/#{index}" }
    )
    expect(metadata_card_records(rail: true, wrapper: "nav")).not_to include("/stories/")
    expect(metadata_card_records(rail: true, path: "/articles/report")).not_to include("/stories/")
    expect(metadata_card_records(count: 3, rail: true)).not_to include("/stories/")
  end

  it "does not mistake a record's descriptive label for a follow control" do
    markdown = metadata_card_records(aria_label: "Audio: Follow the money in the economy")
    expect(markdown).to include("/stories/0", "Owned description for report 0.")
    expect(markdown).not_to include("/channel")
    expect(metadata_card_records(wrapper: "nav", aria_label: "Audio: Follow the money")).not_to include("/stories/")
  end

  it "does not promote heading-formatted bylines over the record's own destination" do
    markdown = metadata_card_records(byline: true, count: 125)
    expect(markdown.scan(%r{\]\((https?://[^)]+)\)}).flatten).to eq(
      125.times.map { |index| "https://publisher.example/stories/#{index}" }
    )
    expect(markdown).not_to include("/authors/")
    expect(markdown).to include("Owned description for report 124.")
  end

  it "retains author-directory records when the author link is the primary destination" do
    markdown = metadata_card_records(author_record: true)
    expect(markdown.scan(%r{\]\((https?://[^)]+)\)}).flatten).to eq(
      4.times.map { |index| "https://publisher.example/stories/#{index}" }
    )
  end

  it "does not append a category destination already represented by its physical owner" do
    result = represented_metadata_reference_deltas
    expect(result.fetch("represented")).to include("Research classification", "/categories/research%28v2%29?scope=local#methods")
    expect(result).to include("references" => [], "unchanged" => true)
  end

  it "retains a separate same-destination occurrence outside the represented owner" do
    result = represented_metadata_reference_deltas(independent: true)
    expect(result.fetch("references").map { |part| part.fetch("id") }).to eq(["independent"])
    expect(result.fetch("references").first.fetch("markdown")).to include("Research classification", "/categories/research%28v2%29?scope=local#methods")
    expect(result.fetch("unchanged")).to be(true)
  end
end
