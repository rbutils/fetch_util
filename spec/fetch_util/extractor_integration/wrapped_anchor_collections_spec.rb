# frozen_string_literal: true

require "support/extractor_integration_helpers"

RSpec.describe "Wrapped anchor collections" do
  include_context "extractor integration helpers"

  def wrapped_collection(html)
    root = File.expand_path("../../..", __dir__)
    source = File.readlines(File.join(root, "websieve/manifest.txt"), chomp: true)
                 .reject { |line| line.empty? || line.start_with?("#") }
                 .map { |path| File.read(File.join(root, "websieve", path)) }.join("\n")
    outro = File.read(File.join(root, "websieve/99_outro.js"))
    source = source.delete_suffix(outro) + <<~JS + outro
      global.__wrappedCollection = function() {
        var root = visibleListClone(document.querySelector('main'));
        cleanupListRoot(root);
        var items = extractListItems(root);
        return JSON.stringify({
          qualified: Array.from(root.querySelectorAll('a[href]')).map(genericListWrappedAnchorCard),
          figureOwners: Array.from(root.querySelectorAll('figure')).map(function(figure) {
            var link = genericListFigureRecordLink(figure);
            return link && link.href;
          }),
          items: items.map(function(item) { return {text: item.text, url: item.url, detail: item.detail}; }),
          markdown: listMarkdownWithInlineDescriptions({root: root, items: items}) || listMarkdown(items)
        });
      };
    JS
    with_url_page("https://publisher.example/", html) do |page|
      page.add_script_tag(content: source)
      JSON.parse(page.evaluate("window.__wrappedCollection()"))
    end
  end

  def wrapped_record(index)
    "<div class=\"layout-cell\"><a href=\"/collection/#{index}\"><figure><figcaption>" \
      "<h2>Collection number #{index}</h2><p>Independent material description for collection #{index}.</p>" \
      "</figcaption></figure></a></div>"
  end

  it "keeps every wrapped heading and paragraph with its own destination" do
    result = wrapped_collection("<main><div>#{4.times.map { |i| wrapped_record(i) }.join}</div></main>")
    expect(result.fetch("items").map { |item| item.fetch("url") }).to eq(4.times.map { |i| "https://publisher.example/collection/#{i}" })
    expect(result.fetch("figureOwners")).to eq([nil, nil, nil, nil])
    4.times do |i|
      expect(result.fetch("markdown")).to include(
        "[Collection number #{i}](https://publisher.example/collection/#{i}) - Independent material description for collection #{i}."
      )
    end
  end

  it "retains short event names and their own dates, locations and footer counts" do
    events = %w[NeoCon Cersaie].map do |name|
      "<div class=\"layout-cell\"><a href=\"/events/#{name}\"><figure><figcaption>" \
        "<div class=\"event-name\">#{name}</div><div>Chicago</div><div class=\"date\">June 8, 2026</div>" \
        "<footer>Discover 6,534 products</footer></figcaption></figure></a></div>"
    end.join
    result = wrapped_collection("<main><div>#{events}</div></main>")
    expect(result.fetch("items").map { |item| item.fetch("text") }).to eq(%w[NeoCon Cersaie])
    result.fetch("items").each do |item|
      expect(item.fetch("detail")).to include("Chicago", "June 8, 2026", "Discover 6,534 products")
    end
  end

  it "does not borrow navigation, hidden or unsafe peers to establish a collection" do
    hidden = wrapped_record(1).sub("layout-cell", 'layout-cell" hidden="hidden')
    unsafe = wrapped_record(1).sub("/collection/1", "https://user:secret@publisher.example/private")
    [hidden, unsafe, "<nav>#{wrapped_record(1)}</nav>", ""].each do |peer|
      result = wrapped_collection("<main><div>#{wrapped_record(0)}#{peer}</div></main>")
      expect(result.fetch("qualified")).not_to include(true)
    end
    result = wrapped_collection("<main><nav>#{4.times.map { |i| wrapped_record(i) }.join}</nav></main>")
    expect(result.fetch("items")).to be_empty
  end

  it "preserves all 125 material records in DOM order" do
    result = wrapped_collection("<main><div>#{125.times.map { |i| wrapped_record(i) }.join}</div></main>")
    expect(result.fetch("items").map { |item| item.fetch("url") }).to eq(125.times.map { |i| "https://publisher.example/collection/#{i}" })
  end

  it "still recognizes a figure that actually contains its linked heading" do
    figures = 2.times.map do |i|
      %(<figure><a href="/figure/#{i}"><h2>Independently linked figure #{i}</h2></a><figcaption>Complete figure description #{i}.</figcaption></figure>)
    end.join
    result = wrapped_collection("<main><div>#{figures}</div></main>")
    expect(result.fetch("figureOwners")).to eq(2.times.map { |i| "https://publisher.example/figure/#{i}" })
  end

  it "keeps independent layout rows and surrounding paragraphs in DOM order" do
    html = "<main><p>Opening explanation for all the independent collections.</p>" \
      "<div>#{wrapped_record(0)}<a href='/other'>Other</a></div>#{wrapped_record(1)}" \
      "<p>Final material terms must remain after the collection records.</p></main>"
    result = wrapped_collection(html)
    expect(result.fetch("items").map { |item| item.fetch("url") }).to eq(2.times.map { |i| "https://publisher.example/collection/#{i}" })
    markdown = result.fetch("markdown")
    expect(markdown.index("Opening explanation")).to be < markdown.index("[Collection number 0]")
    expect(markdown.index("Final material terms")).to be > markdown.index("[Collection number 1]")
  end

  it "keeps all 125 query-distinct offers behind presentation spans independently owned" do
    offers = 125.times.map do |i|
      "<span><a href='/buy?plan=plan#{i}'><div class='product-card'>" \
        "<div class='product-title'>Independent offer #{i}</div>" \
        "<div class='product-description'>Material terms specific to offer #{i}.</div></div></a></span>"
    end.join
    result = wrapped_collection("<main><div class='product-card-bg'>#{offers}</div></main>")
    expect(result.fetch("items").map { |item| item.fetch("url") }).to eq(125.times.map { |i| "https://publisher.example/buy?plan=plan#{i}" })
    result.fetch("items").each_with_index do |item, i|
      expect(item.fetch("text")).to eq("Independent offer #{i}")
      expect(item.fetch("detail")).to include("Material terms specific to offer #{i}.")
      expect(item.fetch("detail")).not_to include("Material terms specific to offer #{(i + 1) % 125}.")
    end
  end

  it "does not let a presentation wrapper raise the normal four-character CJK minimum" do
    names = %W[\u8bfe\u7a0b\u5b66\u4e60 \u79d1\u5b66\u7814\u7a76]
    offers = names.each_with_index.map do |name, i|
      "<span><a href='/program/#{i}'><div class='product-title'>#{name}</div>" \
        "<div class='product-description'>Independent material description #{i}.</div></a></span>"
    end.join
    result = wrapped_collection("<main><div class='product-card-bg'>#{offers}</div></main>")
    expect(result.fetch("items").map { |item| item.fetch("text") }).to eq(names)
  end

  it "keeps visible image-backed headlines local even when their image alt is empty" do
    anchors = 3.times.map do |i|
      "<a href='/featured/#{i}'><img src='/image-#{i}.jpg' alt=''>" \
        "<span>Featured independent headline number #{i}</span></a>"
    end.join
    result = wrapped_collection("<main><div>#{anchors}</div></main>")
    expect(result.fetch("items").map { |item| item.fetch("url") }).to eq(3.times.map { |i| "https://publisher.example/featured/#{i}" })
    result.fetch("items").each_with_index do |item, i|
      expect(item.fetch("detail")).not_to include("Featured independent headline number #{(i + 1) % 3}")
    end
  end
end
