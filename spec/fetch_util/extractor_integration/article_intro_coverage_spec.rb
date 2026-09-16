# frozen_string_literal: true

RSpec.describe "generic article intro recovery" do
  include_context "extractor integration helpers"

  def selected_article_body
    Array.new(4) do |index|
      "<p>Primary paragraph #{index} preserves independently verified reporting facts, detailed context, and source-owned article prose.</p>"
    end.join
  end

  it "recovers a directly adjacent image without requiring a presentation wrapper" do
    lead = "A directly attached image remains material when the same focal article owns it immediately before one proved visible standfirst."
    page_html = "<article><img src='/direct.jpg' alt='Direct evidence'><strong class='article-lead'>#{lead}</strong>" \
                "<div class='article-body'>#{selected_article_body}</div></article>"
    result = intro_selection(page_html)

    expect(result.fetch("html")).to match(/direct\.jpg.*#{Regexp.escape(lead)}.*Primary paragraph 0/m)
    expect(result.fetch("html").scan("direct.jpg").length).to eq(1)
    expect(result.fetch("sourceUnchanged")).to be(true)
  end

  def intro_selection(page_html, metadata: nil, selected_html: selected_article_body)
    root = File.expand_path("../../..", __dir__)
    source = File.readlines(File.join(root, "websieve/manifest.txt"), chomp: true)
                 .reject { |line| line.empty? || line.start_with?("#") }
                 .map { |path| File.read(File.join(root, "websieve", path)) }.join("\n")
    outro = File.read(File.join(root, "websieve/99_outro.js"))
    source = source.delete_suffix(outro) + <<~JS + outro
      window.__articleIntroSelection = function(input) {
        var sourceBefore = document.documentElement.outerHTML;
        var selectedRoot = document.createElement("div");
        selectedRoot.innerHTML = input.selectedHtml;
        var selected = {html: input.selectedHtml, textContent: normalizeText(selectedRoot.textContent),
          readerMode: true, contentType: "article", title: "Selected article"};
        var result = enrichMainArticleContent(selected, input.metadata);
        return JSON.stringify({html: result.html, textContent: result.textContent, readerMode: result.readerMode,
          sourceUnchanged: document.documentElement.outerHTML === sourceBefore});
      };
    JS
    with_url_page("https://news.example/articles/investigation", page_html) do |page|
      page.add_script_tag(content: source)
      JSON.parse(page.evaluate("window.__articleIntroSelection(#{JSON.generate(selectedHtml: selected_html, metadata: metadata)})"))
    end
  end

  it "recovers one named same-article lead and its one attached image in source order" do
    lead = "A long visible standfirst gives essential context that Readability omitted before selecting the article's first body paragraph."
    page_html = <<~HTML
      <article>
        <header><h1>Independent investigation</h1></header>
        <div class="article-big-image"><img src="/lead.jpg" srcset="/lead-large.jpg 2x" alt="Investigators reviewing evidence"></div>
        <strong class="article-lead">#{lead}</strong>
        <div class="article-body">#{selected_article_body}</div>
      </article>
    HTML
    result = intro_selection(page_html)

    expect(result.values_at("readerMode", "sourceUnchanged")).to eq([true, true])
    expect(result.fetch("html")).to match(/lead\.jpg.*#{Regexp.escape(lead)}.*Primary paragraph 0/m)
    expect(result.fetch("html").scan("lead.jpg").length).to eq(1)
    expect(result.fetch("html")).to include("/lead-large.jpg 2x", 'alt="Investigators reviewing evidence"')
  end

  it "rejects ambiguous, nested, hidden, unmarked, late, promotional, gallery and duplicate-owner intros" do
    lead = "A long visible standfirst is material only when one unambiguous focal article proves ownership and order before the selected body."
    body = "<div class='article-body'>#{selected_article_body}</div>"
    alternatives = [
      "<article><article><strong class='article-lead'>#{lead}</strong></article>#{body}</article>",
      "<article><article><strong class='article-lead'>#{lead}</strong>#{body}</article></article>",
      "<article><strong>#{lead}</strong>#{body}</article>",
      "<article><strong class='not-lead'>#{lead}</strong>#{body}</article>",
      "<article><strong class='summary-teaser'>#{lead}</strong>#{body}</article>",
      "<article><div class='article-lead'><strong>#{lead}</strong><b>Additional warning text.</b></div>#{body}</article>",
      "<article><strong class='article-lead' aria-hidden='true'>#{lead}</strong>#{body}</article>",
      "<article aria-hidden='true'><strong class='article-lead'>#{lead}</strong>#{body}</article>",
      "<article><aside><strong class='article-lead'>#{lead}</strong></aside>#{body}</article>",
      "<article><blockquote><strong class='article-lead'>#{lead}</strong></blockquote>#{body}</article>",
      "<article><q><strong class='article-lead'>#{lead}</strong></q>#{body}</article>",
      "<article><cite><strong class='article-lead'>#{lead}</strong></cite>#{body}</article>",
      "<article><div role='blockquote'><strong class='article-lead'>#{lead}</strong></div>#{body}</article>",
      "<article><div class='comments'><strong class='article-lead'>#{lead}</strong></div>#{body}</article>",
      "<article><div class='recommendations'><strong class='article-lead'>#{lead}</strong></div>#{body}</article>",
      "<article><div class='sponsors'><strong class='article-lead'>#{lead}</strong></div>#{body}</article>",
      "<article><div class='promotion'><strong class='article-lead'>#{lead}</strong></div>#{body}</article>",
      "<article><div class='advertorial'><strong class='article-lead'>#{lead}</strong></div>#{body}</article>",
      "<article><div class='partner-content'><strong class='article-lead'>#{lead}</strong></div>#{body}</article>",
      "<article><div class='pullquote'><strong class='article-lead'>#{lead}</strong></div>#{body}</article>",
      "<article><div class='quoted-text'><strong class='article-lead'>#{lead}</strong></div>#{body}</article>",
      "<article><figure class='gallery'><img src='/gallery.jpg'></figure><strong class='article-lead'>#{lead}</strong>#{body}</article>",
      "<article><div class='carousel'><figure><img src='/carousel.jpg'></figure></div><strong class='article-lead'>#{lead}</strong>#{body}</article>",
      "<article><figure class='lightbox'><img src='/lightbox.jpg'></figure><strong class='article-lead'>#{lead}</strong>#{body}</article>",
      "<article><div class='slideshow'><img src='/slideshow.jpg'></div><strong class='article-lead'>#{lead}</strong>#{body}</article>",
      "<article><video src='/clip.mp4'></video><strong class='article-lead'>#{lead}</strong>#{body}</article>",
      "<article><div class='article-media'><audio src='/clip.mp3'></audio></div><strong class='article-lead'>#{lead}</strong>#{body}</article>",
      "<article><iframe src='/embed'></iframe><strong class='article-lead'>#{lead}</strong>#{body}</article>",
      "<article><div class='article-media'><img src='/still.jpg'><video src='/clip.mp4'></video></div><strong class='article-lead'>#{lead}</strong>#{body}</article>",
      "<article><div class='article-media'><div class='story-image'><img src='/nested.jpg'></div></div>" \
        "<strong class='article-lead'>#{lead}</strong>#{body}</article>",
      "<article><div class='article-big-image'><img src='/one.jpg'><img src='/two.jpg'></div><strong class='article-lead'>#{lead}</strong>#{body}</article>",
      "<article><div class='article-big-image sponsor-creative'><img src='/sponsor.jpg'></div><strong class='article-lead'>#{lead}</strong>#{body}</article>",
      "<article class='promotional'><strong class='article-lead'>#{lead}</strong>#{body}</article>",
      "<article><a href='/gallery'><figure><img src='/linked.jpg'></figure></a><strong class='article-lead'>#{lead}</strong>#{body}</article>",
      "<article><div><img src='/unproved.jpg'></div><strong class='article-lead'>#{lead}</strong>#{body}</article>",
      "<article>#{body}<strong class='article-lead'>#{lead}</strong></article>",
      "<article><strong class='article-lead'>#{lead}</strong>#{body}</article><article>#{selected_article_body}</article>",
      "<main><strong class='article-lead'>#{lead}</strong>#{body}</main>",
      "<article itemscope itemtype='https://schema.org/Product'><p itemprop='description'>#{lead}</p>#{body}</article>",
      "<section class='story-grid'><article class='story-card'><strong class='article-lead'>#{lead}</strong>#{body}</article>" \
        "<article class='story-card'><h2>Another story</h2><p>Independent card prose.</p></article></section>",
      "<section class='story-feed'><div class='story-wrap'><article class='story'><strong class='article-lead'>#{lead}</strong>" \
        "#{body}</article></div><div class='story-wrap'><article class='story'><h2>Another story</h2></article></div></section>",
      "<section class='story-feed'><div class='story-wrap'><article class='story'><strong class='article-lead'>#{lead}</strong>" \
        "#{body}</article></div></section>",
      "<section role='feed'><article class='story'><strong class='article-lead'>#{lead}</strong>#{body}</article></section>",
      "<div data-component='collection'><article class='story'><strong class='article-lead'>#{lead}</strong>#{body}</article></div>",
      "<article><strong class='article-lead'>#{lead}</strong><div class='story-grid'>#{body}</div></article>",
      "<article><div>Unmapped source preface</div><strong class='article-lead'>#{lead}</strong>#{body}</article>",
      "<article><img src='/earlier.jpg'><div class='article-big-image'><img src='/primary.jpg'></div>" \
        "<strong class='article-lead'>#{lead}</strong>#{body}</article>",
      "<article class='story-feed'><strong class='article-lead'>#{lead}</strong>#{body}</article>"
    ]

    alternatives.each_with_index do |page_html, index|
      result = intro_selection(page_html)
      expect(result.fetch("html")).not_to include(
        lead, "gallery.jpg", "carousel.jpg", "lightbox.jpg", "slideshow.jpg", "clip.mp4", "clip.mp3", "embed",
        "still.jpg", "nested.jpg", "earlier.jpg", "primary.jpg", "one.jpg", "two.jpg", "sponsor.jpg", "linked.jpg",
        "unproved.jpg"
      ), "alternative #{index}"
      expect(result.fetch("sourceUnchanged")).to be(true)
    end
  end

  it "inserts recovered context after selected article content that precedes it in source order" do
    lead = "A source-owned lead belongs after the selected article label and before the first body paragraph, matching the visible page order."
    selected_html = "<div class='page'><div class='article-label'><p><span>INVESTIGATION</span></p></div>" \
                    "<div class='article-body'>#{selected_article_body}</div></div>"
    page_html = "<article><header><span class='card-label'>INVESTIGATION</span></header><img src='/ordered.jpg'>" \
                "<strong class='article-lead'>#{lead}</strong><div class='article-body'>#{selected_article_body}</div></article>"
    result = intro_selection(page_html, selected_html: selected_html)

    expect(result.fetch("html")).to match(/INVESTIGATION.*ordered\.jpg.*#{Regexp.escape(lead)}.*Primary paragraph 0/m)
    expect(result.fetch("sourceUnchanged")).to be(true)
  end

  it "inserts recovered context before selected article controls that follow it in source order" do
    lead = "A source-owned lead belongs before a selected listen control that follows the standfirst but precedes the first body paragraph."
    selected_html = "<div class='audio-label'>Listen 04:21</div>#{selected_article_body}"
    page_html = "<article><strong class='article-lead'>#{lead}</strong><div class='audio-label'>Listen 04:21</div>" \
                "<div class='article-body'>#{selected_article_body}</div></article>"
    result = intro_selection(page_html, selected_html: selected_html)

    expect(result.fetch("html")).to match(/#{Regexp.escape(lead)}.*Listen 04:21.*Primary paragraph 0/m)
    expect(result.fetch("sourceUnchanged")).to be(true)
  end

  it "does not recover when selected predecessor text is ambiguous or cannot be mapped to the source" do
    lead = "Ambiguous selected metadata cannot safely establish where recovered context belongs in the source-owned article order."
    page_html = "<article><header><span class='card-label'>REPORT</span></header><strong class='article-lead'>#{lead}</strong>" \
                "<div class='article-body'>#{selected_article_body}</div><footer><span class='card-label'>REPORT</span></footer></article>"
    ambiguous = "<div class='article-label'>REPORT</div><div class='article-label'>REPORT</div>#{selected_article_body}"
    unmatched = "<h1>Reader title not present in source</h1>#{selected_article_body}"

    [ambiguous, unmatched].each do |selected_html|
      result = intro_selection(page_html, selected_html: selected_html)
      expect(result.fetch("html")).to eq(selected_html)
      expect(result.fetch("sourceUnchanged")).to be(true)
    end

    reordered_source = "<article><header><span class='card-label'>REPORT</span><span class='article-date'>TODAY</span></header>" \
                       "<strong class='article-lead'>#{lead}</strong><div class='article-body'>#{selected_article_body}</div></article>"
    reordered_selection = "<span class='article-date'>TODAY</span><span class='card-label'>REPORT</span>#{selected_article_body}"
    reordered = intro_selection(reordered_source, selected_html: reordered_selection)
    expect(reordered.fetch("html")).to eq(reordered_selection)
    expect(reordered.fetch("sourceUnchanged")).to be(true)

    unmapped_prefix = "<div>Unmapped editorial preface</div>#{selected_article_body}"
    unmapped = intro_selection(page_html, selected_html: unmapped_prefix)
    expect(unmapped.fetch("html")).to eq(unmapped_prefix)
    expect(unmapped.fetch("sourceUnchanged")).to be(true)
  end

  it "does not duplicate an image when one responsive source URL is already represented" do
    lead = "A visible lead may still be recovered without repeating an image whose primary source already exists in selected article content."
    selected_html = "<img src='/same.jpg' alt='Existing evidence'>#{selected_article_body}"
    page_html = "<article><picture><source srcset='/same-large.jpg 2x'><img src='/same.jpg' alt='Existing evidence'></picture>" \
                "<strong class='article-lead'>#{lead}</strong><div class='article-body'>#{selected_article_body}</div></article>"
    result = intro_selection(page_html, selected_html: selected_html)

    expect(result.fetch("html").scan("same.jpg").length).to eq(1)
    expect(result.fetch("html")).not_to include("same-large.jpg")
    expect(result.fetch("html")).to include(lead)
    expect(result.fetch("html")).to match(/same\.jpg.*#{Regexp.escape(lead)}.*Primary paragraph 0/m)
    expect(result.fetch("sourceUnchanged")).to be(true)
  end

  it "does not reorder a different selected image whose source ownership cannot be mapped" do
    lead = "A different selected image is material context whose order cannot be changed without a matching source resource."
    selected_html = "<img src='/selected.jpg' alt='Selected evidence'>#{selected_article_body}"
    page_html = "<article><img src='/source.jpg' alt='Source evidence'><strong class='article-lead'>#{lead}</strong>" \
                "<div class='article-body'>#{selected_article_body}</div></article>"
    result = intro_selection(page_html, selected_html: selected_html)

    expect(result.fetch("html")).to eq(selected_html)
    expect(result.fetch("sourceUnchanged")).to be(true)

    mapped_page = "<article><header><span class='card-label'>REPORT</span></header><img src='/source.jpg'>" \
                  "<strong class='article-lead'>#{lead}</strong><div class='article-body'>#{selected_article_body}</div></article>"
    mapped_selected = "<div class='article-label'>REPORT</div><img src='/selected.jpg'>#{selected_article_body}"
    mapped = intro_selection(mapped_page, selected_html: mapped_selected)
    expect(mapped.fetch("html")).to eq(mapped_selected)
    expect(mapped.fetch("sourceUnchanged")).to be(true)
  end

  it "does not use matching media that appears after the selected body" do
    lead = "A matching image after the selected body cannot stand in for source media that visibly precedes the article standfirst."
    selected_html = "#{selected_article_body}<img src='/same.jpg' alt='Late evidence'>"
    page_html = "<article><img src='/same.jpg' alt='Early evidence'><strong class='article-lead'>#{lead}</strong>" \
                "<div class='article-body'>#{selected_article_body}</div></article>"
    result = intro_selection(page_html, selected_html: selected_html)

    expect(result.fetch("html")).to eq(selected_html)
    expect(result.fetch("sourceUnchanged")).to be(true)
  end

  it "preserves different body media that follows the recovered context in both source and selection" do
    lead = "A later body image remains material after one proved primary image and standfirst are restored ahead of the article body."
    selected_html = "#{selected_article_body}<img src='/later.jpg' alt='Later evidence'>"
    page_html = "<article><img src='/primary.jpg' alt='Primary evidence'><strong class='article-lead'>#{lead}</strong>" \
                "<div class='article-body'>#{selected_html}</div></article>"
    result = intro_selection(page_html, selected_html: selected_html)

    expect(result.fetch("html")).to match(/primary\.jpg.*#{Regexp.escape(lead)}.*Primary paragraph 0.*later\.jpg/m)
    expect(result.fetch("html").scan(/(?:primary|later)\.jpg/).length).to eq(2)
    expect(result.fetch("sourceUnchanged")).to be(true)
  end

  it "does not mistake a longer body quotation for an already-rendered lead" do
    lead = "The verified standfirst remains a distinct visible article part even when the later report quotes every word inside a longer paragraph."
    first_paragraph = "<p>Reporters later quoted this earlier context: #{lead} The body then adds separate analysis and evidence.</p>"
    selected_html = first_paragraph + selected_article_body
    page_html = "<article><strong class='article-lead'>#{lead}</strong><div class='article-body'>#{selected_html}</div></article>"
    result = intro_selection(page_html, selected_html: selected_html)

    expect(result.fetch("html").scan(lead).length).to eq(2)
    expect(result.fetch("html")).to match(/<strong class="article-lead">.*#{Regexp.escape(lead)}.*<p>Reporters later/m)
    expect(result.fetch("sourceUnchanged")).to be(true)
  end

  it "does not mistake an exact body repetition for a rendered semantic lead" do
    lead = "The exact standfirst can be repeated in body prose while remaining a distinct visible article part that should still be recovered."
    repeated_body = "<p>#{lead}</p>" + selected_article_body
    page_html = "<article><strong class='article-lead'>#{lead}</strong><div class='article-body'>#{repeated_body}</div></article>"
    result = intro_selection(page_html, selected_html: repeated_body)

    expect(result.fetch("html").scan(lead).length).to eq(2)
    expect(result.fetch("html")).to match(/<strong class="article-lead">.*#{Regexp.escape(lead)}.*<p>#{Regexp.escape(lead)}/m)
    expect(result.fetch("sourceUnchanged")).to be(true)
  end

  it "accepts schema description intros only for an article-owned item scope" do
    lead = "A schema article description is a visible standfirst only when the focal article itself owns the structured-data scope."
    page_html = "<article itemscope itemtype='https://schema.org/NewsArticle'><p itemprop='description'>#{lead}</p>" \
                "<div class='article-body'>#{selected_article_body}</div></article>"
    result = intro_selection(page_html)

    expect(result.fetch("html")).to match(/itemprop="description".*#{Regexp.escape(lead)}.*Primary paragraph 0/m)
    expect(result.fetch("sourceUnchanged")).to be(true)
  end

  it "accepts one semantic figure but does not duplicate a metadata-supplied lead or image" do
    lead = "A verified metadata summary is also the visible article standfirst and must remain exactly once with its attached evidence image."
    page_html = <<~HTML
      <article>
        <header class="article-header">
          <figure><img src="/evidence.jpg" alt="Evidence"><figcaption>Evidence caption. Photo credit.</figcaption></figure>
          <p class="article-header__lead">#{lead}</p>
        </header>
        <div class="article-body">#{selected_article_body}</div>
      </article>
    HTML
    result = intro_selection(page_html, metadata: { excerpt: lead })

    expect(result.fetch("html").scan(lead).length).to eq(1)
    expect(result.fetch("html").scan("evidence.jpg").length).to eq(1)
    expect(result.fetch("html")).to match(/evidence\.jpg.*#{Regexp.escape(lead)}.*Primary paragraph 0/m)
    expect(result.fetch("sourceUnchanged")).to be(true)
  end
end
