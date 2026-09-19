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
      "sectionCard: sectionCardCandidate, " \
      "context: listPageContext, description: listDescriptionMarkdown, clone: visibleListClone, " \
      "ownedTitle: genericListOwnedAnchorTitle }; })(window);"
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

  it "keeps a card-owned heading before its description and trailing action" do
    html = <<~HTML
      <html><head><title>Platform capabilities</title></head><body><main>
        <div class="one-text-block">
          <i class="feature-icon"><svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="32px" height="23px" style="opacity: 1 !important; transform: none !important;"><image x="0px" y="0px" width="32px" height="23px" xlink:href="data:img/png;base64,AAAA" style="opacity: 1 !important; transform: none !important;"></image></svg></i>
          <h3>Cutting-Edge Technologies</h3>
          <p>Expand your hosting platform with modern extensions and integrations built for reliable administration.</p>
          <a href="/features/technology">See the list</a>
        </div>
      </main></body></html>
    HTML
    with_url_page("https://platform.example/features", html) do |page|
      page.add_script_tag(content: list_card_fields_source)
      result = page.evaluate(<<~JAVASCRIPT)
        (() => {
          const before = document.body.innerHTML;
          const card = document.querySelector('.one-text-block');
          const item = FetchUtilListFieldsTest.sectionCard(card, {
            listContext: FetchUtilListFieldsTest.context()
          });
          item.detail = 'Cutting-Edge Technologies';
          return {
            before,
            after: document.body.innerHTML,
            markdown: FetchUtilListFieldsTest.render([item])
          };
        })()
      JAVASCRIPT

      expect(result["after"]).to eq(result["before"])
      expect(result["markdown"]).to eq(
        "- [See the list](https://platform.example/features/technology) - " \
        "Cutting-Edge Technologies Expand your hosting platform with modern extensions " \
        "and integrations built for reliable administration."
      )
      expect(result["markdown"].scan("Cutting-Edge Technologies")).to eq(["Cutting-Edge Technologies"])
    end
  end

  it "does not reorder ambiguous card context" do
    variants = {
      extra_link: '<a href="/other">Other destination</a>',
      extra_heading: '<h4>Secondary heading</h4>',
      button: '<button type="button">Change view</button>',
      nested_record: '<article><p>Independent nested record with enough prose to remain separate.</p></article>',
      role_control: '<div role="SWITCH presentation">Toggle mode</div>',
      custom_control: '<x-mode-toggle>Toggle mode</x-mode-toggle>',
      structured_content: '<figure><figcaption>Independent supporting figure</figcaption></figure>',
      meaningful_svg: '<svg><text>Independent chart label</text></svg>',
      semantic_svg: '<svg><image href="data:img/png;base64,AAAA"></image><path d="M0 0h10v10z"></path></svg>',
      executable_svg: '<svg onpointerenter="return false"><image href="data:img/png;base64,AAAA"></image></svg>',
      labelled_svg: '<svg role="img" aria-label="Meaningful icon"><image href="data:img/png;base64,AAAA"></image></svg>',
      external_paint: '<svg fill="url(https://evil.example/paint.svg#fill)"><image href="data:img/png;base64,AAAA"></image></svg>',
      conflicting_refs: '<svg><image href="data:image/png;base64,AAAA" xlink:href="https://evil.example/image.png"></image></svg>',
      nested_svg_data: '<svg><image href="data:image/svg+xml,&lt;svg xmlns=&quot;http://www.w3.org/2000/svg&quot;&gt;&lt;script&gt;run()&lt;/script&gt;&lt;/svg&gt;"></image></svg>',
      quoted_style: '<svg style="transform: none; opacity: \'1; fill: red\'"><image href="data:img/png;base64,AAAA"></image></svg>',
      data_uri_style: '<svg style="transform: data:image/svg+xml; opacity: 1"><image href="data:img/png;base64,AAAA"></image></svg>',
      camelcase_event: '<svg onClick="return false"><image href="data:img/png;base64,AAAA"></image></svg>',
      html_image_element: '<svg></svg>',
      script_content: '<script type="application/json">{"record":"other"}</script>',
      style_content: '<style>.other { display: block; }</style>',
      iframe_content: '<iframe src="/embedded-record"></iframe>',
      template_content: '<template><p>Deferred independent record</p></template>',
      noscript_content: '<noscript>Fallback independent record</noscript>'
    }
    cards = variants.map do |name, addition|
      <<~HTML
        <div class="one-text-block" id="#{name}">
          <h3>#{name.to_s.tr("_", " ").capitalize}</h3>
          <p>Expand this hosting platform with modern extensions and reliable administrative integrations.</p>
          #{addition}
          <a href="/features/#{name}">See the list</a>
        </div>
      HTML
    end.join
    cards << <<~HTML
      <div class="one-text-block" id="description_after_action">
        <h3>Description after action</h3>
        <a href="/features/description-after">See the list</a>
        <p>Expand this hosting platform with modern extensions and reliable administrative integrations.</p>
      </div>
    HTML
    cards << <<~HTML
      <div class="one-text-block" id="short_text_after_action">
        <h3>Short text after action</h3>
        <p>Expand this hosting platform with modern extensions and reliable administrative integrations.</p>
        <a href="/features/short-after">See the list</a>
        <p>Updated daily.</p>
      </div>
      <div class="one-text-block" id="inline_action">
        <h3>Inline action</h3>
        <p>Expand this hosting platform with modern extensions and reliable administrative integrations. <a href="/features/inline">See the list</a></p>
      </div>
      <div class="one-text-block" id="div_text_after_action">
        <h3>Div text after action</h3>
        <p>Expand this hosting platform with modern extensions and reliable administrative integrations.</p>
        <a href="/features/div-after">See the list</a>
        <div>Updated daily.</div>
      </div>
    HTML
    html = "<html><head><title>Platform capabilities</title></head><body><main>#{cards}</main></body></html>"

    with_url_page("https://platform.example/features", html) do |page|
      page.add_script_tag(content: list_card_fields_source)
      result = page.evaluate(<<~JAVASCRIPT)
        (() => {
          const htmlImage = document.createElement('image');
          htmlImage.setAttribute('href', 'data:image/png;base64,AAAA');
          document.querySelector('#html_image_element svg').append(htmlImage);
          return Array.from(document.querySelectorAll('.one-text-block')).map(card => {
          const item = FetchUtilListFieldsTest.sectionCard(card, {
            listContext: FetchUtilListFieldsTest.context()
          });
          return { id: card.id, hasContextHeading: !!(item && item.contextHeading) };
          });
        })()
      JAVASCRIPT

      expect(result.to_h { |row| [row["id"], row["hasContextHeading"]] }).to eq(
        "extra_link" => false,
        "extra_heading" => false,
        "button" => false,
        "nested_record" => false,
        "role_control" => false,
        "custom_control" => false,
        "structured_content" => false,
        "meaningful_svg" => false,
        "semantic_svg" => false,
        "executable_svg" => false,
        "labelled_svg" => false,
        "external_paint" => false,
        "conflicting_refs" => false,
        "nested_svg_data" => false,
        "quoted_style" => false,
        "data_uri_style" => false,
        "camelcase_event" => false,
        "html_image_element" => false,
        "script_content" => false,
        "style_content" => false,
        "iframe_content" => false,
        "template_content" => false,
        "noscript_content" => false,
        "description_after_action" => false,
        "short_text_after_action" => false,
        "inline_action" => false,
        "div_text_after_action" => false
      )
    end
  end

  it "renders a direct record's byline and date once" do
    records = 4.times.map do |index|
      <<~HTML
        <li class="story-row">
          <a class="copy-container" href="/stories/#{index + 1}">
            <b class="title">Feature story number #{index + 1}</b>
            <span class="byline-note">Reporter profile note #{index + 1}</span>
            <span class="comment-byline">Commenter #{index + 1}</span>
            <b class="byline">By Shared Desk</b>
            <b class="time">September 1, 2026 | 4:00pm</b>
            <span class="timeline">Background timeline note #{index + 1}</span>
          </a>
        </li>
      HTML
    end.join
    html = <<~HTML
      <html><head><title>Feature stories</title></head><body><main><ul>#{records}</ul></main></body></html>
    HTML

    with_url_page("https://features.example/", html) do |page|
      page.add_script_tag(content: list_card_fields_source)
      result = page.evaluate(<<~JAVASCRIPT)
        (() => {
          const context = FetchUtilListFieldsTest.context();
          const items = Array.from(document.querySelectorAll('.story-row')).map(card =>
            FetchUtilListFieldsTest.candidate(card.querySelector('a'), card, context));
          return {
            markdown: FetchUtilListFieldsTest.render(items)
          };
        })()
      JAVASCRIPT

      4.times do |index|
        line = "- [Feature story number #{index + 1}](https://features.example/stories/#{index + 1}) - " \
               "By Shared Desk - September 1, 2026 | 4:00pm - " \
               "Reporter profile note #{index + 1} Background timeline note #{index + 1}"
        expect(result["markdown"].lines.map(&:strip)).to include(line)
        expect(result["markdown"].scan("Reporter profile note #{index + 1}").length).to eq(1)
        expect(result["markdown"].scan("Background timeline note #{index + 1}").length).to eq(1)
        expect(result["markdown"]).not_to include("Commenter #{index + 1}")
      end
      expect(result["markdown"].scan("By Shared Desk").length).to eq(4)
      expect(result["markdown"].scan("September 1, 2026 | 4:00pm").length).to eq(4)
    end
  end

  it "separates a declared record title from its nested author metadata" do
    html = <<~HTML
      <html><head><title>Front page</title></head><body><main><section>
        <div class="column"><article class="story-card">
          <a href="/stories/owned" title="A precise source-owned headline">
            <figure><img src="/owned.jpg" alt="Owned story image"></figure>
            <h3><span class="card__title">A precise source-owned headline</span>
              <span data-href="/authors/ada" class="card__author-link anchor-js">
                <span class="card__author-label">By </span>Ada Reporter
              </span>
            </h3>
          </a>
          <div class="related-reference"><a href="/stories/related">A precise source-owned headline</a></div>
        </article></div>
        <div class="column"><article class="story-card">
          <a href="/stories/context" title="A second declared headline">
            <h3><span class="card__title">A second declared headline</span>
              <span class="editorial-context">Analysis desk context</span>
            </h3>
          </a>
        </article></div>
      </section></main></body></html>
    HTML

    with_url_page("https://features.example/", html) do |page|
      page.add_script_tag(content: list_card_fields_source)
      result = page.evaluate(<<~JAVASCRIPT)
        (() => {
          const before = document.body.innerHTML;
          const context = FetchUtilListFieldsTest.context();
          const cards = Array.from(document.querySelectorAll('article'));
          const items = cards.map(card => FetchUtilListFieldsTest.candidate(card.querySelector('a'), card, context));
          return {
            texts: items.map(item => item.text),
            displayTexts: items.map(item => item.displayText || ''),
            markdown: FetchUtilListFieldsTest.render(items),
            unchanged: before === document.body.innerHTML
          };
        })()
      JAVASCRIPT

      expected_texts = [
        "A precise source-owned headline By Ada Reporter",
        "A second declared headline Analysis desk context"
      ]
      expect(result["texts"]).to eq(expected_texts)
      expect(result["displayTexts"]).to eq(["A precise source-owned headline", ""])
      expect(result["markdown"]).to include(
        "[A precise source-owned headline](https://features.example/stories/owned) - By Ada Reporter",
        "[A precise source-owned headline](https://features.example/stories/related)",
        "[A second declared headline Analysis desk context](https://features.example/stories/context)"
      )
      expect(result["markdown"].scan("A precise source-owned headline").length).to eq(2)
      expect(result["markdown"].scan("Ada Reporter").length).to eq(1)
      expect(result["unchanged"]).to be(true)
    end
  end

  it "rejects ambiguous, hidden, interactive, or unsafe title-author splits" do
    records = <<~HTML
      <article data-case="valid"><a href="/valid" title="Valid headline"><h3>
        <span class="card__title">Valid headline</span>
        <span data-href="/authors/valid" class="card__author-link anchor-js">By Valid Author</span>
      </h3></a></article>
      <article data-case="interaction"><a href="/interaction" title="Interaction headline"><h3>
        <span class="card__title">Interaction headline</span>
        <span class="comment-byline">By Comment Author</span>
      </h3></a></article>
      <article data-case="hidden"><a href="/hidden" title="Hidden headline"><h3>
        <span class="card__title">Hidden headline</span>
        <span class="card__author-link" hidden>By Hidden Author</span>
      </h3></a></article>
      <article data-case="nested-interaction"><a href="/nested-interaction" title="Nested interaction"><h3>
        <span class="card__title">Nested interaction</span>
        <span class="card__author-link">By Desk <span class="comment-author">Commenter</span></span>
      </h3></a></article>
      <article data-case="nested-hidden"><a href="/nested-hidden" title="Nested hidden"><h3>
        <span class="card__title">Nested hidden</span>
        <span class="card__author-link">By Desk <span hidden>Hidden contributor</span></span>
      </h3></a></article>
      <article data-case="authors"><a href="/authors" title="Many authors headline"><h3>
        <span class="card__title">Many authors headline</span>
        <span class="card__author-link">By First Author</span><span class="byline">By Second Author</span>
      </h3></a></article>
      <article data-case="titles"><a href="/titles" title="First title"><h3>
        <span class="card__title">First title</span><span class="feature-title">Second title</span>
        <span class="card__author-link">By Title Author</span>
      </h3></a></article>
      <article data-case="mismatch"><a href="/mismatch" title="Different declared title"><h3>
        <span class="card__title">Visible title</span><span class="card__author-link">By Mismatch Author</span>
      </h3></a></article>
      <article data-case="headings"><a href="/headings" title="Two headings"><h3>
        <span class="card__title">Two headings</span><span class="card__author-link">By Heading Author</span>
      </h3><h4>Additional context</h4></a></article>
      <article data-case="unsafe"><a href="javascript:openStory()" title="Unsafe headline"><h3>
        <span class="card__title">Unsafe headline</span><span class="card__author-link">By Unsafe Author</span>
      </h3></a></article>
    HTML
    html = "<html><head><title>Records</title></head><body><main>#{records}</main></body></html>"

    with_url_page("https://features.example/", html) do |page|
      page.add_script_tag(content: list_card_fields_source)
      titles = page.evaluate(<<~JAVASCRIPT)
        Object.fromEntries(Array.from(document.querySelectorAll('article')).map(record => [
          record.dataset.case,
          FetchUtilListFieldsTest.ownedTitle(record.querySelector('a'))
        ]))
      JAVASCRIPT

      expect(titles).to eq(
        "valid" => "Valid headline",
        "interaction" => "",
        "hidden" => "",
        "nested-interaction" => "",
        "nested-hidden" => "",
        "authors" => "",
        "titles" => "",
        "mismatch" => "",
        "headings" => "",
        "unsafe" => ""
      )
    end
  end

  it "preserves a same-label related heading with a different destination" do
    html = <<~HTML
      <html><head><title>Records</title></head><body><main>
        <article class="story-card">
          <a href="/primary">Primary headline</a>
          <h4><a href="/related">Related heading</a></h4>
        </article>
      </main></body></html>
    HTML

    with_url_page("https://features.example/", html) do |page|
      page.add_script_tag(content: list_card_fields_source)
      markdown = page.evaluate(<<~JAVASCRIPT)
        (() => {
          const card = document.querySelector('article');
          return FetchUtilListFieldsTest.render([{
            card,
            text: 'Primary headline',
            displayText: 'Related heading',
            url: '/primary'
          }]);
        })()
      JAVASCRIPT

      expect(markdown).to include(
        "[Related heading](https://features.example/primary)",
        "[Related heading](https://features.example/related)"
      )
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
            <span class="byline">By Cartography Desk</span>
            <span class="time">September 8, 2026 | 4:00pm</span>
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
      expect(result["markdown"]).to include("By Cartography Desk", "September 8, 2026 | 4:00pm")
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

  it "preserves headings of every level and length without changing candidate scoring" do
    headings = ["Courses", "Research", "Alumni", "Support", "Partners", "Specialized institutional guidance " * 90]
    html = <<~HTML
      <html><head><title>Learning collections</title></head><body><main>
        #{headings.each_with_index.map { |text, index| "<h#{index + 1}>#{text}</h#{index + 1}>" }.join}
        <h4 hidden>Hidden draft heading</h4>
        <aside class="weather-widget"><h3>Weather forecast</h3><p>Weather forecast: wind, rain, snow and temperature.</p></aside>
        <p>Short paragraph</p>
        <div class="story-card"><a href="/learn/maps">Explore cartography workshops</a></div>
      </main></body></html>
    HTML
    with_url_page("https://learning.example/collections", html) do |page|
      page.add_script_tag(content: list_card_fields_source)
      result = page.evaluate(<<~JAVASCRIPT)
        (() => {
          const root = FetchUtilListFieldsTest.clone(document.querySelector('main'));
          const card = root.querySelector('.story-card');
          const items = [{ card, text: 'Explore cartography workshops', url: '/learn/maps' }];
          return { scoring: FetchUtilListFieldsTest.description(root),
            empty: FetchUtilListFieldsTest.description(root, []),
            description: FetchUtilListFieldsTest.description(root, items) };
        })()
      JAVASCRIPT

      expect(result["scoring"]).to eq("")
      expect(result["empty"]).to eq("")
      expect(result["description"]).to eq(headings.map { |text| "## #{text.strip}" }.join("\n\n"))
      expect(result["description"]).not_to include("Hidden draft", "Short paragraph", "Weather forecast")
    end
  end

  it "deduplicates owned headings while preserving an independent identical heading" do
    html = <<~HTML
      <html><head><title>Learning collections</title></head><body><main>
        <h4>Workshops</h4><h5>Learning collections</h5><h6>Explore cartography workshops</h6>
        <h4>Help</h4>
        <div class="story-card"><h6>Explore cartography workshops</h6><a href="/learn/maps">Explore cartography workshops</a></div>
      </main></body></html>
    HTML
    with_url_page("https://learning.example/collections", html) do |page|
      page.add_script_tag(content: list_card_fields_source)
      description = page.evaluate(<<~JAVASCRIPT)
        (() => {
          const root = document.querySelector('main');
          const card = root.querySelector('.story-card');
          const items = [{ card, text: 'Explore cartography workshops', url: '/learn/maps' }];
          return FetchUtilListFieldsTest.description(root, items, {
            sectionLabels: ['Workshops'], pageTitles: ['Learning collections']
          });
        })()
      JAVASCRIPT

      expect(description).to eq("## Explore cartography workshops\n\n## Help")
    end
  end

  it "keeps linked record titles on the existing description admission path" do
    title = "Build geographic maps with historical and contemporary observations"
    html = <<~HTML
      <html><head><title>Learning collections</title></head><body><main>
        <a href="/short"><h2>Short record</h2></a>
        <h2><a href="/long">#{title}</a></h2>
        <h4><a href="/deep">Deep linked records are not standalone page description labels</a></h4>
        <div class="story-card"><a href="/learn/maps">Explore cartography workshops</a></div>
      </main></body></html>
    HTML
    with_url_page("https://learning.example/collections", html) do |page|
      page.add_script_tag(content: list_card_fields_source)
      result = page.evaluate(<<~JAVASCRIPT)
        (() => {
          const root = document.querySelector('main');
          const card = root.querySelector('.story-card');
          return { scoring: FetchUtilListFieldsTest.description(root),
            description: FetchUtilListFieldsTest.description(root, [
              { card, text: 'Explore cartography workshops', url: '/learn/maps' }
            ]) };
        })()
      JAVASCRIPT

      expect(result.values).to eq(["## #{title}", "## #{title}"])
    end
  end
end
