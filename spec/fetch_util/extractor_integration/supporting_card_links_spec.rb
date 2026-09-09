# frozen_string_literal: true

RSpec.describe "FetchUtil extractor integration - supporting card links" do
  include_context "extractor integration helpers"

  def render_supporting_cards(cards)
    with_url_page("https://articles.example/", "<main><h1>Latest articles</h1>#{cards}</main>") do |page|
      root = File.expand_path("../../..", __dir__)
      source = File.readlines(File.join(root, "websieve/manifest.txt"), chomp: true).reject(&:empty?).map do |entry|
        File.read(File.join(root, "websieve", entry))
      end.join("\n").sub("})(window);", "global.supportingClone = visibleListClone; " \
                                           "global.supportingItems = extractListItems; " \
                                           "global.supportingProof = genericListSupportingCard; " \
                                           "global.supportingSupplemental = listSupplementalDetail; " \
                                           "global.supportingText = listTextWithReferences; " \
                                           "global.supportingMarkdown = listMarkdown; })(window);")
      page.add_script_tag(content: source)
      page.evaluate(<<~JS)
        (() => {
          const main = document.querySelector('main'), original = main.outerHTML;
          const items = supportingItems(supportingClone(main));
          const postbody = main.querySelector('.postbody');
          const detached = postbody && postbody.cloneNode(true);
          const detachedReference = detached && detached.querySelector('p a[href]');
          const supplementalCard = main.querySelector('[data-supporting-fixture]');
          const supplementalContent = supplementalCard && supplementalCard.querySelector('.postbody');
          const supplementalPrimary = supplementalContent && supplementalContent.querySelector('h2 a[href]');
          const supplementalItem = supplementalPrimary && {text: supplementalPrimary.textContent,
            url: supplementalPrimary.href, card: supplementalCard, contentCard: supplementalContent};
          const authorReference = main.querySelector('.author a[href]');
          const unsafeReference = document.createElement('a');
          unsafeReference.href = 'https://fixture-user:fixture-secret@example.net/private';
          unsafeReference.textContent = 'private label';
          const supportingCache = new WeakMap();
          let supportingQueries = 0;
          const querySelectorAll = detached && detached.querySelectorAll;
          const querySelector = detached && detached.querySelector;
          if (detached) detached.querySelectorAll = function(selector) {
            supportingQueries += 1;
            return querySelectorAll.call(this, selector);
          };
          if (detached) detached.querySelector = function(selector) {
            supportingQueries += 1;
            return querySelector.call(this, selector);
          };
          const detachedSupporting = detached && !!supportingProof(detachedReference, detached, supportingCache);
          const firstSupportingQueries = supportingQueries;
          if (detached) supportingProof(detachedReference, detached, supportingCache);
          return {items: items.map(item => ({text: item.text, url: item.url})),
                  markdown: supportingMarkdown(items), detachedSupporting: detachedSupporting,
                  supportingQueryCounts: [firstSupportingQueries, supportingQueries],
                  rootReference: authorReference && supportingText(authorReference),
                  unsafeRootReference: supportingText(unsafeReference),
                  supplementalText: supplementalContent && supportingText(supplementalContent),
                  supplemental: supplementalItem && supportingSupplemental(supplementalItem, [], supplementalCard),
                  unchanged: main.outerHTML === original};
        })()
      JS
    end
  end

  it "keeps all supporting references in their primary records without promoting them" do
    cards = 125.times.map do |index|
      <<~HTML
        <div class="story">
          <div class="postbody"><h2><a href="/articles/#{index}">Article #{index}</a></h2>
          <p>Summary #{index} cites <a href="/evidence/#{index}">evidence #{index}</a>.</p>
          <p>Additional statement #{index} with <a href="/details/#{index}">details #{index}</a>.</p></div>
          <div class="author"><a href="/authors/#{index}">Author #{index}</a></div>
          <div class="category"><a href="/topics/#{index}">Topic #{index}</a></div>
        </div>
      HTML
    end.join
    result = render_supporting_cards(cards)
    expect(result.fetch("items")).to eq(125.times.map do |index|
      {"text" => "Article #{index}", "url" => "https://articles.example/articles/#{index}"}
    end)
    expect(result.fetch("detachedSupporting")).to be(true)
    expect(result.fetch("supportingQueryCounts").first).to be > 0
    expect(result.fetch("supportingQueryCounts").last).to eq(result.fetch("supportingQueryCounts").first)
    expect(result.fetch("rootReference")).to eq("[Author 0](https://articles.example/authors/0)")
    expect(result.fetch("unsafeRootReference")).to eq("private label")
    (0...125).each do |index|
      line = result.fetch("markdown").lines.fetch(index)
      expect(line).to include("[evidence #{index}](https://articles.example/evidence/#{index})")
      expect(line).to include("[details #{index}](https://articles.example/details/#{index})")
      expect(line).to include("[Author #{index}](https://articles.example/authors/#{index})")
      expect(line).to include("[Topic #{index}](https://articles.example/topics/#{index})")
      expect(line).not_to include("Summary #{(index + 1) % 125}")
    end
    expect(result.fetch("unchanged")).to be(true)
  end

  it "keeps supporting lists inside their primary record" do
    card = <<~HTML
      <div class="story" data-supporting-fixture><div class="postbody">
        <h2><a href="/articles/primary">Primary article title</a></h2>
        <p>Article introduction with enough material to establish this record.</p>
        <ul><li><a href="/sources/one">First source</a></li><li><a href="/sources/two">Second source</a></li></ul>
      </div></div>
    HTML
    result = render_supporting_cards(card)
    expect(result.fetch("supplementalText")).to include("First source", "Second source")
    expect(result.fetch("supplemental")).to include(
      "[First source](https://articles.example/sources/one)",
      "[Second source](https://articles.example/sources/two)"
    )
  end

  it "does not let a collection wrapper claim its linked card peers" do
    cards = <<~HTML
      <div class="card-grid">
        <a class="card-grid-card" href="/articles/first"><h3>First linked card</h3><p>First summary.</p></a>
        <a class="card-grid-card" href="/articles/second"><h3>Second linked card</h3><p>Second summary.</p></a>
        <a class="card-grid-card" href="/articles/third"><h3>Third linked card</h3><p>Third summary.</p></a>
      </div>
    HTML
    result = render_supporting_cards(cards)
    expect(result.fetch("items")).to eq([
      {"text" => "First linked card", "url" => "https://articles.example/articles/first"},
      {"text" => "Second linked card", "url" => "https://articles.example/articles/second"},
      {"text" => "Third linked card", "url" => "https://articles.example/articles/third"}
    ])
  end

  it "keeps unsafe and hidden supporting destinations out of rendered output" do
    cards = 6.times.map do |index|
      <<~HTML
        <article class="story"><h2><a href="/articles/#{index}">Article #{index}</a></h2>
        <p>Public <a href="/references/#{index}">reference #{index}</a>,
        <a href="https://fixture-user:fixture-secret@example.net/private">private label</a> and
        <a href="javascript:void(0)">local action</a>.</p>
        <p hidden>Hidden <a href="https://hidden.example/#{index}">hidden reference</a>.</p></article>
      HTML
    end.join
    result = render_supporting_cards(cards)
    expect(result.fetch("items").length).to eq(6)
    expect(result.fetch("markdown")).not_to include("fixture-secret", "javascript:", "hidden.example", "hidden reference")
    (0...6).each do |index|
      expect(result.fetch("markdown")).to include("[reference #{index}](https://articles.example/references/#{index})")
      expect(result.fetch("markdown")).to include("private label", "local action")
    end
  end
end
