# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'generic focal article rail boundaries' do
  include_context 'extractor integration helpers'

  let(:article_title) { 'Coastal restoration protects three towns' }

  def focal_ownership_source
    @focal_ownership_source ||= begin
      root = File.expand_path('../../..', __dir__)
      source = File.readlines(File.join(root, 'websieve/manifest.txt'), chomp: true)
                   .reject { |line| line.empty? || line.start_with?('#') }
                   .map { |path| File.read(File.join(root, 'websieve', path)) }.join("\n")
      source.sub('})(window);', <<~JS.chomp)
        global.__broadMixedArticleFocal = function() {
          var root = visibilityPrunedClone(document.body);
          return broadMixedArticleFocal(root.querySelector("main"));
        };
        global.__scoreNode = scoreNode;
        global.__fallbackContent = fallbackContent;
        global.__fallbackContainedArticleRecords = fallbackContainedArticleRecords;
        global.__focalOwnershipInnermostCandidates = focalOwnershipInnermostCandidates;
        global.__visibilityPrunedBodyHtml = function() {
          return visibilityPrunedClone(document.body).innerHTML;
        };
        })(window);
      JS
    end
  end

  def focal_article(tag: 'article', attributes: '')
    <<~HTML
      <#{tag} id="focal" #{attributes}>
        <h1>#{article_title}</h1>
        <p>The restoration project reconnects three towns while protecting homes that flooded during consecutive winters.</p>
        <p>Engineers rebuilt the coastline after reviewing historical maps, drainage records, and testimony from residents.</p>
        <p>Independent researchers measured water levels throughout the work and published the complete monitoring data.</p>
        <p>The final design preserves wetlands and creates safer walking routes between neighboring communities.</p>
      </#{tag}>
    HTML
  end

  def rail_records(count: 3, destination: nil, destinations: nil)
    Array.new(count) do |index|
      href = destinations ? destinations.fetch(index) : (destination || "/regional/#{index + 1}")
      <<~HTML
        <article class="story-card">
          <h2><a href="#{href}">Regional report number #{index + 1}</a></h2>
          <p>This separately reported event contains local evidence and does not belong to the coastal investigation.</p>
        </article>
      HTML
    end.join
  end

  def dom_state(page)
    page.evaluate(<<~JAVASCRIPT)
      (function() {
        var roots = [document.body];
        var shadowHtml = [];
        for (var index = 0; index < roots.length; index += 1) {
          Array.from(roots[index].querySelectorAll("*")).forEach(function(node) {
            if (!node.shadowRoot || roots.indexOf(node.shadowRoot) !== -1) return;
            roots.push(node.shadowRoot);
            shadowHtml.push(node.shadowRoot.innerHTML);
          });
        }
        var controls = [];
        roots.forEach(function(root) {
          Array.from(root.querySelectorAll("input, select, textarea")).forEach(function(control) {
            controls.push([control.value, Boolean(control.checked), control.selectedIndex]);
          });
        });
        return { body: document.body.innerHTML, shadows: shadowHtml, controls: controls };
      })()
    JAVASCRIPT
  end

  def focal_selection(url, body)
    selected = nil
    with_url_page(url, "<html><head><title>#{article_title}</title></head><body>#{body}</body></html>") do |page|
      source_state = dom_state(page)
      page.add_script_tag(content: focal_ownership_source)
      selected = page.evaluate('window.__broadMixedArticleFocal()?.id || null')
      expect(dom_state(page)).to eq(source_state)
    end
    selected
  end

  it 'does not collapse independent collections on list-like routes' do
    %w[related-stories analysis-list news-feed].each_with_index do |class_name, index|
      selection = focal_selection(
        "https://example.test/news/reports#{index.zero? ? "" : index}/",
        "<main>#{focal_article}<section class=#{class_name}><h2>Independent reporting</h2>#{rail_records}</section></main>"
      )

      expect(selection).to be_nil, class_name
    end

    selection = focal_selection(
      'https://example.test/list',
      "<main>#{focal_article}<section class=related-stories><h2>Independent reporting</h2>#{rail_records}</section></main>"
    )

    expect(selection).to be_nil
  end

  it 'keeps class-only feeds and semantic live feeds outside the focal article' do
    groups = {
      'class feed' => '<section class="news-feed">',
      'semantic feed' => '<section class="related-stories" role="feed">'
    }

    groups.each_with_index do |(label, opening), index|
      selection = focal_selection(
        "https://example.test/news/coastal-feed-#{index + 1}",
        "<main>#{focal_article}#{opening}<h2>Live regional coverage</h2>#{rail_records}</section></main>"
      )

      expect(selection).to be_nil, label
    end
  end

  it 'requires exactly one qualifying rail group' do
    selection = focal_selection(
      'https://example.test/news/coastal-multiple-rails',
      <<~HTML
        <main>
          #{focal_article}
          <section class="related-stories"><h2>Regional reports</h2>#{rail_records}</section>
          <section class="recommended-stories"><h2>Recommended reports</h2>#{rail_records(destinations: %w[/popular/1 /popular/2 /popular/3])}</section>
        </main>
      HTML
    )

    expect(selection).to be_nil
  end

  it 'requires the sole group heading to lead its direct rail group' do
    headingless_selection = focal_selection(
      'https://example.test/news/coastal-headingless-rail',
      "<main>#{focal_article}<section class=related-stories>#{rail_records}</section></main>"
    )
    misplaced_selection = focal_selection(
      'https://example.test/news/coastal-misplaced-heading',
      <<~HTML
        <main>
          #{focal_article}
          <section class="related-stories">
            #{rail_records(count: 1)}
            <h2>Important safety instructions for residents</h2>
            #{rail_records(count: 2)}
          </section>
        </main>
      HTML
    )

    expect(headingless_selection).to be_nil
    expect(misplaced_selection).to be_nil
  end

  it 'requires three distinct rail destinations and at most one group heading' do
    duplicate_destinations = [
      '/regional/shared?utm_source=one',
      '/regional/shared#two',
      '/regional/shared?fbclid=three'
    ]
    duplicate_selection = focal_selection(
      'https://example.test/news/coastal-duplicate-rail',
      "<main>#{focal_article}<section class=related-stories><h2>Reports</h2>#{rail_records(destinations: duplicate_destinations)}</section></main>"
    )
    ambiguous_selection = focal_selection(
      'https://example.test/news/coastal-ambiguous-rail',
      "<main>#{focal_article}<section class=related-stories><h2>Reports</h2><h3>Analysis</h3>#{rail_records}</section></main>"
    )

    expect(duplicate_selection).to be_nil
    expect(ambiguous_selection).to be_nil
  end

  it 'keeps broad ownership around resources and controls' do
    material = {
      'object' => '<object data="/evidence.pdf"></object>',
      'embed' => '<embed src="/evidence.pdf">',
      'source' => '<source src="/audio.mp3">',
      'code' => '<code>Emergency threshold = 12.5</code>',
      'form' => '<form><label>Correction<input name="correction"></label></form>',
      'details' => '<details><summary>Method note</summary>Independent method.</details>'
    }

    material.each_with_index do |(label, node), index|
      selection = focal_selection(
        "https://example.test/news/coastal-resource-#{index + 1}",
        "<main>#{focal_article}<section class=related-stories><h2>Reports</h2>#{rail_records}</section>#{node}</main>"
      )

      expect(selection).to be_nil, label
    end
  end

  it 'does not treat controlled or embedded record cards as disposable rails' do
    controls = {
      'form' => '<form><input aria-label="Regional subscription"></form>',
      'embed' => '<object data="/regional-evidence.pdf"></object>',
      'details' => '<details><summary>Regional method</summary>Evidence</details>',
      'secondary link' => '<p><a href="/regional/source">Primary source</a></p>',
      'code' => '<code>Regional threshold = 8.5</code>',
      'semantic textbox' => '<span role="textbox">Editable regional correction</span>',
      'contenteditable' => '<span contenteditable>Editable regional correction</span>',
      'video' => '<video controls src="/regional-report.mp4"></video>',
      'audio' => '<audio controls src="/regional-report.mp3"></audio>',
      'iframe' => '<iframe src="/regional-map"></iframe>',
      'canvas' => '<canvas aria-label="Regional chart"></canvas>',
      'table' => '<table><tr><th>Region</th><td>Delta</td></tr></table>',
      'figure caption' => '<figure><img src="/region.jpg"><figcaption>Regional evidence map</figcaption></figure>',
      'shadow form' => '<span><template shadowrootmode="open"><form><input aria-label="Regional subscription"></form></template></span>'
    }

    controls.each_with_index do |(label, control), index|
      records = rail_records.sub('</article>', "#{control}</article>")
      selection = focal_selection(
        "https://example.test/news/coastal-card-control-#{index + 1}",
        "<main>#{focal_article}<section class=related-stories><h2>Reports</h2>#{records}</section></main>"
      )

      expect(selection).to be_nil, label
    end
  end

  it 'does not discard article-length records inside a named rail' do
    multiple_paragraphs = rail_records.gsub(
      '</p>',
      '</p><p>This second paragraph makes each entry an independently substantive article.</p>'
    )
    long_paragraph = rail_records.gsub(
      'This separately reported event contains local evidence and does not belong to the coastal investigation.',
      'Independent regional evidence and analysis. ' * 20
    )

    [multiple_paragraphs, long_paragraph].each_with_index do |records, index|
      selection = focal_selection(
        "https://example.test/news/coastal-full-records-#{index + 1}",
        "<main>#{focal_article}<section class=related-stories><h2>Reports</h2>#{records}</section></main>"
      )

      expect(selection).to be_nil
    end
  end

  it 'does not discard one-paragraph records that independently qualify as articles' do
    latin_records = rail_records.gsub(
      'This separately reported event contains local evidence and does not belong to the coastal investigation.',
      'Independent regional evidence and analysis. ' * 9
    )
    bengali_records = rail_records.gsub(
      'This separately reported event contains local evidence and does not belong to the coastal investigation.',
      'স্বাধীন আঞ্চলিক প্রতিবেদন যাচাইকৃত তথ্য এবং বিস্তারিত বিশ্লেষণ তুলে ধরে। ' * 4
    )

    [latin_records, bengali_records].each_with_index do |records, index|
      with_url_page(
        "https://example.test/news/coastal-one-paragraph-article-#{index + 1}",
        "<html><head><title>#{article_title}</title></head><body>" \
        "<main>#{focal_article}<section class=related-stories><h2>Reports</h2>#{records}</section></main>" \
        "</body></html>"
      ) do |page|
        source_state = dom_state(page)
        page.add_script_tag(content: focal_ownership_source)
        scoreable = page.evaluate(<<~JAVASCRIPT)
          Array.from(document.querySelectorAll(".story-card")).map(function(node) {
            return Number.isFinite(window.__scoreNode(node));
          })
        JAVASCRIPT

        expect(scoreable).to all(be(true))
        expect(page.evaluate('window.__broadMixedArticleFocal()?.id || null')).to be_nil
        expect(dom_state(page)).to eq(source_state)
      end
    end
  end

  it 'indexes only scored candidates that contain another scored root' do
    independent = Array.new(40) do |index|
      "<article id=independent-#{index}><h2>Independent #{index}</h2><p>#{"Independent report. " * 16}</p></article>"
    end.join

    with_url_page(
      'https://example.test/news/candidate-containment',
      "<main id=outer><article id=inner><h1>Inner report</h1><p>#{"Owned evidence. " * 30}</p></article></main>#{independent}"
    ) do |page|
      page.add_script_tag(content: focal_ownership_source)
      containment = page.evaluate(<<~JAVASCRIPT)
        (function() {
          var records = Array.from(document.querySelectorAll("main, article")).map(function(node) {
            return { node: node, visibleNode: node };
          });
          var result = window.__fallbackContainedArticleRecords(records);
          return {
            containers: Array.from(result.containedByNode.keys()).map(function(node) { return node.id; }),
            contained: result.containedByNode.get(document.getElementById("outer")).map(function(record) {
              return record.node.id;
            })
          };
        })()
      JAVASCRIPT

      expect(containment).to eq('containers' => ['outer'], 'contained' => ['inner'])
    end
  end

  it 'selects innermost focal candidates without pairwise containment scans' do
    nested = "<article id=inner>#{focal_article}</article>"
    40.times { |index| nested = %(<div id="layer-#{index}" class="content-wrapper">#{nested}</div>) }

    with_url_page(
      'https://example.test/news/nested-candidate-index',
      "<title>#{article_title}</title><main>#{nested}</main>"
    ) do |page|
      page.add_script_tag(content: focal_ownership_source)
      candidates = page.evaluate(<<~JAVASCRIPT)
        window.__focalOwnershipInnermostCandidates(document.querySelector("main")).map(function(node) {
          return node.id;
        });
      JAVASCRIPT

      expect(candidates).to eq(['focal'])
    end
  end

  it 'preserves the earlier fallback winner when independent candidates tie' do
    article = '<h1>Equal scoring investigation</h1>' \
              "<p><span>FIRST</span> #{"Independently verified evidence remains material and complete. " * 8}</p>"
    later_article = article.sub('FIRST', 'LATER')

    with_url_page(
      'https://example.test/news/equal-scoring-investigation',
      "<article>#{article}</article><article>#{later_article}</article>"
    ) do |page|
      source_state = dom_state(page)
      page.add_script_tag(content: focal_ownership_source)
      result = page.evaluate('window.__fallbackContent()')

      expect(result.fetch('html')).to include('FIRST')
      expect(result.fetch('html')).not_to include('LATER')
      expect(dom_state(page)).to eq(source_state)
    end
  end

  it 'checks visible composed shadow content outside the focal article' do
    selection = focal_selection(
      'https://example.test/news/coastal-shadow-notice',
      <<~HTML
        <main>
          #{focal_article}
          <section class="related-stories"><h2>Reports</h2>#{rail_records}</section>
          <div><template shadowrootmode="open"><p>Emergency flood warning remains in effect.</p></template></div>
        </main>
      HTML
    )

    expect(selection).to be_nil
  end

  it 'checks visible assigned-slot content outside the focal article' do
    body = <<~HTML
      <main>
        #{focal_article}
        <section class="related-stories"><h2>Reports</h2>#{rail_records}</section>
        <div>
          <template shadowrootmode="open"><slot name="notice"></slot></template>
          <p slot="notice">Emergency flood warning remains in effect.</p>
        </div>
      </main>
    HTML
    selection = nil

    with_url_page(
      'https://example.test/news/coastal-slotted-notice',
      "<html><head><title>#{article_title}</title></head><body>#{body}</body></html>"
    ) do |page|
      source_state = dom_state(page)
      page.add_script_tag(content: focal_ownership_source)
      pruned_html = page.evaluate('window.__visibilityPrunedBodyHtml()')
      selection = page.evaluate('window.__broadMixedArticleFocal()?.id || null')

      expect(pruned_html).to include('Emergency flood warning remains in effect.')
      expect(dom_state(page)).to eq(source_state)
    end

    expect(selection).to be_nil
  end

  it 'selects the focal article for one proved related or complementary rail' do
    groups = {
      'named rail' => '<section class="related-stories">',
      'aside rail' => '<aside>',
      'complementary rail' => '<section role="complementary">'
    }

    groups.each_with_index do |(label, opening), index|
      selection = focal_selection(
        "https://example.test/news/coastal-related-#{index + 1}",
        "<main>#{focal_article}#{opening}<h2>Related reports</h2>#{rail_records}</#{opening.start_with?("<aside") ? "aside" : "section"}></main>"
      )

      expect(selection).to eq('focal'), label
    end
  end

  it 'accepts explicit semantic focal ownership on non-article-like routes' do
    shapes = {
      'main article' => focal_article(attributes: 'role="main"'),
      'schema body' => focal_article(tag: 'div', attributes: 'itemprop="articleBody"')
    }

    shapes.each_with_index do |(label, article), index|
      selection = focal_selection(
        "https://example.test/archive#{index + 1}",
        "<main>#{article}<aside><h2>Related reports</h2>#{rail_records}</aside></main>"
      )

      expect(selection).to eq('focal'), label
    end
  end
end
