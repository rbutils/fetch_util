# frozen_string_literal: true

RSpec.describe "FetchUtil navigation token scope" do
  include_context "extractor integration helpers"

  def navigation_source
    root = File.expand_path("../../..", __dir__)
    source = File.readlines(File.join(root, "websieve/manifest.txt"), chomp: true)
                 .reject { |line| line.empty? || line.start_with?("#") }
                 .map { |path| File.read(File.join(root, "websieve", path)) }.join("\n")
    source.sub("})(window);", <<~JAVASCRIPT)
      global.checkNavigation = listNavigationNode;
      global.checkNavigationItems = function() {
        return extractListItems(cleanupListRoot(visibleListClone(document.body))).map(function(item) { return item.text; });
      };
      })(window);
    JAVASCRIPT
  end

  it "distinguishes navigation tokens from presentation and infinite-scroll names" do
    with_url_page("https://research.example/", "<html><body></body></html>") do |page|
      page.add_script_tag(content: navigation_source)
      result = page.evaluate(<<~JAVASCRIPT)
        (() => {
          var classes = ['card card-navy', 'cardNavy', 'autopagerize_page_element', 'AutoPagerizePageElement',
            'nav', 'topnav', 'nav-link', 'navItems', 'navlinks', 'nav-container', 'navbar',
            'navbar-expand-xl', 'mainNavigation', 'navigation-menu', 'pager', 'pager-next', 'pagination'];
          return classes.map(function(name) {
            var node = document.createElement('div');
            node.className = name;
            return checkNavigation(node);
          }).concat(['nav', 'header', 'footer'].map(function(tag) {
            var node = document.createElement(tag);
            node.className = 'card-navy';
            return checkNavigation(node);
          }));
        })()
      JAVASCRIPT
      expect(result).to eq(Array.new(4, false) + Array.new(16, true))
    end
  end

  it "keeps every infinite-scroll record in a presentation-colored container" do
    records = (0...125).map do |index|
      "<section class='index_article_container'><h2><a href='/story/#{index}'>Independent news headline #{index}</a></h2>" \
        "<p>Local reporting and independently verified observations for this story.</p></section>"
    end.join
    html = "<html><body><div class='card-navy'><div class='autopagerize_page_element'>#{records}</div></div>" \
           "<div class='pager'><a href='/next'>Next page</a></div><nav><a href='/menu'>Navigation entry</a></nav></body></html>"
    with_url_page("https://research.example/", html) do |page|
      page.add_script_tag(content: navigation_source)
      expect(page.evaluate("checkNavigationItems()")).to eq((0...125).map { |index| "Independent news headline #{index}" })
    end
  end

  it "excludes named section-link navigation without matching similarly named stories" do
    records = (1..6).map do |index|
      "<article><h2><a href='/story/#{index}'>Independent regional report #{index}</a></h2>" \
        "<p>Verified local context #{index} remains with this report.</p></article>"
    end.join
    html = <<~HTML
      <html><body><main>
        #{records}
        <article class="named-section-links-story">
          <h2><a href="/story/7">Independent named section links investigation</a></h2>
          <p>Verified investigation context remains material.</p>
        </article>
        <article class="story-card named-section-links">
          <h2><a href="/story/8">Independent exact-token story report</a></h2>
          <p>Verified exact-token story context remains material.</p>
        </article>
        <article class="named-section-links__contenthash">
          <h2><a href="/story/9">Independent content hash report</a></h2>
          <p>Verified content hash context remains material.</p>
        </article>
        <article class="named-section-links__storyhash">
          <h2><a href="/story/10">Independent story hash report</a></h2>
          <p>Verified story hash context remains material.</p>
        </article>
        <div class="NamedSectionLinks_namedSectionLinks__IvyJA">
          <div class="NamedSectionLinks_title__xsDj_">More:</div>
          <div class="NamedSectionLinks_list__Wlbun">
            <a href="/desk/markets">Markets</a>
          </div>
        </div>
        <div class="named-section-links-menu">
          <a href="/desk/sport">Sport</a>
        </div>
        <div class="named-section-links--list">
          <a href="/desk/culture">Culture</a>
        </div>
      </main></body></html>
    HTML

    with_url_page("https://research.example/", html) do |page|
      page.add_script_tag(content: navigation_source)
      result = page.evaluate(<<~JAVASCRIPT)
        (() => {
          var before = document.documentElement.outerHTML;
          var classes = ['NamedSectionLinks_list__Wlbun', 'named-section-links', 'named_section_links',
            'named-section-links-menu', 'named-section-links--list',
            'NamedSectionLinks_namedSectionLinks__IvyJA', 'NamedSectionLinks_title__xsDj_',
            'named-section-links-wrapper', 'NamedSectionLinks_wrapper__Ab12',
            'NamedSectionLinks__Ab12', 'named-section-links-story',
            'named-section-links-more-story', 'named-section-links--list-story',
            'named-section-links-nav-story', 'unnamed-section-links', 'not-named-section-links',
            'promo_named-section-links', 'notNamedSectionLinks', 'promoNamedSectionLinks',
            'named-section-links--list__story', 'NamedSectionLinks_list__content',
            'NamedSectionLinks__record', 'story-card named-section-links',
            'named-section-links__contenthash', 'named-section-links__storyhash'];
          var navigation = classes.map(function(name) {
            var node = document.createElement('div');
            node.className = name;
            return checkNavigation(node);
          });
          var items = checkNavigationItems();
          return { navigation: navigation, items: items, unchanged: before === document.documentElement.outerHTML };
        })()
      JAVASCRIPT
      expect(result).to eq(
        "navigation" => Array.new(10, true) + Array.new(15, false),
        "items" => (1..6).map { |index| "Independent regional report #{index}" } +
          [
            "Independent named section links investigation",
            "Independent exact-token story report",
            "Independent content hash report",
            "Independent story hash report"
          ],
        "unchanged" => true
      )
    end

    with_url_page("https://research.example/", html) do |page|
      before = page.evaluate("document.body.outerHTML")
      result = extract_payload(page, reader_mode: false)
      expect(result["contentType"]).to eq("list")
      expect(result["hostAware"]).not_to be(true)
      expected_records = (1..6).map do |index|
        "- [Independent regional report #{index}](https://research.example/story/#{index})" \
          " - Verified local context #{index} remains with this report."
      end
      expected_records << "- [Independent named section links investigation](https://research.example/story/7)" \
                          " - Verified investigation context remains material."
      expected_records << "- [Independent exact-token story report](https://research.example/story/8)" \
                          " - Verified exact-token story context remains material."
      expected_records << "- [Independent content hash report](https://research.example/story/9)" \
                          " - Verified content hash context remains material."
      expected_records << "- [Independent story hash report](https://research.example/story/10)" \
                          " - Verified story hash context remains material."
      records = result["markdown"].lines.grep(/\A- \[Independent /).map(&:chomp)
      expect(records).to eq(expected_records)
      (1..10).each do |index|
        expect(result["markdown"].scan("](https://research.example/story/#{index})").length).to eq(1)
      end
      expect(result["markdown"]).not_to include("More:", "/desk/markets", "/desk/sport", "/desk/culture")
      expect(page.evaluate("document.body.outerHTML")).to eq(before)
    end
  end

  it "retains cloned document records when global layout state mentions navigation" do
    titles = (1..12).map { |index| "Independent regional dispatch #{index}" }
    records = titles.each_with_index.map do |title, index|
      "<a href='/report/#{index}'><h2>#{title}</h2><p>Verified details of this local report.</p></a>"
    end.join
    html = "<html class='navigation-open'><body class='header-static header-big sidebar-visible'>#{records}" \
           "<nav><a href='/menu'>Main navigation links</a></nav>" \
           "<div role='navigation'><a href='/topics'>All available topics</a></div></body></html>"

    with_url_page("https://research.example/", html) do |page|
      page.add_script_tag(content: navigation_source)
      expect(page.evaluate("checkNavigation(document.body)")).to be(false)
      expect(page.evaluate("checkNavigation(document.documentElement)")).to be(false)
      expect(page.evaluate("checkNavigationItems()")).to eq(titles)
    end
  end
end
