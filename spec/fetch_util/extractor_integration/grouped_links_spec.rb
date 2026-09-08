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
      "items: extractFallbackHeadlineItems, clone: visibleListClone, render: listMarkdown }; })(window);"
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
          return api.render(api.items(api.clone(document.querySelector('main'))));
        })()
      JAVASCRIPT
      expect(markdown.lines.map(&:strip)).to eq(
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
end
