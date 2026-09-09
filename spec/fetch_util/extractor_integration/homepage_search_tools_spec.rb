require "support/extractor_integration_helpers"

RSpec.describe FetchUtil::Extractor do
  include_context "extractor integration helpers"

  def search_tools_source
    root = File.expand_path("../../..", __dir__)
    source = File.readlines("#{root}/websieve/manifest.txt").map(&:strip)
                 .reject { |path| path.empty? || path.start_with?("#") }
                 .map { |path| File.read("#{root}/websieve/#{path}") }.join("\n")
    source.sub("})(window);", "global.__searchTools = homepageSearchToolsMarkdown; })(window);")
  end

  it "preserves all homepage search tools before the selected material without promoting a header profile" do
    links = 125.times.map { |index| "<a href='/search/#{index}'>Research tool #{index}</a>" }.join
    html = <<~HTML
      <html><body><div id="header"><div id="menu-container-generated">
      <table><tr><td><input placeholder="Enter search terms"></td></tr><tr><td>#{links}</td></tr></table>
      </div></div><main><a href="/news/one">Independent research bulletin</a></main></body></html>
    HTML
    with_url_page("https://research.example/", html) do |page|
      page.add_script_tag(content: search_tools_source)
      actual = page.evaluate(<<~JS)
        __searchTools({ contentType: 'list', listExtraction: { items: [{ url: 'https://research.example/news/one' }] } }, 'Original material')
      JS
      tools = 125.times.map { |index| "- [Research tool #{index}](https://research.example/search/#{index})" }
      expect(actual).to eq("#{tools.join("\n")}\n\nOriginal material")
    end
  end

  it "rejects real chrome, hidden controls, unsafe links and partial or later groups" do
    with_url_page("https://research.example/", "<html><body></body></html>") do |page|
      page.add_script_tag(content: search_tools_source)
      actual = page.evaluate(<<~JS)
        (() => {
          const table = '<table><tr><td><input type="search"><a href="/search/one">First search tool</a>' +
            '<a href="/search/two">Second search tool</a></td></tr></table>';
          const record = '<main><a href="/news/one">Independent research bulletin</a></main>';
          const cases = [
            '<nav>' + table + '</nav>' + record,
            '<header>' + table + '</header>' + record,
            '<form>' + table + '</form>' + record,
            '<div role="toolbar">' + table + '</div>' + record,
            table.replace('<table>', '<table hidden>') + record,
            table.replace('type="search"', 'type="search" hidden') + record,
            table.replace('/search/two', 'https://user:secret@example.net/private') + record,
            table.replace('/search/two', 'javascript:void(0)') + record,
            table.replace('/search/two', '/login') + record,
            table.replace('type="search"', 'type="text" placeholder="Account identifier"') + record,
            record + table,
            '<p>Opening explanation before the search tools.</p>' + table + record,
            '<h1>Page heading before the search tools</h1>' + table + record,
            table.replace('/search/two', '/news/one') + record,
            table.replace('/search/two', '/search/one') + record
          ];
          return cases.map(html => {
            document.body.innerHTML = html;
            return __searchTools({ contentType: 'list', listSourceItems: [{ url: 'https://research.example/news/one' }] }, 'Original');
          });
        })()
      JS
      expect(actual).to eq(Array.new(15, ""))
    end
  end

  it "completes a validated tool group when consecutive peers are already represented" do
    html = <<~HTML
      <html><body><table><tr><td><input type="search"></td></tr><tr><td>
      <a href="/search/one">First research tool</a>
      <a href="/search/two">Second research tool</a>
      <a href="/search/three">Third research tool</a>
      </td><td><a href="/help/search">Search help</a></td></tr></table>
      <main><a href="/news/one">Independent research bulletin</a></main></body></html>
    HTML
    with_url_page("https://research.example/", html) do |page|
      page.add_script_tag(content: search_tools_source)
      actual = page.evaluate(<<~JS)
        __searchTools({ contentType: 'list', listSourceItems: [
          { url: 'https://research.example/search/one' },
          { url: 'https://research.example/search/two' },
          { url: 'https://research.example/search/three' },
          { url: 'https://research.example/news/one' }
        ] }, [
          '- [First research tool](https://research.example/search/one)',
          '- [Second research tool](https://research.example/search/two)',
          '- [Third research tool](https://research.example/search/three)',
          '- [Independent research bulletin](https://research.example/news/one)'
        ].join('\\n'))
      JS
      expect(actual).to eq(<<~MARKDOWN.chomp)
        - [First research tool](https://research.example/search/one)
        - [Second research tool](https://research.example/search/two)
        - [Third research tool](https://research.example/search/three)
        - [Search help](https://research.example/help/search)
        - [Independent research bulletin](https://research.example/news/one)
      MARKDOWN
    end
  end

  it "leaves non-homepage and non-list content unchanged" do
    html = <<~HTML
      <html><body><table><tr><td><input type="search">
      <a href="/search/one">First research tool</a><a href="/search/two">Second research tool</a>
      </td></tr></table><main><a href="/news/one">Independent research bulletin</a></main></body></html>
    HTML
    with_url_page("https://research.example/news/entry", html) do |page|
      page.add_script_tag(content: search_tools_source)
      actual = page.evaluate(<<~JS)
        __searchTools({ contentType: 'list', listSourceItems: [{ url: 'https://research.example/news/one' }] }, 'Original')
      JS
      expect(actual).to eq("")
    end
    with_url_page("https://research.example/", html) do |page|
      page.add_script_tag(content: search_tools_source)
      actual = page.evaluate(<<~JS)
        [{ contentType: 'article' }, { contentType: 'list', hostAware: true },
         { contentType: 'list', docsLike: true }, { contentType: 'list', legalProvision: true }].map(content =>
          __searchTools(Object.assign({ listSourceItems: [{ url: 'https://research.example/news/one' }] }, content), 'Original'))
      JS
      expect(actual).to eq(Array.new(4, ""))
    end
  end
end
