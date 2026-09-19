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

  def main_fallback_selection(primary, fallback, main_root: true, url: "https://practice.example/", page_html: nil,
                              primary_flags: {}, metadata: nil, code_root: false)
    root = File.expand_path("../../..", __dir__)
    source = File.readlines(File.join(root, "websieve/manifest.txt"), chomp: true)
                 .reject { |line| line.empty? || line.start_with?("#") }
                 .map { |path| File.read(File.join(root, "websieve", path)) }.join("\n")
    outro = File.read(File.join(root, "websieve/99_outro.js"))
    source = source.delete_suffix(outro) + <<~JS + outro
      window.__mainFallbackSelection = function(input) {
        var documentBefore = document.documentElement.outerHTML;
        var primaryRoot = document.createElement("div");
        var fallbackRoot = document.createElement("div");
        primaryRoot.innerHTML = input.primary;
        fallbackRoot.innerHTML = input.fallback;
        var primary = {html: input.primary, textContent: normalizeText(primaryRoot.textContent), readerMode: true, contentType: "article",
          title: "Readability title", byline: "Primary author", excerpt: "Original summary", publishedTime: "2026-09-01"};
        Object.assign(primary, input.primaryFlags);
        var fallback = {html: input.fallback, textContent: normalizeText(fallbackRoot.textContent), readerMode: false,
          contentType: "article", mainContentRoot: input.mainRoot, instructionalContentRoot: input.codeRoot};
        var primaryBefore = JSON.stringify(primary), fallbackBefore = JSON.stringify(fallback);
        var chosen = preferFallbackContent(primary, fallback);
        var dominantBefore = dominantIndexListPage(chosen);
        var producerMain = !!fallbackContent().mainContentRoot;
        var originalFallback = fallbackContent;
        fallbackContent = function() { return fallback; };
        var selected;
        try { selected = enrichMainArticleContent(chosen, input.metadata); }
        finally { fallbackContent = originalFallback; }
        var selectedRoot = document.createElement("div");
        selectedRoot.innerHTML = selected.html;
        var resources = [];
        selectedRoot.querySelectorAll("a, img, source, video").forEach(function(node) {
          ["href", "src", "poster"].forEach(function(attribute) {
            var value = node.getAttribute(attribute);
            if (value) resources.push(value);
          });
        });
        return JSON.stringify({expanded: selected.html === input.fallback, html: selected.html, readerMode: selected.readerMode,
          dominantBefore: dominantBefore, dominantAfter: dominantIndexListPage(selected),
          metadata: [selected.title, selected.byline, selected.excerpt, selected.publishedTime],
          inputsUnchanged: JSON.stringify(primary) === primaryBefore && JSON.stringify(fallback) === fallbackBefore,
          documentUnchanged: document.documentElement.outerHTML === documentBefore,
          urls: Array.prototype.map.call(selectedRoot.querySelectorAll("a[href]"), function(link) { return link.getAttribute("href"); }),
          resources: resources,
          coverage: mainFallbackPreservesArticle(primaryRoot, fallbackRoot), producerMain: producerMain});
      };
    JS
    with_url_page(url, page_html || "<main>#{primary}</main>") do |page|
      page.add_script_tag(content: source)
      input = { primary: primary, fallback: fallback, mainRoot: main_root, primaryFlags: primary_flags, metadata: metadata, codeRoot: code_root }
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

  it "supplements an exact visible article lead and its attached figure without header controls" do
    lead = "A verified local summary introduces the report with material context that the selected article body does not repeat."
    page_html = <<~HTML
      <main>
        <header class="article-header">
          <button>Share article</button>
          <p class="article-header__lead">#{lead}</p>
          <figure><img src="/lead.jpg" alt="Evidence at the scene"><figcaption>Local evidence caption.</figcaption></figure>
        </header>
        <section class="article-body">#{main_fallback_primary}</section>
      </main>
    HTML
    result = main_fallback_selection(
      main_fallback_primary,
      main_fallback_primary,
      url: "https://practice.example/articles/report",
      page_html: page_html,
      metadata: { excerpt: lead }
    )

    expect(result.fetch("html")).to include(lead, "Evidence at the scene", "Local evidence caption.", "Primary paragraph 3")
    expect(result.fetch("html")).not_to include("Share article")
  end

  it "does not supplement an unconfirmed or separately owned lead" do
    lead = "A metadata summary must have exact visible ownership before it can supplement a selected article body."
    separate = "<article><header class='article-header'><p>#{lead}</p></header></article>" \
               "<main><section>#{main_fallback_primary}</section></main>"
    unconfirmed = "<main><header class='article-header'><p>Different visible summary.</p></header>" \
                  "<section>#{main_fallback_primary}</section></main>"

    [separate, unconfirmed].each do |page_html|
      result = main_fallback_selection(
        main_fallback_primary,
        main_fallback_primary,
        url: "https://practice.example/articles/report",
        page_html: page_html,
        metadata: { excerpt: lead }
      )
      expect(result.fetch("html")).not_to include(lead)
    end
  end

  it "does not enrich a different selected content contract" do
    flags = [{ readerMode: false }, { contentType: "list" }, { hostAware: true }, { docsLike: true },
             { legalProvision: true }, { markdown: "Already rendered specialized content" }]
    flags.each do |primary_flags|
      result = main_fallback_selection(main_fallback_primary, main_fallback_primary + main_fallback_additions, primary_flags: primary_flags)
      expect(result.fetch("expanded")).to be(false)
    end
  end

  it "recovers omitted instructional examples without new links or semantic main markup" do
    primary = "#{main_fallback_primary}<pre>if ready:\n  run()\nfinish()</pre>"
    fallback = "#{primary}<p>Inspect the available options.</p><pre>tool --help</pre>"
    result = main_fallback_selection(primary, fallback, main_root: false, code_root: true, url: "https://practice.example/tutorial")

    expect(result.values_at("expanded", "readerMode", "inputsUnchanged")).to eq([true, true, true])
    expect(result.fetch("metadata")).to eq(["Readability title", "Primary author", "Original summary", "2026-09-01"])
    expect(main_fallback_selection(primary, fallback, main_root: false).fetch("expanded")).to be(false)
  end

  it "requires exact ordered primary code as well as complete prose and resources before recovery" do
    primary = "#{main_fallback_primary}<pre>if ready:\n  run()\nfinish()</pre><pre>done()</pre>"
    additions = "<pre>tool --help</pre>"
    alternatives = [primary.sub("  run()", "run()"), primary.sub("if ready:", "if not_ready:"),
                    "#{primary.sub("<pre>done()</pre>", "")}<p>done()</p>",
                    primary.sub("href='/existing'", "href='/different'"),
                    primary.sub(%r{<p>Primary paragraph 2.*?</p>}, "")]
    alternatives.each do |alternative|
      result = main_fallback_selection(primary, alternative + additions, code_root: true)
      expect(result.values_at("expanded", "inputsUnchanged")).to eq([false, true])
    end
  end

  it "preserves every additional instructional example in DOM order" do
    primary = "#{main_fallback_primary}<pre>initial_command()</pre>"
    commands = Array.new(125) { |index| "<pre>command_#{index}()</pre>" }.join
    result = main_fallback_selection(primary, primary + commands, main_root: false, code_root: true)

    expect(result.fetch("expanded")).to be(true)
    expect(result.fetch("html").scan(%r{<pre>command_(\d+)\(\)</pre>}).flatten).to eq((0...125).map(&:to_s))
  end

  it "preserves omitted resources from the uniquely owned article in source order" do
    primary = "#{main_fallback_primary}<video poster='/video/poster.jpg'>" \
      "<source src='/video/report.mp4' type='video/mp4'></video>" \
      "<img src='/existing-empty-alt.jpg' alt=''><a href='/existing-empty-anchor'></a>"
    assets = <<~HTML
      <section class="additional-asset">
        <h3>Figure evidence</h3>
        <div class="asset-viewer-inline">
          <a href="/download/figure.jpg">Download asset</a>
          <a href="/iiif/figure.jpg"><img src="/preview/figure.jpg" alt="Figure evidence"></a>
          <a href="/existing">Existing service details</a>
          <a href="/existing-empty-alt.jpg">Existing image download</a>
          <a href="/existing-empty-anchor">Recovered empty anchor resource</a>
        </div>
        <div class="asset-viewer-inline asset-viewer-inline--supplement visuallyhidden" data-variant="supplement">
          <a class="asset-viewer-inline__download_all_link" href="/download/supplement.jpg" download>
            <span class="visuallyhidden">Download asset</span>
          </a>
          <a class="asset-viewer-inline__open_link" href="/iiif/supplement.jpg">
            <span class="visuallyhidden">Open asset</span>
          </a>
        </div>
      </section>
      <section class="additional-asset" style="visibility: hidden">
        <a href="/download/toggleable-data.csv">Download toggleable data</a>
      </section>
      <section>
        <h3>Experiment video</h3>
        <div class="video-container">
          <video poster="/video/poster.jpg">
            <source src="/video/report.mp4" type="video/mp4">
            <source src="/video/report.webm" type="video/webm">
            <source src="/video/report.ogv" type="video/ogg">
          </video>
          <a href="/video/transcript.txt">Download transcript</a>
        </div>
      </section>
    HTML
    page = "<article>#{primary}#{assets}</article>"
    result = main_fallback_selection(
      primary,
      primary,
      url: "https://practice.example/articles/report",
      page_html: page
    )

    expect(result.fetch("html")).to include("Article resources", "Figure evidence", "Experiment video")
    expect(result.fetch("resources")).to include(
      "https://practice.example/download/figure.jpg",
      "https://practice.example/iiif/figure.jpg",
      "https://practice.example/download/supplement.jpg",
      "https://practice.example/iiif/supplement.jpg",
      "https://practice.example/download/toggleable-data.csv",
      "/video/poster.jpg",
      "/video/report.mp4",
      "https://practice.example/video/report.webm",
      "https://practice.example/video/report.ogv",
      "https://practice.example/video/transcript.txt"
    )
    expect(result.fetch("resources").grep(%r{/video/})).to eq(
      ["/video/poster.jpg", "/video/report.mp4"] +
        %w[report.webm report.ogv transcript.txt].map { |name| "https://practice.example/video/#{name}" }
    )
    expect(result.fetch("html").scan("/video/poster.jpg").length).to eq(1)
    expect(result.fetch("html").scan("/video/report.mp4").length).to eq(1)
    expect(result.fetch("html").scan("/existing-empty-alt.jpg").length).to eq(1)
    expect(result.fetch("html").scan("/existing-empty-anchor").length).to eq(2)
    expect(result.fetch("html")).to include("Recovered empty anchor resource")
    expect(result.fetch("urls").grep(/existing/)).to eq(
      ["/existing", "/existing-empty-anchor", "https://practice.example/existing-empty-anchor"]
    )
    expect(result.values_at("inputsUnchanged", "documentUnchanged")).to eq([true, true])

    fallback_result = main_fallback_selection(
      primary,
      primary,
      url: "https://practice.example/articles/report",
      page_html: page,
      primary_flags: { readerMode: false }
    )
    expect(fallback_result.fetch("resources")).to include("https://practice.example/video/report.webm")
  end

  it "preserves every uniquely owned article resource without a presentation cap" do
    assets = Array.new(137) do |index|
      "<section class='additional-asset'><div class='asset-viewer-inline'>" \
        "<a href='/asset/#{index}'>Download asset #{index}</a></div></section>"
    end.join
    page = "<article>#{main_fallback_primary}#{assets}</article>"
    result = main_fallback_selection(
      main_fallback_primary,
      main_fallback_primary,
      url: "https://practice.example/articles/report",
      page_html: page
    )

    expect(result.fetch("urls").grep(%r{/asset/})).to eq(
      Array.new(137) { |index| "https://practice.example/asset/#{index}" }
    )
  end

  it "rejects hidden, unrelated, unsafe and ambiguously owned article resources" do
    rejected = [
      "<section class='additional-asset' hidden><a href='/hidden'>Hidden asset</a></section>",
      "<section class='additional-asset' inert><a href='/inert'>Inert asset</a></section>",
      "<section class='additional-asset' aria-hidden='true'><a href='/aria-hidden'>ARIA hidden asset</a></section>",
      "<section class='additional-asset' style='display: none'><a href='/display-none'>Display hidden asset</a></section>",
      "<details><section class='additional-asset'><a href='/closed-details'>Closed details asset</a></section></details>",
      "<aside><section class='additional-asset'><a href='/related'>Related asset</a></section></aside>",
      "<section class='related additional-asset'><a href='/recommendation'>Recommended asset</a></section>",
      "<section><video poster='/bare-poster.jpg'><source src='/bare-video.mp4' type='video/mp4'></video></section>",
      "<section class='additional-asset'><a href='javascript:alert(1)'>Unsafe asset</a></section>",
      "<section class='additional-asset'><a href='https://user:secret@practice.example/private'>Private asset</a></section>"
    ].join
    competing = "<article>#{main_fallback_primary}<section class='additional-asset'><a href='/other'>Other article asset</a></section></article>"
    page = "<article>#{main_fallback_primary}#{rejected}</article>#{competing}"
    result = main_fallback_selection(
      main_fallback_primary,
      main_fallback_primary,
      url: "https://practice.example/articles/report",
      page_html: page
    )

    expect(result.fetch("html")).not_to include("Article resources", "/hidden", "/inert", "/aria-hidden",
                                                "/display-none", "/closed-details", "/bare-poster", "/bare-video",
                                                "/related", "/recommendation", "/other", "user:secret")
  end

  it "rejects hard-hidden descendants inside a visible article resource container" do
    assets = <<~HTML
      <section class="additional-asset">
        <a href="/resource/visible">Visible asset</a>
        <a href="/resource/display-none" style="display: none">Display hidden asset</a>
        <div hidden><a href="/resource/hidden-owner">Hidden owner asset</a></div>
        <details><a href="/resource/closed-details">Closed details asset</a></details>
        <video class="article-video" style="display: none" poster="/resource/hidden-poster.jpg">
          <source src="/resource/hidden-video.mp4" type="video/mp4">
        </video>
      </section>
    HTML
    page = "<article>#{main_fallback_primary}#{assets}</article>"
    result = main_fallback_selection(
      main_fallback_primary,
      main_fallback_primary,
      url: "https://practice.example/articles/report",
      page_html: page
    )

    expect(result.fetch("resources").grep(%r{/resource/})).to eq(["https://practice.example/resource/visible"])
  end

  it "does not replace specialized or already rendered content with an instructional fallback" do
    primary = "#{main_fallback_primary}<pre>initial_command()</pre>"
    fallback = "#{primary}<pre>tool --help</pre>"
    [{ readerMode: false }, { contentType: "list" }, { hostAware: true }, { docsLike: true },
     { legalProvision: true }, { markdown: "Already rendered content" }].each do |primary_flags|
      result = main_fallback_selection(primary, fallback, main_root: false, code_root: true, primary_flags: primary_flags)
      expect(result.fetch("expanded")).to be(false)
    end
  end
end
