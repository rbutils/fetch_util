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
end
