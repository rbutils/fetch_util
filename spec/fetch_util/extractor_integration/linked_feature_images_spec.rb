# frozen_string_literal: true

require "spec_helper"
require "support/extractor_integration_helpers"

RSpec.describe "Selected linked feature images" do
  include_context "extractor integration helpers"

  def linked_feature_markdown(html, records)
    root = File.expand_path("../..", File.dirname(FetchUtil::Extractor.instance_method(:extract).source_location.first))
    paths = File.readlines(File.join(root, "websieve/manifest.txt"), chomp: true).reject do |line|
      line.empty? || line.start_with?("#")
    end
    source = paths.map { |path| File.read(File.join(root, "websieve", path)) }.join("\n")
    outro = File.read(File.join(root, "websieve/99_outro.js"))
    raise "source-module test boundary changed" unless source.scan(outro).size == 1

    source = source.sub(outro, <<~JS)
      window.__linkedFeatureMarkdown = function(records) {
        var before = document.body.innerHTML;
        var root = visibleListClone(document.body);
        var items = records.map(function(record) {
          var link = root.querySelector("#" + record.id);
          var card = root.querySelector("#" + record.card);
          var summary = Array.from(card.children).find(function(node) { return node.localName === "p"; });
          return {sourceNode: link, card: card, url: link.href, text: link.textContent,
            summary: summary ? listTextWithReferences(summary) : ""};
        });
        var markdown = listMarkdown(items);
        return {markdown: markdown, unchanged: before === document.body.innerHTML};
      };
      })(window);
    JS
    with_url_page("https://publication.example.test/features/", html) do |page|
      before = page.evaluate("document.body.innerHTML")
      inject_standalone_extractor(page)
      page.add_script_tag(content: source)
      result = page.evaluate("window.__linkedFeatureMarkdown(#{JSON.generate(records)})")
      expect(page.evaluate("document.body.innerHTML")).to eq(before)
      expect(result.fetch("unchanged")).to be(true)
      result.fetch("markdown")
    end
  end

  def feature_markup(id, images:, heading: false)
    title = heading ? "<h2>Complete #{id} feature</h2>" : "<div class='title'>Complete #{id} feature</div>"
    <<~HTML
      <div id="card-#{id}"><a id="#{id}" href="/reports/#{id}">
        <div class="cover">#{images}</div>
        <div class="copy"><div class="label">Independent research</div>#{title}
          <div>The complete #{id} explanation retains its own evidence and conclusion.</div></div>
      </a><p>Independent closing material for #{id} with <a href="/references/#{id}">the original reference</a>.</p></div>
    HTML
  end

  def feature_records(*ids)
    ids.map { |id| { id: id, card: "card-#{id}" } }
  end

  it "retains each empty-alternative image owned by a selected non-heading feature link" do
    html = feature_markup("first", images: '<img src="/images/first.jpg" alt="">') +
           feature_markup("second", images: '<img src="/images/second.png" alt="">')
    markdown = linked_feature_markdown(html, feature_records("first", "second"))
    expect(markdown.scan("![](https://publication.example.test/images/first.jpg)").size).to eq(1)
    expect(markdown.scan("![](https://publication.example.test/images/second.png)").size).to eq(1)
    expect(markdown.index("/images/first.jpg")).to be < markdown.index("/images/second.png")
    %w[first second].each do |id|
      expect(markdown).to include("Complete #{id} feature", "The complete #{id} explanation retains its own evidence and conclusion.")
      expect(markdown).to include("Independent closing material for #{id}", "](https://publication.example.test/references/#{id})")
    end
  end

  it "retains a nonempty alternative and the existing semantic-heading image owner" do
    html = feature_markup("first", images: '<img src="/images/first.jpg" alt="First feature preview">') +
           feature_markup("second", images: '<img src="/images/second.png" alt="Second feature preview">', heading: true)
    markdown = linked_feature_markdown(html, feature_records("first", "second"))
    expect(markdown.scan("![First feature preview](https://publication.example.test/images/first.jpg)").size).to eq(1)
    expect(markdown.scan("![Second feature preview](https://publication.example.test/images/second.png)").size).to eq(1)
    expect(markdown).to include("Complete first feature", "Complete second feature")
  end

  it "preserves independent physical images even when all their destinations are identical" do
    image = '<img src="/images/repeated.png" alt="">'
    html = feature_markup("first", images: image + image) + feature_markup("second", images: image)
    markdown = linked_feature_markdown(html, feature_records("first", "second"))
    expect(markdown.scan("![](https://publication.example.test/images/repeated.png)").size).to eq(3)
    expect(markdown).to include("Complete first feature", "Complete second feature")
  end

  it "keeps hidden images and closed-disclosure bodies excluded from a visible feature" do
    images = <<~HTML
      <img src="/images/visible.png" alt="">
      <img hidden src="/images/hidden.png" alt="">
      <span style="display:none"><img src="/images/styled-hidden.png" alt=""></span>
      <details><summary>Complete disclosure label</summary><img src="/images/closed.png" alt=""></details>
    HTML
    markdown = linked_feature_markdown(feature_markup("first", images: images), feature_records("first"))
    expect(markdown.scan("![](https://publication.example.test/images/visible.png)").size).to eq(1)
    expect(markdown).to include("Complete disclosure label", "Complete first feature")
    expect(markdown).not_to include("/images/hidden.png", "/images/styled-hidden.png", "/images/closed.png")
  end

  it "does not materialize program or interface image descendants as feature resources" do
    images = <<~HTML
      <img src="/images/visible.png" alt="">
      <code><img src="/images/program.png" alt=""></code>
      <button><img src="/images/button.png" alt=""></button>
    HTML
    markdown = linked_feature_markdown(feature_markup("first", images: images), feature_records("first"))
    expect(markdown.scan("![](https://publication.example.test/images/visible.png)").size).to eq(1)
    expect(markdown).not_to include("/images/program.png", "/images/button.png")
    expect(markdown).to include("The complete first explanation retains its own evidence and conclusion.")
  end

  it "keeps unsafe image destinations out while retaining the selected feature and its safe image" do
    images = '<img src="javascript:alert(1)" alt=""><img src="/images/visible.png" alt="">'
    markdown = linked_feature_markdown(feature_markup("first", images: images), feature_records("first"))
    expect(markdown.scan("![](https://publication.example.test/images/visible.png)").size).to eq(1)
    expect(markdown).not_to include("javascript:")
    expect(markdown).to include("Complete first feature", "](https://publication.example.test/reports/first)")
  end
end
