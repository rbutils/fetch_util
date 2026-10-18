# frozen_string_literal: true

require "spec_helper"
require "support/extractor_integration_helpers"

RSpec.describe "Selected physical record context" do
  include_context "extractor integration helpers"

  def selected_record_markdown(html, records, sectioned: false)
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
        var markdown;
        if (#{sectioned}) {
          var group = root.querySelector("#utilities");
          var heading = group.querySelector("h1, h2, h3, h4, h5, h6");
          var introduction = root.querySelector("#introduction");
          markdown = sectionedListMarkdownWithDescriptions({regions: [{node: group, cards: items,
            headingNode: heading, label: heading.textContent}]},
            [{node: introduction, markdown: markdownFor(introduction.outerHTML)}]);
        } else {
          markdown = listMarkdown(items);
        }
        return {markdown: markdown, unchanged: before === document.body.innerHTML};
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

  def shared_reference_group_markdown(selected:, select_repeated: false)
    introduction = "This complete directory introduction explains the independently selected software and its useful references."
    html = <<~HTML
      <section id="directory"><h1>Public service directory</h1>
        <p>#{introduction}</p>
        <div><h2>Open service software</h2><p>The service uses
          <a id="license" href="/licenses/free">Free software license</a>.
          The complete service explanation remains available to every reader.</p></div>
        <div id="utilities"><h3>Useful links</h3>
          <a href="/contact">Contact the maintainers</a>
          <a id="security" href="/security">Security guidance</a>
          <a id="source" href="/source">Source code</a>
          <a id="bugs" href="/issues">Report an issue</a>
          <a id="questions" href="/questions">Community questions</a>
          <a href="/wiki">Complete service wiki</a>
          <a href="/blog">Service updates</a>
          <a id="source-repeat" href="/source">Source code</a>
          <a href="/privacy">Privacy information</a>
        </div>
        <div>Independent closing resource <a href="/support">complete support manual</a>.</div>
      </section>
    HTML
    records = [{ id: "license", card: "directory", summary: introduction }]
    if selected
      records.concat(%w[security source bugs questions].map { |id| { id: id, card: "utilities" } })
      records << { id: "source-repeat", card: "utilities" } if select_repeated
    end
    markdown = selected_record_markdown(html, records)
    expect(markdown).to include(introduction, "The complete service explanation remains available to every reader.")
    expect(markdown).to include("Contact the maintainers", "Complete service wiki", "Privacy information", "Useful links")
    expect(markdown).to include("Independent closing resource", "](https://publication.example.test/support)")
    references = markdown.scan(%r{\[([^\]]+)\]\(https://publication\.example\.test/(contact|security|source|issues|questions|wiki|blog|privacy)\)})
    expected_references = [
      ["Contact the maintainers", "contact"], ["Security guidance", "security"],
      ["Source code", "source"], ["Report an issue", "issues"],
      ["Community questions", "questions"], ["Complete service wiki", "wiki"],
      ["Service updates", "blog"], ["Source code", "source"], ["Privacy information", "privacy"]
    ]
    expect(references).to eq(expected_references)
    markdown
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

  it "renders a selected shared reference group's complete context once without copying it into its ancestor" do
    markdown = shared_reference_group_markdown(selected: true)
    expect(markdown.scan("](https://publication.example.test/source)").size).to eq(2)
    expect(markdown.scan("](https://publication.example.test/contact)").size).to eq(1)
    expect(markdown.scan("Useful links").size).to eq(1)
  end

  it "retains a complete shared reference group when none of its references is separately selected" do
    markdown = shared_reference_group_markdown(selected: false)
    expect(markdown.scan("](https://publication.example.test/source)").size).to eq(2)
    expect(markdown.scan("](https://publication.example.test/contact)").size).to eq(1)
  end

  it "preserves two separately selected physical references to the same destination" do
    markdown = shared_reference_group_markdown(selected: true, select_repeated: true)
    expect(markdown.scan("](https://publication.example.test/source)").size).to eq(2)
    expect(markdown.scan("](https://publication.example.test/contact)").size).to eq(1)
    expect(markdown.scan("Useful links").size).to eq(1)
  end

  it "keeps independently selected table-cell references as separate list records" do
    html = <<~HTML
      <main><h1>Complete reference directory</h1><table><tbody><tr id="resource-row">
        <td><a id="first-reference" href="/references/first">First complete reference</a></td>
        <td><a id="second-reference" href="/references/second">Second complete reference</a></td>
      </tr></tbody></table></main>
    HTML
    records = %w[first-reference second-reference].map { |id| { id: id, card: "resource-row" } }
    markdown = selected_record_markdown(html, records)
    expect(markdown).to include("[First complete reference](https://publication.example.test/references/first)")
    expect(markdown).to include("[Second complete reference](https://publication.example.test/references/second)")
    expect(markdown.lines.count { |line| line.start_with?("- [") }).to eq(2)
  end

  it "renders a shared group's physical heading once when its section already represents that node" do
    html = <<~HTML
      <main><h1>Complete reference directory</h1>
        <p id="introduction">The complete introduction remains before every reference.</p>
        <div id="utilities"><h2>Useful links</h2>
          <a href="/contact">Contact the maintainers</a>
          <a id="security" href="/security">Security guidance</a>
          <a id="source" href="/source">Source code</a>
        </div>
      </main>
    HTML
    records = %w[security source].map { |id| { id: id, card: "utilities" } }
    markdown = selected_record_markdown(html, records, sectioned: true)
    expect(markdown).to include("The complete introduction remains before every reference.")
    expect(markdown.scan(%r{\[([^\]]+)\]\(https://publication\.example\.test/(contact|security|source)\)})).to eq(
      [["Contact the maintainers", "contact"], ["Security guidance", "security"], ["Source code", "source"]]
    )
    expect(markdown.scan(/^## Useful links$/).size).to eq(1)
  end
end
