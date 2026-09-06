# frozen_string_literal: true

RSpec.describe "FetchUtil extractor integration - list card fields" do
  include_context "extractor integration helpers"

  def list_card_fields_source
    root = File.expand_path("../../..", __dir__)
    source = File.readlines(File.join(root, "websieve/manifest.txt"), chomp: true).reject(&:empty?).map do |entry|
      File.read(File.join(root, "websieve", entry))
    end.join("\n")
    source.sub(
      "})(window);",
      "global.FetchUtilListFieldsTest = { render: listMarkdown, candidate: listLinkCandidate, " \
      "context: listPageContext, description: listDescriptionMarkdown }; })(window);"
    )
  end

  def list_card_fields_html
    <<~HTML
      <html><head><title>Learning collections</title></head><body><main>
        <div class="story-card">
          <h2><a href="/learn/maps">Learn maps</a></h2>
          <span class="category">Cartography</span>
          <p>Choose projections and build detailed interactive maps for your community.</p>
          <p>Compare historical maps with current land use before publishing your results.</p>
          <figure><figcaption>Map comparison preview</figcaption></figure>
          <time datetime="2026-09-06">September 6, 2026</time>
        </div>
      </main></body></html>
    HTML
  end

  %w[formatted compact].each do |format|
    it "removes the matching fields without shifting later nodes in #{format} cards" do
      html = format == "compact" ? list_card_fields_html.gsub(/>\s+</, "><") : list_card_fields_html
      with_url_page("https://learning.example/collections", html) do |page|
        page.add_script_tag(content: list_card_fields_source)
        markdown = page.evaluate(<<~JAVASCRIPT)
          (() => {
            const card = document.querySelector('.story-card');
            const summary = card.querySelector('p').textContent;
            card.appendChild(card.querySelector('p').cloneNode(true));
            return FetchUtilListFieldsTest.render([{
              card, text: 'Learn maps', url: '/learn/maps',
              summary, category: 'Cartography', caption: 'Map comparison preview'
            }]);
          })()
        JAVASCRIPT

        [
          "Choose projections and build detailed interactive maps for your community.",
          "Compare historical maps with current land use before publishing your results.",
          "Cartography", "Map comparison preview", "2026-09-06"
        ].each do |text|
          expect(markdown.scan(text)).to eq([text])
        end
        expect(markdown).to include("[Learn maps](https://learning.example/learn/maps)")
        expect(markdown).not_to include("September 6, 2026")
      end
    end
  end

  it "keeps the focal inner record when removing an earlier wrapper field" do
    html = <<~HTML
      <html><head><title>Learning collections</title></head><body><main>
        <div class="post">
          <span class="category">Cartography</span>
          <div class="entry">
            <h2><a href="/learn/maps">Learn maps</a></h2>
            <p>Choose projections and build detailed interactive maps for your community.</p>
            <p>Compare historical maps with current land use before publishing your results.</p>
          </div>
          <div class="story-card">Unrelated sibling notes must not replace the selected record.</div>
        </div>
      </main></body></html>
    HTML
    with_url_page("https://learning.example/collections", html.gsub(/>\s+</, "><")) do |page|
      page.add_script_tag(content: list_card_fields_source)
      result = page.evaluate(<<~JAVASCRIPT)
        (() => {
          const card = document.querySelector('.post');
          const item = FetchUtilListFieldsTest.candidate(card.querySelector('a'), card, FetchUtilListFieldsTest.context());
          item.summary = card.querySelector('p').textContent;
          return {
            wrapperOwned: item.card === card,
            contentOwned: item.contentCard === card.querySelector('.entry'),
            markdown: FetchUtilListFieldsTest.render([item])
          };
        })()
      JAVASCRIPT

      expect(result.values_at("wrapperOwned", "contentOwned")).to eq([true, true])
      expect(result["markdown"]).to include(
        "[Learn maps](https://learning.example/learn/maps)",
        "Choose projections and build detailed interactive maps for your community.",
        "Compare historical maps with current land use before publishing your results."
      )
      expect(result["markdown"]).not_to include("Unrelated sibling notes")
    end
  end

  [false, true].each do |emitted|
    it "suppresses a card summary only when emitted is #{emitted}" do
      with_url_page("https://learning.example/collections", list_card_fields_html) do |page|
        page.add_script_tag(content: list_card_fields_source)
        result = page.evaluate(<<~JAVASCRIPT)
          (() => {
            const card = document.querySelector('.story-card');
            const item = FetchUtilListFieldsTest.candidate(card.querySelector('a'), card, FetchUtilListFieldsTest.context());
            const summary = card.querySelector('p').textContent;
            if (#{emitted}) item.summary = summary;
            return {
              rawDetail: item.detail,
              description: FetchUtilListFieldsTest.description(document.querySelector('main'), [item]),
              markdown: FetchUtilListFieldsTest.render([item])
            };
          })()
        JAVASCRIPT

        summary = "Choose projections and build detailed interactive maps for your community."
        expect(result["rawDetail"]).to include(summary)
        expect(result["description"].include?(summary)).to eq(!emitted)
        expect(result["markdown"].include?(summary)).to eq(emitted)
        expect(result["description"]).not_to include("Compare historical maps")
        expect(result.values_at("description", "markdown").join("\n").scan(summary)).to eq([summary])
      end
    end
  end

  it "restores a shared introduction once rather than into every linked item" do
    html = <<~HTML
      <html><head><title>Learning collections</title></head><body><main><div>
        <h2>Choose your learning pathway</h2>
        <p>Explore practical workshops with expert teachers who support your learning goals.</p>
        <a href="/learn/maps">Explore cartography workshops</a>
        <a href="/learn/science">Explore scientific research workshops</a>
        <a href="/learn/music">Explore music composition workshops</a>
      </div></main></body></html>
    HTML
    with_url_page("https://learning.example/collections", html) do |page|
      page.add_script_tag(content: list_card_fields_source)
      result = page.evaluate(<<~JAVASCRIPT)
        (() => {
          const card = document.querySelector('main > div');
          const items = Array.from(card.querySelectorAll('a')).map(link =>
            FetchUtilListFieldsTest.candidate(link, card, FetchUtilListFieldsTest.context()));
          return {
            sharedCard: items.every(item => item.card === card),
            description: FetchUtilListFieldsTest.description(card, items),
            markdown: FetchUtilListFieldsTest.render(items)
          };
        })()
      JAVASCRIPT

      summary = "Explore practical workshops with expert teachers who support your learning goals."
      expect(result["sharedCard"]).to be(true)
      expect(result["description"].scan(summary)).to eq([summary])
      expect(result["markdown"]).not_to include(summary)
      expect(result["markdown"].scan(%r{https://learning.example/learn/}).length).to eq(3)
    end
  end

  it "uses the rendered row detail instead of unused card fields as description evidence" do
    html = <<~HTML
      <html><head><title>Learning collections</title></head><body><main><table><tbody><tr><td>
        <a href="/learn/maps">Explore cartography workshops</a>
        <p>Compare historical maps with current land use before publishing your results.</p>
        <p>Choose projections and build detailed interactive maps for your community.</p>
      </td></tr></tbody></table></main></body></html>
    HTML
    with_url_page("https://learning.example/collections", html) do |page|
      page.add_script_tag(content: list_card_fields_source)
      result = page.evaluate(<<~JAVASCRIPT)
        (() => {
          const card = document.querySelector('tr');
          const paragraphs = card.querySelectorAll('p');
          const item = { card, text: 'Explore cartography workshops', url: '/learn/maps',
            detail: paragraphs[0].textContent, summary: paragraphs[1].textContent };
          return {
            description: FetchUtilListFieldsTest.description(document.querySelector('main'), [item]),
            markdown: FetchUtilListFieldsTest.render([item])
          };
        })()
      JAVASCRIPT

      expect(result["description"]).to eq("Choose projections and build detailed interactive maps for your community.")
      expect(result["markdown"]).to eq(
        "- [Explore cartography workshops](https://learning.example/learn/maps) - " \
        "Compare historical maps with current land use before publishing your results."
      )
    end
  end
end
