# frozen_string_literal: true

RSpec.describe "Sectioned list descriptions" do
  include_context "extractor integration helpers"

  def section_description_card(number, detail_first: false)
    heading = %(<h3><a href="/articles/#{number}">Guide #{number}</a></h3>)
    detail = %(<p>Focused summary for resource record #{number} with enough local detail to identify this item.</p>)
    content = detail_first ? "#{detail}\n#{heading}" : "#{heading}\n#{detail}"

    <<~HTML
      <article class="resource-card">
        #{content}
      </article>
    HTML
  end

  def compact_consent_card(number)
    <<~HTML
      <article class="resource-card">
        <h3><a href="/policy/#{number}">Consent #{number}</a></h3>
      </article>
    HTML
  end

  def sectioned_directory_html(description: nil, extra: nil, before: nil, between: nil, after: nil)
    <<~HTML
      <!doctype html>
      <html>
        <head>
          <title>Resource directory</title>
          <meta name="description" content="A maintained directory of practical resources.">
        </head>
        <body>
          <main>
            #{before}
            <h1>Resource directory for growing teams</h1>
            #{description}
            #{extra}
            <section>
              <h2>Implementation guides</h2>
              #{section_description_card(1, detail_first: true)}
              #{section_description_card(2)}
              #{section_description_card(5)}
              #{section_description_card(6)}
            </section>
            #{between}
            <section>
              <h2>Product resources</h2>
              #{section_description_card(3)}
              #{section_description_card(4)}
              #{section_description_card(7)}
              #{section_description_card(8)}
            </section>
            #{after}
          </main>
        </body>
      </html>
    HTML
  end

  def extract_with_readability_root(page, selector)
    extract_payload(page)
    page.evaluate(<<~JS)
      (() => {
        const NarrowReadability = function() {};
        NarrowReadability.prototype.parse = function() {
          const root = document.querySelector(#{selector.to_json});
          return {
            title: document.title,
            content: root ? root.outerHTML : "",
            textContent: root ? root.textContent : ""
          };
        };
        window.Readability = NarrowReadability;

        return window.FetchUtilExtract.extract({ reader_mode: true });
      })()
    JS
  end

  it "preserves page-owned prose without repeating section or item content" do
    description = <<~HTML
      <p>Free migration support.</p>
      <h2>Resource directory</h2>
      <p>Choose, configure, and maintain every workflow from one practical resource directory.</p>
      <h2 class="sp-headline-block">Built for complete operational visibility</h2>
      <p>Each workflow remains auditable while teams adapt policy, ownership, and delivery over time.</p>
    HTML
    between = "<p>Inter-section guidance stays between implementation guides and product resources.</p>"
    long_after_text = (1..45).map do |number|
      "Operational note #{number} preserves a distinct visible requirement after every listed product resource."
    end.join(" ")
    long_after_text = "#{long_after_text} Final uncapped guidance marker."

    html = sectioned_directory_html(
      description: description,
      between: between,
      after: "<p>#{long_after_text}</p>"
    )
    with_url_page("https://example.com/reports", html) do |page|
      result = extract_payload(page)
      markdown = result.fetch("markdown")

      expect(result.fetch("contentType")).to eq("list")
      expect(long_after_text.length).to be > 2000
      expect(markdown).to include("Free migration support.")
      expect(markdown.lines.map(&:strip)).not_to include("## Resource directory")
      expect(markdown).to include("Choose, configure, and maintain every workflow")
      expect(markdown).to include("Resource directory for growing teams")
      expect(markdown).to include("Built for complete operational visibility")
      expect(markdown).to include("Each workflow remains auditable")
      expect(markdown).to include("Final uncapped guidance marker")
      expect(markdown.index("Choose, configure")).to be < markdown.index("Implementation guides")
      expect(markdown.index("Implementation guides")).to be < markdown.index("Guide 1")
      expect(markdown.index("Guide 1")).to be < markdown.index("Focused summary for resource record 1")
      expect(markdown.index("Guide 6")).to be < markdown.index("Inter-section guidance")
      expect(markdown.index("Inter-section guidance")).to be < markdown.index("Product resources")
      expect(markdown.index("Guide 8")).to be < markdown.index("Final uncapped guidance marker")
      expect(markdown.scan("Implementation guides").length).to eq(1)
      expect(markdown.scan("Guide 1").length).to eq(1)
      expect(result.fetch("textContent")).to include("Choose, configure, and maintain every workflow")
      expect(result.fetch("textContent")).to include("Final uncapped guidance marker")
      expect(result.fetch("textContent").gsub(/\s+/, " ").strip).to eq(markdown.gsub(/\s+/, " ").strip)
      expect(result.keys).not_to include("sectionMarkdownWithDescription")
    end
  end

  it "does not relabel an opaque-path list from its deferred description" do
    before = <<~HTML
      <p>This page-owned overview deliberately exceeds one hundred characters so it would look article-like if deferred prose participated in opaque-path classification.</p>
    HTML

    with_url_page("https://example.com/records/abc123", sectioned_directory_html(before: before)) do |page|
      result = extract_payload(page)

      expect(result.fetch("markdown")).to include("This page-owned overview deliberately exceeds")
      expect(result.fetch("contentType")).to eq("list")
    end
  end

  it "does not let deferred prose prevent warning-driven interstitial promotion" do
    overview = ("This maintained overview explains the public directory and its stable records without changing the listed policy links. " * 12).strip
    html = <<~HTML
      <!doctype html>
      <html>
        <head><title>Policy resources</title></head>
        <body>
          <main>
            <h1>Policy resources</h1>
            <p>#{overview}</p>
            <section>
              <h2>Cookie choices</h2>
              #{(1..4).map { |number| compact_consent_card(number) }.join}
            </section>
            <section>
              <h2>Consent choices</h2>
              #{(5..8).map { |number| compact_consent_card(number) }.join}
            </section>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://example.com/reports", html) do |page|
      result = extract_payload(page)

      expect(result.fetch("contentType")).to eq("interstitial")
      expect(result.fetch("warnings")).to include("consent_interstitial")
      expect(result.fetch("markdown")).not_to include("This maintained overview")
      expect(result.fetch("textContent")).not_to include("This maintained overview")
    end
  end

  it "excludes prose owned by unselected and hidden record cards" do
    extra = <<~HTML
      <aside>
        <div class="story-card">
          <h3>Unselected promotional story that must not become page description</h3>
          <p>Promotional card detail belongs to its own omitted record rather than the directory.</p>
        </div>
        <article class="resource-card" hidden>
          <h3><a href="/articles/hidden">Hidden selected record</a></h3>
          <p>Hidden selected record prose must not enter the visible directory.</p>
        </article>
        <div class="story-card" style="display: none">
          <h3>Hidden unselected record</h3>
          <p>Hidden unselected record prose must not enter the visible directory.</p>
        </div>
      </aside>
    HTML
    description = <<~HTML
      <h2 class="sp-headline-block">Page-owned guidance remains visible</h2>
      <p>This independent context explains how readers should use the complete directory below.</p>
    HTML

    with_page(sectioned_directory_html(description: description, extra: extra)) do |page|
      markdown = extract_payload(page).fetch("markdown")

      expect(markdown).to include("Page-owned guidance remains visible")
      expect(markdown).to include("This independent context explains")
      expect(markdown).not_to include("Unselected promotional story")
      expect(markdown).not_to include("Promotional card detail belongs")
      expect(markdown).not_to include("Hidden selected record")
      expect(markdown).not_to include("Hidden unselected record")
    end
  end

  it "does not let a deferred description replace a rich article" do
    paragraphs = [
      "Operational context explains why teams need durable evidence before changing shared systems. ",
      "Implementation guidance describes careful sequencing, ownership, review, and rollback decisions. ",
      "Verification guidance connects observable outcomes to explicit controls and preserved source data. "
    ].map { |sentence| "<p>#{sentence * 7}</p>" }.join
    description = <<~HTML
      <article role="main" data-readability-root>
        <h1>Evidence-led operations report</h1>
        <p class="byline">By Example Team</p>
        #{paragraphs}
      </article>
    HTML
    html = <<~HTML
      <title>Evidence-led operations report</title>
      #{sectioned_directory_html(description: description)}
    HTML

    with_url_page("https://example.com/reports", html) do |page|
      result = extract_with_readability_root(page, "[data-readability-root]")

      expect(result.fetch("contentType")).to eq("article")
      expect(result.fetch("markdown")).to include("Operational context explains")
      expect(result.fetch("markdown")).not_to include("Guide 1")
    end
  end
end
