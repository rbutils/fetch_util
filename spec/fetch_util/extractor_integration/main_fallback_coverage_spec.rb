require "spec_helper"
require "support/extractor_integration_helpers"

RSpec.describe FetchUtil::Extractor do
  include_context "extractor integration helpers"

  def main_fallback_primary
    paragraphs = Array.new(4) do |index|
      "<p>Primary paragraph #{index} explains independently retained scheduling and patient communication facts. " \
        "A practice keeps its own records, appointment details and carefully described service conditions.</p>"
    end.join
    "<h1>Practice services</h1>#{paragraphs}<p><a href='/existing'>Existing service details</a></p>" \
      "<img src='/existing.jpg' srcset='/existing-large.jpg 2x' alt='Existing visual context'>"
  end

  def main_fallback_additions
    "<p><a href='/appointments'>Explore appointment services</a></p>" \
      "<p><a href='/communications'>Explore communication services</a></p>"
  end

  def main_fallback_selection(primary, fallback, main_root: true, url: "https://practice.example/", page_html: nil, primary_flags: {})
    root = File.expand_path("../../..", __dir__)
    source = File.readlines(File.join(root, "websieve/manifest.txt"), chomp: true)
                 .reject { |line| line.empty? || line.start_with?("#") }
                 .map { |path| File.read(File.join(root, "websieve", path)) }.join("\n")
    outro = File.read(File.join(root, "websieve/99_outro.js"))
    source = source.delete_suffix(outro) + <<~JS + outro
      window.__mainFallbackSelection = function(input) {
        var primaryRoot = document.createElement("div");
        var fallbackRoot = document.createElement("div");
        primaryRoot.innerHTML = input.primary;
        fallbackRoot.innerHTML = input.fallback;
        var primary = {html: input.primary, textContent: normalizeText(primaryRoot.textContent), readerMode: true, contentType: "article",
          title: "Readability title", byline: "Primary author", excerpt: "Original summary", publishedTime: "2026-09-01"};
        Object.assign(primary, input.primaryFlags);
        var fallback = {html: input.fallback, textContent: normalizeText(fallbackRoot.textContent), readerMode: false, contentType: "article", mainContentRoot: input.mainRoot};
        var primaryBefore = JSON.stringify(primary), fallbackBefore = JSON.stringify(fallback);
        var chosen = preferFallbackContent(primary, fallback);
        var dominantBefore = dominantIndexListPage(chosen);
        var producerMain = !!fallbackContent().mainContentRoot;
        var originalFallback = fallbackContent;
        fallbackContent = function() { return fallback; };
        var selected;
        try { selected = enrichMainArticleContent(chosen); }
        finally { fallbackContent = originalFallback; }
        var selectedRoot = document.createElement("div");
        selectedRoot.innerHTML = selected.html;
        return JSON.stringify({expanded: selected.html === input.fallback, html: selected.html, readerMode: selected.readerMode,
          dominantBefore: dominantBefore, dominantAfter: dominantIndexListPage(selected),
          metadata: [selected.title, selected.byline, selected.excerpt, selected.publishedTime],
          inputsUnchanged: JSON.stringify(primary) === primaryBefore && JSON.stringify(fallback) === fallbackBefore,
          urls: Array.prototype.map.call(selectedRoot.querySelectorAll("a[href]"), function(link) { return link.getAttribute("href"); }),
          coverage: mainFallbackPreservesArticle(primaryRoot, fallbackRoot), producerMain: producerMain});
      };
    JS
    with_url_page(url, page_html || "<main>#{primary}</main>") do |page|
      page.add_script_tag(content: source)
      input = { primary: primary, fallback: fallback, mainRoot: main_root, primaryFlags: primary_flags }
      JSON.parse(page.evaluate("window.__mainFallbackSelection(#{JSON.generate(input)})"))
    end
  end

  it "enriches a proved Readability article without losing its material, metadata or provenance" do
    primary = main_fallback_primary
    fallback = primary + main_fallback_additions
    result = main_fallback_selection(primary, fallback)
    expect(result.values_at("expanded", "coverage", "producerMain", "readerMode", "inputsUnchanged")).to eq([true, true, true, true, true])
    expect(result.fetch("html")).to eq(fallback)
    expect(result.fetch("metadata")).to eq(["Readability title", "Primary author", "Original summary", "2026-09-01"])
  end

  it "retains all 125 additional destinations in their original order" do
    additions = Array.new(125) { |index| "<p><a href='/service/#{index}'>Independently named service #{index}</a></p>" }.join
    result = main_fallback_selection(main_fallback_primary, main_fallback_primary + additions)
    expect(result.values_at("expanded", "coverage")).to eq([true, true])
    expect(result.fetch("urls")).to eq(
      ["/existing"] + Array.new(125) { |index| "/service/#{index}" }
    )
  end

  it "does not let additional main-body cards alter the input to list arbitration" do
    cards = Array.new(8) { |index| "<section class='card'><h3><a href='/service/#{index}'>Independent service #{index}</a></h3></section>" }.join
    result = main_fallback_selection(main_fallback_primary, main_fallback_primary + cards)
    expect(result.values_at("expanded", "dominantBefore", "dominantAfter")).to eq([true, false, true])
  end

  it "rejects missing or reordered primary text even when additional links remain" do
    primary = main_fallback_primary
    [primary.sub(%r{<p>Primary paragraph 2.*?</p>}, ""),
     primary.sub("Primary paragraph 0", "Primary paragraph temporary")
            .sub("Primary paragraph 1", "Primary paragraph 0").sub("Primary paragraph temporary", "Primary paragraph 1")].each do |changed|
      result = main_fallback_selection(primary, changed + main_fallback_additions)
      expect(result.values_at("expanded", "coverage")).to eq([false, false])
    end
  end

  it "does not substitute changed numbers or mathematical operators" do
    [["<strong>1</strong>", "<strong>10</strong>"], ["<strong>n&lt;2</strong>", "<strong>n&gt;2</strong>"]].each do |before, after|
      primary = main_fallback_primary + before
      result = main_fallback_selection(primary, main_fallback_primary + after + main_fallback_additions)
      expect(result.values_at("expanded", "coverage")).to eq([false, false])
    end
  end

  it "preserves primary resource identity, labels, responsive sources and order" do
    primary = main_fallback_primary
    image = primary[/<img[^>]+>/]
    [primary.sub("href='/existing'", "href='/replacement'"), primary.sub("Existing visual context", "Different visual"),
     primary.sub("/existing-large.jpg 2x", "/different-large.jpg 2x"), primary.sub(image, ""),
     image + primary.sub(image, "")].each do |changed|
      result = main_fallback_selection(primary, changed + main_fallback_additions)
      expect(result.values_at("expanded", "coverage")).to eq([false, false])
    end
  end

  it "does not count navigation, hidden entries, controls or unsafe URLs as material gains" do
    additions = main_fallback_additions
    ["<nav>#{additions}</nav>", "<div hidden>#{additions}</div>",
     additions.gsub("Explore appointment services", "Login").gsub("Explore communication services", "Share"),
     additions.gsub("href='/", "href='javascript:"),
     additions.gsub("href='/", "href='https://user:secret@practice.example/")].each do |links|
      result = main_fallback_selection(main_fallback_primary, main_fallback_primary + links)
      expect(result.values_at("expanded", "coverage")).to eq([false, false])
    end
  end

  it "requires a homepage main-root proof and preserves MediaWiki precedence" do
    primary = main_fallback_primary
    fallback = primary + main_fallback_additions
    expect(main_fallback_selection(primary, fallback, main_root: false).fetch("expanded")).to be(false)
    result = main_fallback_selection(primary, fallback, url: "https://practice.example/article/current")
    expect(result.values_at("expanded", "producerMain")).to eq([false, false])
    wiki = "<main><div id='mw-content-text'><div class='mw-parser-output'>#{primary}</div></div></main>"
    expect(main_fallback_selection(primary, fallback, page_html: wiki).fetch("expanded")).to be(false)
  end

  it "does not enrich a different selected content contract" do
    flags = [{ readerMode: false }, { contentType: "list" }, { hostAware: true }, { docsLike: true },
             { legalProvision: true }, { markdown: "Already rendered specialized content" }]
    flags.each do |primary_flags|
      result = main_fallback_selection(main_fallback_primary, main_fallback_primary + main_fallback_additions, primary_flags: primary_flags)
      expect(result.fetch("expanded")).to be(false)
    end
  end
end
