# frozen_string_literal: true

RSpec.describe "FetchUtil extractor integration - grouped links" do
  include_context "extractor integration helpers"

  def grouped_links_source
    root = File.expand_path("../../..", __dir__)
    source = File.readlines(File.join(root, "websieve/manifest.txt"), chomp: true).reject(&:empty?).map do |entry|
      File.read(File.join(root, "websieve", entry))
    end.join("\n")
    source.sub(
      "})(window);",
      "global.FetchUtilGroupTest = { group: genericListLinkGroup, " \
      "items: extractFallbackHeadlineItems, flat: extractListItems, clone: visibleListClone, render: listMarkdown }; })(window);"
    )
  end

  def grouped_links_html(extra = "")
    <<~HTML
      <html><head><title>Public services</title></head><body><main><section>
        <h1>Public services</h1><div class="card-grid">
          <div class="topic"><div class="topic-title">Living here</div>
            <p><a href="/energy">Energy</a><br><a href="/housing">Housing assistance</a>
            <br><a href="/energy">Power</a></p>#{extra}</div>
          <div class="topic"><div class="topic-title">Government</div>
            <p><a href="/about-region">About NSW</a><br><a href="/funding">Grants and funding</a></p></div>
        </div>
      </section></main></body></html>
    HTML
  end

  it "preserves short labels and aliases in DOM order with only their own group context" do
    with_url_page("https://services.example/topics", grouped_links_html) do |page|
      page.add_script_tag(content: grouped_links_source)
      markdown = page.evaluate(<<~JAVASCRIPT)
        (() => {
          const api = FetchUtilGroupTest;
          const root = api.clone(document.querySelector('main'));
          return {flat: api.render(api.flat(root)), fallback: api.render(api.items(root))};
        })()
      JAVASCRIPT
      expect(markdown.fetch("flat")).to eq(markdown.fetch("fallback"))
      expect(markdown.fetch("flat").lines.map(&:strip)).to eq(
        [
          "- [Energy](https://services.example/energy) - Living here",
          "- [Housing assistance](https://services.example/housing) - Living here",
          "- [Power](https://services.example/energy) - Living here",
          "- [About NSW](https://services.example/about-region) - Government",
          "- [Grants and funding](https://services.example/funding) - Government"
        ]
      )
    end
  end

  it "does not use shared prose, nested groups, navigation or unsafe peers as group evidence" do
    with_url_page("https://services.example/topics", grouped_links_html) do |page|
      page.add_script_tag(content: grouped_links_source)
      results = page.evaluate(<<~JAVASCRIPT)
        (() => {
          const original = document.querySelector('section').innerHTML;
          const mutations = [
            root => root.querySelector('.topic').insertAdjacentHTML('beforeend', '<p>Shared substantive explanation.</p>'),
            root => root.querySelector('.topic').insertAdjacentHTML('beforeend', '<div><h3>Nested group</h3><a href="/nested">Nested topic</a></div>'),
            root => root.setAttribute('role', 'navigation'),
            root => root.querySelector('a[href="/funding"]').setAttribute('href', 'javascript:void(0)'),
            root => root.querySelector('a[href="/funding"]').setAttribute('href', 'https://user:secret@example.net/funding'),
            root => root.querySelector('a[href="/funding"]').setAttribute('hidden', ''),
            root => root.querySelector('a[href="/funding"]').style.display = 'none'
          ];
          return mutations.map(mutate => {
            const root = document.querySelector('section');
            root.innerHTML = original;
            root.removeAttribute('role');
            mutate(root);
            return !!FetchUtilGroupTest.group(root.querySelector('a'));
          });
        })()
      JAVASCRIPT
      expect(results).to eq([false, false, false, false, false, false, false])
    end
  end

  it "keeps hidden labels and non-HTTP or credential-bearing destinations out of grouped output" do
    extra = <<~HTML
      <a hidden href="/hidden">Hidden label</a>
      <a href="javascript:void(0)">Unsafe action</a>
      <a href="https://user:secret@example.net/private">Private action</a>
    HTML
    with_url_page("https://services.example/topics", grouped_links_html(extra)) do |page|
      page.add_script_tag(content: grouped_links_source)
      markdown = page.evaluate(<<~JAVASCRIPT)
        (() => {
          const api = FetchUtilGroupTest;
          return api.render(api.items(api.clone(document.querySelector('main'))));
        })()
      JAVASCRIPT
      expect(markdown).to include("[Energy]", "[About NSW]")
      expect(markdown).not_to include("Hidden label", "javascript:", "user:secret", "example.net/private")
    end
  end

  it "does not downgrade independently described or metadata-bearing anchors to plain grouped links" do
    with_url_page("https://services.example/topics", grouped_links_html) do |page|
      page.add_script_tag(content: grouped_links_source)
      results = page.evaluate(<<~JAVASCRIPT)
        (() => {
          const root = document.querySelector('section');
          const original = root.innerHTML;
          root.querySelector('a').innerHTML = '<h3>Energy options</h3><p>A local service explanation.</p>';
          const prose = !!FetchUtilGroupTest.group(root.querySelector('a'));
          root.innerHTML = original;
          root.querySelector('a[href="/funding"]').innerHTML =
            '<span>Grants and funding</span><time datetime="2026-09-01">September 1</time>';
          return [prose, !!FetchUtilGroupTest.group(root.querySelector('a'))];
        })()
      JAVASCRIPT
      expect(results).to eq([false, false])
    end
  end

  it "does not cap material entries in a qualified group" do
    with_url_page("https://services.example/topics", grouped_links_html) do |page|
      page.add_script_tag(content: grouped_links_source)
      lines = page.evaluate(<<~JAVASCRIPT)
        (() => {
          const api = FetchUtilGroupTest;
          const group = document.querySelector('.topic p');
          group.innerHTML = Array.from({length: 125}, (_, index) =>
            `<a href="/record/${index}">ID ${index}</a>`).join('<br>');
          return api.render(api.items(api.clone(document.querySelector('main')))).split(String.fromCharCode(10));
        })()
      JAVASCRIPT
      expect(lines.first(125)).to eq(
        (0...125).map { |index| "- [ID #{index}](https://services.example/record/#{index}) - Living here" }
      )
      expect(lines.length).to eq(127)
    end
  end

  it "keeps uncapped short plain-link groups without treating their sibling labels as descriptions" do
    links = (0...125).map { |index| "<a href='/genre/#{index}'>G #{index}</a><br>" }.join
    html = "<html><body><div class='mainContent'><h1>Browse genres</h1><div>#{links}</div></div></body></html>"
    with_url_page("https://services.example/", html) do |page|
      page.add_script_tag(content: grouped_links_source)
      markdown = page.evaluate(<<~JAVASCRIPT)
        (() => {
          const api = FetchUtilGroupTest;
          return api.render(api.flat(api.clone(document.body)));
        })()
      JAVASCRIPT
      expect(markdown.lines.map(&:strip)).to eq(
        (0...125).map { |index| "- [G #{index}](https://services.example/genre/#{index})" }
      )
    end
  end

  it "does not use semantic navigation or independently described records as plain-link groups" do
    with_url_page("https://services.example/", "<html><body><div id='root'></div></body></html>") do |page|
      page.add_script_tag(content: grouped_links_source)
      results = page.evaluate(<<~JAVASCRIPT)
        (() => {
          const root = document.querySelector('#root');
          const links = '<a href="/music">Music</a><a href="/art">Art</a>';
          const cases = [
            '<nav><li>' + links + '</li></nav>',
            '<footer><div>' + links + '</div></footer>',
            '<div role="navigation"><article>' + links + '</article></div>',
            '<menu><li>' + links + '</li></menu>',
            '<div role="toolbar"><li>' + links + '</li></div>',
            '<div>' + links + '<p>Local explanatory material.</p></div>',
            '<div><a href="/music"><h2>Music</h2><p>Own description.</p></a><a href="/art">Art</a></div>',
            '<div><a href="/music">Music</a><a hidden href="/art">Art</a></div>',
            '<div><a href="/music">Music</a><a href="https://user:secret@example.net/art">Art</a></div>',
            '<div>' + links + '<a href="tel:18001234567">18001234567</a></div>'
          ];
          return cases.map(html => {
            root.innerHTML = html;
            return !!FetchUtilGroupTest.group(root.querySelector('a'));
          });
        })()
      JAVASCRIPT
      expect(results).to eq(Array.new(10, false))
    end
  end

  it "keeps short-link columns when their shared wrapper also looks link-dense" do
    labels = %w[Music Art Sports Fiction Romance Ebooks History Drama]
    columns = labels.each_slice(4).map do |column|
      "<div>#{column.map { |label| "<a href='/#{label.downcase}'>#{label}</a><br>" }.join}</div>"
    end.join
    html = "<html><body><div class='mainContent'><h1>Browse</h1><div>#{columns}</div></div></body></html>"
    with_url_page("https://services.example/", html) do |page|
      page.add_script_tag(content: grouped_links_source)
      markdown = page.evaluate("FetchUtilGroupTest.render(FetchUtilGroupTest.flat(FetchUtilGroupTest.clone(document.body)))")
      expect(markdown.lines.map(&:strip)).to eq(
        labels.map { |label| "- [#{label}](https://services.example/#{label.downcase})" }
      )
    end
  end

  it "retains independently accepted short headings alongside an already populated flat collection" do
    records = (0...125).map do |index|
      "<article><h2><a href='/record/#{index}'>Detailed record number #{index}</a></h2><p>Own detail #{index}.</p></article>"
    end.join
    html = "<html><body><main><h1>Records</h1><h2><a href='/cost-of-living'>Cost of living</a></h2>#{records}</main></body></html>"
    with_url_page("https://services.example/", html) do |page|
      page.add_script_tag(content: grouped_links_source)
      result = page.evaluate(<<~JAVASCRIPT)
        (() => {
          const api = FetchUtilGroupTest;
          const items = api.flat(api.clone(document.querySelector('main')));
          return {urls: items.map(item => item.url), markdown: api.render(items)};
        })()
      JAVASCRIPT
      expect(result.fetch("urls")).to eq(
        ["https://services.example/cost-of-living"] + (0...125).map { |index| "https://services.example/record/#{index}" }
      )
      (0...125).each { |index| expect(result.fetch("markdown")).to include("Own detail #{index}.") }
    end
  end
end
