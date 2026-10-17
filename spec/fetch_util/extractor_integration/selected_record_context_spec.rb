# frozen_string_literal: true

require "spec_helper"
require "support/extractor_integration_helpers"

RSpec.describe "Selected physical record context" do
  include_context "extractor integration helpers"

  def selected_record_markdown(html, records)
    root = File.expand_path("../../..", __dir__)
    paths = File.readlines(File.join(root, "websieve/manifest.txt"), chomp: true).reject do |line|
      line.empty? || line.start_with?("#")
    end
    source = paths.map { |path| File.read(File.join(root, "websieve", path)) }.join("\n")
    outro = File.read(File.join(root, "websieve/99_outro.js"))
    raise "source-module test boundary changed" unless source.scan(outro).size == 1

    source = source.sub(outro, <<~JS)
      window.__selectedRecordMarkdown = function(records) {
        var before = document.body.innerHTML;
        var root = visibleListClone(document.body);
        var items = records.map(function(record) {
          var link = root.querySelector("#" + record.id);
          return {sourceNode: link, card: root.querySelector("#" + record.card),
            url: link.href, text: link.textContent, summary: record.summary || ""};
        });
        return {markdown: listMarkdown(items), unchanged: before === document.body.innerHTML};
      };
      })(window);
    JS
    with_url_page("https://publication.example.test/records/", html) do |page|
      before = page.evaluate("document.body.innerHTML")
      inject_standalone_extractor(page)
      page.add_script_tag(content: source)
      result = page.evaluate("window.__selectedRecordMarkdown(#{JSON.generate(records)})")
      expect(page.evaluate("document.body.innerHTML")).to eq(before)
      expect(result.fetch("unchanged")).to be(true)
      result.fetch("markdown")
    end
  end

  def selected_context_cards(image_label: "First report preview")
    <<~HTML
      <html><head><title>Independent publication records</title></head><body><main>
      <h1>Independent publication records</h1>
      <article id="feature" class="story-card">
        <figure><a href="/reports/first"><img src="/images/first.jpg" alt="#{image_label}"></a></figure>
        <h2><a id="first" href="/reports/first">First complete research report</a></h2>
        <div class="byline"><a rel="author" href="/people/avery">Avery Researcher</a></div>
        <div class="abstract-copy">The complete first analysis preserves its evidence and original conclusion.</div>
        <div class="formats"><a id="series" href="/collections/first">Independent series index</a>
          <a href="/classification/research">Research classification</a></div>
        <p hidden>Hidden record text must remain hidden.</p>
      </article>
      <article id="second-card" class="story-card">
        <h2><a id="second" href="/reports/second">Second independent report</a></h2>
        <div class="abstract-copy">The second physical record has its own complete explanation.</div>
        <div class="formats"><a href="/classification/research">Research classification</a></div>
      </article>
      </main></body></html>
    HTML
  end

  def evidenced_directory_markdown(include_child:)
    introduction = "This complete authored introduction explains the directory and remains with its own parent record before the individually selected resources."
    html = <<~HTML
      <main><h1>Public resource directory</h1><article id="directory">
        <h2><a id="directory-title" href="/documentation">Documentation and references</a></h2>
        <p id="directory-summary">#{introduction}</p>
        <section class="tall"><h3><a href="/news?type=blog">Blog</a></h3>
          <a href="/news?type=blog"></a><ul><a href="/news?type=blog"></a>
            <li id="child-card"><a href="/news?type=blog"></a><a id="child-title" href="/news/encoding">How to encode a complete media stream</a></li>
            <li id="archive-card"><a id="archive-title" href="/news?type=blog">Blog archive</a></li>
          </ul>
        </section>
        <div>Independent parent resource <a href="/manual">complete manual</a>.</div>
      </article></main>
    HTML
    records = [
      { id: "directory-title", card: "directory", summary: introduction },
      { id: "archive-title", card: "archive-card" }
    ]
    records.insert(1, { id: "child-title", card: "child-card" }) if include_child
    selected_record_markdown(html, records)
  end

  it "does not give a secondary topic the context of its separately selected heading record" do
    records = [
      { id: "first", card: "feature" }, { id: "series", card: "feature" }, { id: "second", card: "second-card" }
    ]
    markdown = selected_record_markdown(selected_context_cards, records)
    expect(markdown.scan("](https://publication.example.test/classification/research)").size).to eq(2)
    expect(markdown.scan("Avery Researcher").size).to eq(1)
    expect(markdown.scan("The complete first analysis preserves its evidence and original conclusion.").size).to eq(1)
    expect(markdown).to include("/reports/first", "/collections/first", "/reports/second", "The second physical record has its own complete explanation.")
    expect(markdown).not_to include("Hidden record text")
  end

  it "retains card context when no separately selected record owns its heading" do
    markdown = selected_record_markdown(selected_context_cards, [{ id: "series", card: "feature" }])
    expect(markdown).to include("/reports/first", "/collections/first", "Avery Researcher")
    expect(markdown).to include("The complete first analysis preserves its evidence and original conclusion.")
    expect(markdown.scan("](https://publication.example.test/classification/research)").size).to eq(1)
  end

  it "uses an already selected heading owner without requiring a nonempty image alternative" do
    records = [
      { id: "first", card: "feature" }, { id: "series", card: "feature" }, { id: "second", card: "second-card" }
    ]
    markdown = selected_record_markdown(selected_context_cards(image_label: ""), records)
    expect(markdown.scan("](https://publication.example.test/classification/research)").size).to eq(2)
    expect(markdown).to include("/reports/first", "/collections/first", "/reports/second")
    expect(markdown.scan("The complete first analysis preserves its evidence and original conclusion.").size).to eq(1)
  end

  it "renders a selected child card's context only in that child while retaining parent-owned resources" do
    html = <<~HTML
      <html><head><title>Complete resource directory</title></head><body><main>
      <h1>Complete resource directory</h1><article id="directory">
        <h2><a id="documentation" href="/documentation/">Documentation and examples</a></h2>
        <div class="owned-copy">The directory's independently authored introduction remains complete.</div>
        <section><h3><a href="/news/archive?kind=blog">Blog</a></h3>
          <a href="/news/archive?kind=blog"></a>
          <ul><a href="/news/archive?kind=blog"></a>
            <li id="child"><a href="/news/archive?kind=blog"></a>
              <a id="encoding" href="/news/encoding">Complete encoding instructions</a></li>
            <li id="archive-card"><a id="archive" href="/news/archive?kind=blog">Blog archive</a></li>
          </ul>
        </section>
        <div class="closing-copy">The complete directory's final reference remains <a href="/support/">independent support</a>.</div>
      </article></main></body></html>
    HTML
    records = [
      { id: "documentation", card: "directory" }, { id: "encoding", card: "child" }, { id: "archive", card: "archive-card" }
    ]
    markdown = selected_record_markdown(html, records)
    expect(markdown.scan("](https://publication.example.test/news/archive?kind=blog)").size).to eq(5)
    expect(markdown).to include("Documentation and examples", "Complete encoding instructions", "Blog archive")
    expect(markdown).to include("The directory's independently authored introduction remains complete.")
    expect(markdown).to include("The complete directory's final reference remains", "](https://publication.example.test/support/)")
  end

  it "does not repeat a selected child resource in a parent with authored record evidence" do
    markdown = evidenced_directory_markdown(include_child: true)
    expect(markdown.scan("](https://publication.example.test/news?type=blog)").size).to eq(5)
    expect(markdown).to include("This complete authored introduction", "individually selected resources.")
    expect(markdown).to include("[How to encode a complete media stream](https://publication.example.test/news/encoding)")
    expect(markdown).to include("[complete manual](https://publication.example.test/manual)")
  end

  it "retains an evidenced parent's child resource when that physical child is not separately selected" do
    markdown = evidenced_directory_markdown(include_child: false)
    expect(markdown.scan("](https://publication.example.test/news?type=blog)").size).to eq(5)
    expect(markdown).to include("How to encode a complete media stream", "This complete authored introduction")
    expect(markdown).to include("[complete manual](https://publication.example.test/manual)")
  end
end
