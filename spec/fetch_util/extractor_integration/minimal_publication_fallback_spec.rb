# frozen_string_literal: true

require "spec_helper"
require "support/extractor_integration_helpers"

RSpec.describe "Complete minimal publication ownership" do
  include_context "extractor integration helpers"

  def minimal_publication_record(label, name, href: "/reports/#{label}", hidden: false)
    style = hidden ? ' style="display: none"' : ""
    %(<a href="#{href}"#{style}><h3>Complete #{label} research report</h3><p class="author">#{name}</p>) +
      %(<p>The #{label} report preserves the complete evidence, the independent analysis, and every published methodological qualification.</p></a>)
  end

  def minimal_publication_page(records, headline: true, interface: false, tail: "")
    heading = headline ? '<h1 class="publication-heading">Research bulletins</h1>' : ""
    group = interface ? "<nav>#{records}</nav>" : "<section>#{records}</section>"
    <<~HTML
      <html><head><title>Research bulletins</title></head><body><main>
        <article id="post-42" class="type-page">#{heading}<div class="publication-content">
          <p>This publication presents independently authored research, complete reports, and their public methodological evidence.</p>
          #{group}</div></article></main>#{tail}</body></html>
    HTML
  end

  def inspect_minimal_publication(html, url: "https://publication.example.test/bulletins/")
    with_url_page(url, html) do |page|
      inject_standalone_extractor(page)
      before = page.evaluate("document.body.innerHTML")
      payload = page.evaluate("window.FetchUtilExtract.extract({reader_mode: true})")
      expect(page.evaluate("document.body.innerHTML")).to eq(before)
      yield payload
    end
  end

  def expect_complete_minimal_publication(payload, href: nil)
    expect(payload.fetch("title")).to eq("Research bulletins")
    expect(payload.fetch("byline")).to be_nil
    markdown = payload.fetch("markdown")
    expect(markdown).to include("This publication presents independently authored research, complete reports, and their public methodological evidence.")
    %w[alpha beta].zip(["Ari Reader", "Bo Editor"]).each do |label, name|
      expect(markdown.scan("Complete #{label} research report").size).to eq(1)
      expect(markdown.scan(name).size).to eq(1)
      expect(
        markdown.scan("The #{label} report preserves the complete evidence, the independent analysis, and every published methodological qualification.").size
      ).to eq(1)
      expect(markdown).to include("https://publication.example.test#{href || "/reports/#{label}"}")
    end
    expect(markdown.index("Complete alpha research report")).to be < markdown.index("Complete beta research report")
  end

  def minimal_preference_probe(html, url: "https://publication.example.test/bulletins/", mismatched: false, projection: nil)
    root = File.expand_path("../..", File.dirname(FetchUtil::Extractor.instance_method(:extract).source_location.first))
    paths = File.readlines(File.join(root, "websieve/manifest.txt"), chomp: true).reject { |path| path.empty? || path.start_with?("#") }
    source = paths.map { |path| File.read(File.join(root, "websieve", path)) }.join("\n")
    outro = File.read(File.join(root, "websieve/99_outro.js"))
    raise "source probe closure changed" unless source.scan(outro).size == 1

    callback = <<~JS
      window.__minimalPreference216 = function() {
        var before = document.body.innerHTML;
        var owner = document.querySelector('article');
        var card = owner.querySelector('a[href]');
        var primary = {html: card.innerHTML, textContent: card.textContent, title: document.title, readerMode: true, contentType: 'article'};
        var fallback = {html: owner.innerHTML, textContent: owner.textContent, title: document.title, readerMode: false, contentType: 'article'};
        if (#{mismatched}) fallback.html += '<p>Unowned extra fallback prose.</p>';
        var operation = #{JSON.generate(projection)};
        if (operation) {
          var projected = document.createElement('div');
          projected.innerHTML = fallback.html;
          if (operation === 'quote') {
            var quote = projected.querySelector('blockquote');
            quote.replaceWith.apply(quote, Array.from(quote.childNodes));
          } else if (operation === 'list') {
            var ordered = projected.querySelector('ol');
            var unordered = document.createElement('ul');
            while (ordered.firstChild) unordered.appendChild(ordered.firstChild);
            ordered.replaceWith(unordered);
          } else if (operation === 'break') {
            projected.querySelector('br').remove();
          } else if (operation === 'target') {
            projected.querySelector('[id="bound-note"]').removeAttribute('id');
          }
          fallback.html = projected.innerHTML;
        }
        var selected = preferFallbackContent(primary, fallback);
        return {original: selected === primary, unchanged: before === document.body.innerHTML};
      };
      })(window);
    JS
    with_url_page(url, html) do |page|
      inject_standalone_extractor(page)
      page.add_script_tag(content: source.sub(outro, callback))
      value = page.evaluate("window.__minimalPreference216()")
      expect(value.fetch("unchanged")).to be(true)
      value.fetch("original")
    end
  end

  it "retains the introduction and both complete physically linked publications" do
    records = minimal_publication_record("alpha", "Ari Reader") + minimal_publication_record("beta", "Bo Editor")
    inspect_minimal_publication(minimal_publication_page(records)) { |payload| expect_complete_minimal_publication(payload) }
  end

  it "preserves independent records even when their declared destinations are equal" do
    records = minimal_publication_record("alpha", "Ari Reader", href: "/same") + minimal_publication_record("beta", "Bo Editor", href: "/same")
    inspect_minimal_publication(minimal_publication_page(records)) do |payload|
      expect_complete_minimal_publication(payload, href: "/same")
      expect(payload.fetch("markdown").scan("](https://publication.example.test/same)").size).to eq(2)
    end
  end

  it "does not restore a hidden peer or disclose a closed program" do
    records = minimal_publication_record("alpha", "Ari Reader") + minimal_publication_record("beta", "Bo Editor") +
              minimal_publication_record("Secret hidden record", "Hidden Reader", hidden: true)
    tail = '<aside><details><summary>Closed tools</summary><pre>Closed secret program</pre></details></aside>'
    inspect_minimal_publication(minimal_publication_page(records, tail: tail)) do |payload|
      expect_complete_minimal_publication(payload)
      expect(payload.fetch("markdown")).not_to include("Secret hidden record", "Hidden Reader", "Closed secret program")
    end
  end

  it "retains an independently owned article author, complete prose and literal program beside related records" do
    paragraphs = (1..5).map do |index|
      "Independent finding #{index} preserves the complete source evidence, its published interpretation, " \
        "and its separately documented methodological qualification."
    end
    related = minimal_publication_record("alpha", "Ari Reader") + minimal_publication_record("beta", "Bo Editor")
    html = <<~HTML
      <html><head><title>Independent investigation</title><meta name="author" content="Editorial Team"></head><body>
        <main><article><h1>Independent investigation</h1>#{paragraphs.map { |text| "<p>#{text}</p>" }.join}
          <pre><code>result = [1, 2, 3]\nputs result.inspect</code></pre><aside>#{related}</aside></article></main></body></html>
    HTML
    inspect_minimal_publication(html, url: "https://publication.example.test/investigation/") do |payload|
      expect(payload.fetch("title")).to eq("Independent investigation")
      expect(payload.fetch("byline")).to eq("Editorial Team")
      paragraphs.each { |text| expect(payload.fetch("markdown")).to include(text) }
      expect(payload.fetch("markdown")).to include("result = [1, 2, 3]\nputs result.inspect")
    end
  end

  it "requires a page headline, a non-interface collection, foreign destinations and exact source-owned fallback material" do
    records = minimal_publication_record("alpha", "Ari Reader") + minimal_publication_record("beta", "Bo Editor")
    expect(minimal_preference_probe(minimal_publication_page(records, headline: false))).to be(true)
    expect(minimal_preference_probe(minimal_publication_page(records, interface: true))).to be(true)
    expect(minimal_preference_probe(minimal_publication_page(records), url: "https://publication.example.test/reports/alpha")).to be(true)
    expect(minimal_preference_probe(minimal_publication_page(records), mismatched: true)).to be(true)
  end

  {
    quote: "<blockquote><p>A separately quoted methodological qualification.</p></blockquote>",
    list: "<ol><li>First ordered qualification.</li><li>Second ordered qualification.</li></ol>",
    break: "<p>Independent<br>word boundaries.</p>",
    target: '<p><a id="bound-note"></a>Bound methodological note.</p><p><a href="#bound-note">Read the bound note</a></p>'
  }.each do |kind, material|
    it "rejects a fallback that changes the physical #{kind} material while accepting the complete source" do
      records = minimal_publication_record("alpha", "Ari Reader") + minimal_publication_record("beta", "Bo Editor")
      html = minimal_publication_page(records).sub("</div></article>", "#{material}</div></article>")
      expect(minimal_preference_probe(html)).to be(false)
      expect(minimal_preference_probe(html, projection: kind.to_s)).to be(true)
    end
  end
end
