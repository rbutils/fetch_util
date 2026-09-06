# frozen_string_literal: true

RSpec.describe "FetchUtil extractor integration - list card fields" do
  include_context "extractor integration helpers"

  def list_card_fields_source
    root = File.expand_path("../../..", __dir__)
    source = File.readlines(File.join(root, "websieve/manifest.txt"), chomp: true).reject(&:empty?).map do |entry|
      File.read(File.join(root, "websieve", entry))
    end.join("\n")
    source.sub("})(window);", "global.FetchUtilListFieldsTest = { render: listMarkdown, candidate: listLinkCandidate, context: listPageContext }; })(window);")
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
end
