require "spec_helper"
require "support/extractor_integration_helpers"

RSpec.describe FetchUtil::Extractor do
  include_context "extractor integration helpers"

  def shared_context_records(html, url: "https://publisher.example/", root_selector: "main")
    root = File.expand_path("../../..", __dir__)
    source = File.readlines(File.join(root, "websieve/manifest.txt"), chomp: true)
                 .reject { |line| line.empty? || line.start_with?("#") }
                 .map { |path| File.read(File.join(root, "websieve", path)) }.join("\n")
    outro = File.read(File.join(root, "websieve/99_outro.js"))
    source = source.delete_suffix(outro) + <<~JS + outro
      window.__sharedContextRecords = function () {
        var root = visibleListClone(document.querySelector(#{root_selector.to_json}));
        cleanupListRoot(root);
        var items = extractListItems(root, ["Material collection"]);
        var content = listContent({title: "Material collection"});
        return JSON.stringify({
          records: items.map(function(item) { return {url: item.url, markdown: listMarkdown([item]), owner: item.card.className}; }),
          containerAuthor: cardField(root, ".author, .byline, [rel='author'], [itemprop='author']"),
          markdown: content && content.markdown
        });
      };
    JS
    with_url_page(url, html) do |page|
      page.add_script_tag(content: source)
      JSON.parse(page.evaluate("window.__sharedContextRecords()"))
    end
  end

  it "keeps product prices and images inside their own tiles" do
    tiles = Array.new(6) do |index|
      <<~HTML
        <div class="product"><div class="product-tile">
          <a href="/goods/#{index}"><img src="/image-#{index}.jpg" alt="Own product image #{index}"></a>
          <a href="?wishlist=#{index}" title="Wishlist"></a>
          <a href="/goods/#{index}">Independently described product number #{index}</a>
          <span>Own price token #{index}</span>
        </div></div>
      HTML
    end.join
    result = shared_context_records("<main><h1>Material collection</h1><section class='newItemSlider'>#{tiles}</section></main>")
    expect(result.fetch("records").map { |record| record.fetch("url") }).to eq(
      Array.new(6) { |index| "https://publisher.example/goods/#{index}" }
    )
    result.fetch("records").each_with_index do |record, index|
      expect(record.fetch("markdown")).to include("Own price token #{index}", "Own product image #{index}")
      (0...6).reject { |other| other == index }.each do |other|
        expect(record.fetch("markdown")).not_to include("Own price token #{other}", "Own product image #{other}")
      end
    end
  end

  it "does not repeat a page-level article beneath each destination" do
    links = Array.new(6) do |index|
      "<div><p>Independent explanatory prose number #{index} is retained for this service.</p>" \
        "<p><a href='/service/#{index}'>Explore independently named service #{index}</a></p></div>"
    end.join
    result = shared_context_records("<main><article class='type-page'><h1>Material collection</h1>#{links}</article></main>")
    expect(result.fetch("records").length).to eq(6)
    result.fetch("records").each_with_index do |record, index|
      (0...6).reject { |other| other == index }.each do |other|
        expect(record.fetch("markdown")).not_to include("Independent explanatory prose number #{other}")
      end
    end
    6.times do |index|
      expect(result.fetch("markdown").scan("Independent explanatory prose number #{index}").length).to eq(1)
    end
  end

  it "keeps a promotional destination when an untyped article wraps the homepage" do
    stories = Array.new(125) do |index|
      "<article class='story'><h3><a href='/story/#{index}'>Independently named story #{index}</a></h3>" \
        "<p>Local story information number #{index}.</p></article>"
    end.join
    result = shared_context_records(<<~HTML)
      <main><article class="page-shell">
        <h1>Material collection</h1>
        <section class="support-section"><h2>Household support</h2>
          <p>Available rebates and practical assistance help households reduce their regular bills.</p>
          <a href="/household-support">Read more</a>
        </section>
        <section>#{stories}</section>
      </article><a href="#top">Top of page</a></main>
    HTML
    expect(result.fetch("records").map { |record| record.fetch("url") }).to eq(
      ["https://publisher.example/household-support"] +
        Array.new(125) { |index| "https://publisher.example/story/#{index}" }
    )
    support = result.fetch("records").first
    expect(support.fetch("owner")).to eq("support-section")
    expect(support.fetch("markdown")).to include("Available rebates and practical assistance")
    expect(support.fetch("markdown")).not_to include("Local story information")
  end

  it "retains individual article ownership when other main material or an article route exists" do
    article = "<article class='feature-card'><h2><a href='/feature'>Distinct feature destination</a></h2>" \
              "<p>Local feature description remains associated with this destination.</p></article>"
    ["<p>Independent main introduction.</p>", "<img src='/outside.jpg' alt='Independent visual'>",
     "<a href='/outside'>Independent destination</a>"].each do |outside|
      record = shared_context_records("<main>#{article}#{outside}</main>").fetch("records").first
      expect(record.fetch("owner")).to eq("feature-card")
      expect(record.fetch("markdown")).to include("Local feature description")
    end
    record = shared_context_records("<main>#{article}</main>", url: "https://publisher.example/features/current")
             .fetch("records").first
    expect(record.fetch("owner")).to eq("feature-card")
  end

  it "does not attribute a neighboring article's author to a collection link" do
    stories = Array.new(3) do |index|
      <<~HTML
        <article><h3><a href="/story/#{index}">Independent premium report #{index}</a></h3>
          <p>Local reporting and analysis for this individual story #{index}.</p>
          <span class="author">Independent reporter #{index}</span>
        </article>
      HTML
    end.join
    result = shared_context_records(<<~HTML, root_selector: ".left-column")
      <main><h1>Material collection</h1><div class="left-column">
        <h2>Premium reports</h2>#{stories}
        <h2><a href="/games">Mind training collection</a></h2>
        <article><h3><a href="/game/words">Daily independent word puzzle</a></h3></article>
        <article><h3><a href="/game/numbers">Daily independent number puzzle</a></h3></article>
      </div></main>
    HTML
    records = result.fetch("records")
    expect(result.fetch("containerAuthor")).to eq("")
    games = result.fetch("markdown").lines.find { |line| line.include?("https://publisher.example/games") }
    expect(games).not_to be_nil
    expect(games).not_to include("Independent reporter")
    3.times do |index|
      story = records.find { |record| record.fetch("url") == "https://publisher.example/story/#{index}" }
      expect(story.fetch("markdown")).to include("Independent reporter #{index}")
    end
  end
end
