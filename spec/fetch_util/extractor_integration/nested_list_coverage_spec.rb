# frozen_string_literal: true

require "support/extractor_integration_helpers"

RSpec.describe "Nested list material coverage" do
  include_context "extractor integration helpers"

  def nested_coverage(extra_count: 2, alter: "")
    root = File.expand_path("../../..", __dir__)
    source = File.readlines(File.join(root, "websieve/manifest.txt"), chomp: true)
                 .reject { |line| line.empty? || line.start_with?("#") }
                 .map { |path| File.read(File.join(root, "websieve", path)) }.join("\n")
    outro = File.read(File.join(root, "websieve/99_outro.js"))
    source = source.delete_suffix(outro) + <<~JS + outro
      global.__nestedCoverage = function() {
        function build(node, sections) {
          var root = visibleListClone(node);
          cleanupListRoot(root);
          var items = extractListItems(root);
          return {sourceNode:node, root:root, items:items, markdown:listMarkdown(items),
            sectionCount:sections, sectionRank:sections * 100000};
        }
        var inner = build(document.querySelector('#inner'), 2);
        var outer = build(document.querySelector('main'), 0);
        inner.sectionMarkdownWithDescription = listDescriptionMarkdown(inner.root, inner.items, {
          includeInlineProse:true, preserveTextLengths:true, preserveUnrepresentedText:true
        }) + '\\n\\n' + inner.markdown;
        #{alter}
        var before = outer.markdown;
        var result = nestedListMaterialCoverage(outer, inner);
        return JSON.stringify({accepted:!!result, unchanged:outer.markdown===before,
          urls:result && result.items.map(function(item) {return item.url;}), markdown:result && result.markdown});
      };
    JS
    record = lambda do |id|
      "<article class='card'><h3><a href='/record/#{id}'>Independent record #{id}</a></h3>" \
        "<p>Material description specific to record #{id}.</p><time>Publication date #{id}.</time></article>"
    end
    extra = extra_count.times.map { |i| record.call("extra-#{i}") }
    html = "<main>#{extra.shift}<div id='inner'><h2>First section</h2>" \
      "#{record.call("one")}#{record.call("two")}<h2>Second section</h2>" \
      "<p>Workshop on C*-algebras must survive in full.</p>#{record.call("three")}#{record.call("four")}" \
      "</div>#{extra.join}<p>Surrounding material terms must remain after every record.</p></main>"
    with_url_page("https://publisher.example/", html) do |page|
      page.add_script_tag(content: source)
      JSON.parse(page.evaluate("window.__nestedCoverage()"))
    end
  end

  it "preserves nested records, local dates, surrounding prose and DOM order without mutating either candidate" do
    result = nested_coverage
    expect(result.fetch("accepted")).to be true
    expect(result.fetch("unchanged")).to be true
    expect(result.fetch("urls")).to eq(%w[extra-0 one two three four extra-1].map { |id| "https://publisher.example/record/#{id}" })
    expect(result.fetch("markdown")).to include("Workshop on C*-algebras must survive in full.", "Publication date one.", "Surrounding material terms")
  end

  it "retains all 125 additional independently owned records" do
    result = nested_coverage(extra_count: 125)
    expect(result.fetch("accepted")).to be true
    expect(result.fetch("urls")).to eq((%w[extra-0 one two three four] + (1...125).map { |i| "extra-#{i}" }).map { |id| "https://publisher.example/record/#{id}" })
  end

  it "does not trade a child's local fields for another record that happens to contain the same text" do
    result = nested_coverage(alter: <<~JS)
      var item = outer.items.find(function(record) {return record.url.endsWith('/one');});
      item.card = document.createElement('article');
      item.detail = ''; item.summary = ''; item.time = ''; item.fields = [];
    JS
    expect(result.fetch("accepted")).to be false
  end

  it "does not promote additional records owned by a shared page container" do
    result = nested_coverage(alter: "outer.items.filter(function(item) {return item.url.includes('extra-');}).forEach(function(item) {item.card=outer.root;});")
    expect(result.fetch("accepted")).to be false
  end

  it "requires all original primary and secondary destinations" do
    missing_primary = nested_coverage(alter: "outer.items = outer.items.filter(function(item) {return !item.url.endsWith('/one');});")
    expect(missing_primary.fetch("accepted")).to be false
    missing_secondary = nested_coverage(
      alter: "inner.markdown += '\\n[Material reference](https://publisher.example/required-reference)'; " \
             "inner.sectionMarkdownWithDescription=inner.markdown;"
    )
    expect(missing_secondary.fetch("accepted")).to be false
  end

  it "requires the child's unlinked workshop prose as well as its records" do
    result = nested_coverage(alter: "outer.root.querySelector('#inner > p').remove();")
    expect(result.fetch("accepted")).to be false
  end

  it "does not confuse different numbers or mathematical operators in local material" do
    [["Required amount $1.", "Required amount $10."], ["Constraint n < 2.", "Constraint n > 2."]].each do |before, after|
      result = nested_coverage(alter: <<~JS)
        [[inner, #{JSON.generate(before)}], [outer, #{JSON.generate(after)}]].forEach(function(entry) {
          var item = entry[0].items.find(function(record) {return record.url.endsWith('/one');});
          item.card.querySelector('p').textContent = entry[1];
          item.detail = entry[1]; item.summary = entry[1]; item.fields = [];
        });
      JS
      expect(result.fetch("accepted")).to be false
    end
  end
end
