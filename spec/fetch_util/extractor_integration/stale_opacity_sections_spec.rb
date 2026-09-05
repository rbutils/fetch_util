# frozen_string_literal: true

RSpec.describe "FetchUtil extractor integration - stale opacity sections" do
  include_context "extractor integration helpers"

  def stale_opacity_section(index, class_name: "feature-panel", style: "opacity: 0", nested: "")
    <<~HTML
      <section class="content-section">
        <div class="#{class_name}" style="#{style}">
          <h2>Display collection #{index}</h2>
          <p>
            Display collection #{index} explains a distinct viewing experience, supported formats, setup choices,
            and the material capabilities available to households choosing this television platform.
          </p>
          <a class="news-collection-item-link-block" href="/collections/#{index}">
            <h3 class="news-card-date"><time>September #{index}, 2026</time></h3>
            <h4 class="news-card-title">Complete display guide for collection #{index}</h4>
            <span>Read More</span>
          </a>
          #{nested}
        </div>
      </section>
    HTML
  end

  def stale_opacity_html(sections:, visible: "")
    <<~HTML
      <html><head><title>Display collections</title></head><body>
        <h1>Experience every display collection</h1>
        #{visible}
        #{sections}
      </body></html>
    HTML
  end

  def stale_opacity_test_source
    root = File.expand_path("../../..", __dir__)
    manifest = File.join(root, "websieve", "manifest.txt")
    source = File.readlines(manifest, chomp: true).reject(&:empty?).map do |entry|
      File.read(File.join(root, "websieve", entry))
    end.join("\n")
    source.sub(
      "})(window);",
      <<~JAVASCRIPT
        global.FetchUtilStaleOpacityTest = {
          detailedListMarkdown: staleOpacityDetailedListMarkdown,
          keepsCurrentMarkdown: staleOpacityKeepsCurrentMarkdown
        };
        })(window);
      JAVASCRIPT
    )
  end

  it "recovers every record from stale opacity sections in DOM order" do
    sections = (1..6).map { |index| stale_opacity_section(index) }.join

    with_url_page("https://displays.example/", stale_opacity_html(sections: sections)) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)
      links = payload.fetch("markdown").scan(%r{/collections/(\d+)})

      expect(payload["contentType"]).to eq("list")
      expect(links.flatten.map(&:to_i)).to eq((1..6).to_a)
      expect(payload.fetch("markdown")).to include(
        "Experience every display collection",
        "material capabilities available to households",
        "Complete display guide for collection 6"
      )
      expect(payload.fetch("warnings")).not_to include("empty_extraction", "short_extraction")
      expect(payload).not_to have_key("listExtraction")
    end
  end

  it "requires multiple independently owned sections" do
    html = stale_opacity_html(sections: stale_opacity_section(1))

    with_url_page("https://displays.example/", html) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)

      expect(payload.fetch("markdown")).not_to include("/collections/1")
    end
  end

  it "rejects interactive and privacy-owned hidden branches" do
    classes = %w[carousel-panel tab-panel newsletter-privacy]
    sections = classes.map.with_index do |class_name, index|
      stale_opacity_section(index + 1, class_name: class_name)
    end.join

    with_url_page("https://displays.example/", stale_opacity_html(sections: sections)) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)

      expect(payload.fetch("markdown")).not_to include("/collections/")
    end
  end

  it "rejects mixed hidden-state ownership" do
    sections = [
      stale_opacity_section(1),
      stale_opacity_section(2, style: "display: none"),
      stale_opacity_section(3, style: "visibility: hidden")
    ].join

    with_url_page("https://displays.example/", stale_opacity_html(sections: sections)) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)

      expect(payload.fetch("markdown")).not_to include("/collections/")
    end
  end

  it "rejects material nested chrome ownership" do
    nested = '<aside class="newsletter"><p>Private subscriber promotion with material copy.</p><a href="/subscribe">Subscribe</a></aside>'
    sections = (1..3).map { |index| stale_opacity_section(index, nested: nested) }.join

    with_url_page("https://displays.example/", stale_opacity_html(sections: sections)) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)

      expect(payload.fetch("markdown")).not_to include("/collections/")
    end
  end

  it "rejects independently hidden nested material ownership" do
    nested = '<div><article hidden><h4><a href="https://displays.example/alternate">Alt</a></h4></article></div>'
    sections = (1..3).map { |index| stale_opacity_section(index, nested: nested) }.join

    with_url_page("https://displays.example/", stale_opacity_html(sections: sections)) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)

      expect(payload.fetch("markdown")).not_to include("/collections/")
      expect(payload.fetch("markdown")).not_to include("/alternate")
    end
  end

  it "enriches duplicate rendered lines locally and requires exact visible blocks" do
    with_page("<html><body></body></html>") do |page|
      page.evaluate(stale_opacity_test_source)
      result = JSON.parse(page.evaluate(<<~JAVASCRIPT))
        JSON.stringify((function() {
          document.body.innerHTML = [
            '<a id="first" class="news-collection-item-link-block"><h3 class="news-card-date">Shared date</h3><h4 class="news-card-title">First owned headline</h4></a>',
            '<a id="second" class="news-collection-item-link-block"><h3 class="news-card-date">Shared date</h3><h4 class="news-card-title">Second owned headline</h4></a>'
          ].join('');
          var items = ['first', 'second'].map(function(id) {
            return {
              text: 'Shared date',
              url: 'https://records.example/shared',
              detail: '',
              card: document.getElementById(id)
            };
          });
          var line = '- [Shared date](https://records.example/shared)';
          return {
            markdown: window.FetchUtilStaleOpacityTest.detailedListMarkdown({
              markdown: line + '\\n' + line,
              listExtraction: { items: items }
            }),
            collision: window.FetchUtilStaleOpacityTest.keepsCurrentMarkdown('News', '## Latest News'),
            exact: window.FetchUtilStaleOpacityTest.keepsCurrentMarkdown('News', '## News\\n\\nMore')
          };
        })())
      JAVASCRIPT

      expect(result.fetch("markdown").scan("First owned headline").length).to eq(1)
      expect(result.fetch("markdown").scan("Second owned headline").length).to eq(1)
      expect(result).to include("collision" => false, "exact" => true)
    end
  end

  it "does not replace a material visible list" do
    visible = (1..4).map do |index|
      <<~HTML
        <article>
          <h2><a href="/visible/#{index}">Visible display guide #{index}</a></h2>
          <p>This visible guide has its own material summary and remains the selected collection.</p>
        </article>
      HTML
    end.join
    sections = (1..4).map { |index| stale_opacity_section(index) }.join

    with_url_page("https://displays.example/guides", stale_opacity_html(sections: sections, visible: visible)) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)

      expect(payload.fetch("markdown")).to include("/visible/1", "/visible/4")
      expect(payload.fetch("markdown")).not_to include("/collections/")
    end
  end
end
