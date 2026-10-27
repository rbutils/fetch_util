# frozen_string_literal: true

require 'open3'

RSpec.describe "FetchUtil extractor integration - direct prose cards" do
  include_context "extractor integration helpers"

  def direct_prose_card_source
    root = File.expand_path("../../..", __dir__)
    source = File.readlines(File.join(root, "websieve/manifest.txt"), chomp: true).reject(&:empty?).map do |entry|
      File.read(File.join(root, "websieve", entry))
    end.join("\n")
    source.sub(
      "})(window);",
      "global.FetchUtilDirectProseTest = { direct: genericListDirectAnchorCard, " \
      "items: extractListItems, clone: visibleListClone, render: listMarkdown }; })(window);"
    )
  end

  it "keeps every prose-only sibling record and its own complete details" do
    names = %w[Furniture Consumer Industrial Analytics Consulting Enterprise]
    cards = names.each_with_index.map do |name, index|
      <<~HTML
        <a href="/solutions/#{index}">
          <div><h2>#{name}</h2></div>
          <div><p>#{name} helps its own customers build reliable workflows and prepare accurate estimates.</p></div>
          <p>Its distinct capability number #{index} connects the approved design to production.</p>
        </a>
      HTML
    end.join
    html = <<~HTML
      <html><head><title>Industry solutions</title></head><body>
        <main><h1>Industry solutions</h1><div>#{cards}</div></main>
      </body></html>
    HTML

    with_url_page("https://solutions.example/categories", html) do |page|
      before = page.evaluate('document.body.outerHTML')
      inject_standalone_extractor(page)
      page.add_script_tag(content: direct_prose_card_source)
      payload = page.evaluate(<<~JAVASCRIPT)
        (() => {
          const api = FetchUtilDirectProseTest;
          const items = api.items(api.clone(document.querySelector('main')));
          return { localCards: items.every(item => item.card.matches('a[href]')), markdown: api.render(items) };
        })()
      JAVASCRIPT
      markdown = payload.fetch("markdown")
      expect(payload["localCards"]).to be(true)
      expect(markdown.scan(%r{https://solutions.example/solutions/\d})).to eq(
        names.each_index.map { |index| "https://solutions.example/solutions/#{index}" }
      )
      parser = 'import sys; from markdown_it import MarkdownIt; print(MarkdownIt("commonmark").enable("table").render(sys.stdin.read()))'
      parsed, error, status = Open3.capture3('python3', '-c', parser, stdin_data: markdown)
      raise "independent CommonMark parser failed: #{error}" unless status.success?

      document = Nokogiri::HTML.fragment(parsed)
      expect(document.css('h2').map(&:text)).to eq(names)
      expect(document.css('a[href]').map { |link| link['href'] }).to eq(
        names.each_index.map { |index| "https://solutions.example/solutions/#{index}" }
      )
      paragraphs = names.each_with_index.flat_map do |name, index|
        [
          "#{name} helps its own customers build reliable workflows and prepare accurate estimates.",
          "Its distinct capability number #{index} connects the approved design to production."
        ]
      end
      expect(document.css('p').map(&:text)).to eq(paragraphs)
      names.each_with_index do |name, index|
        expect(document.text).to include(
          "#{name} helps its own customers build reliable workflows and prepare accurate estimates.",
          "Its distinct capability number #{index} connects the approved design to production."
        )
        expect(document.text.scan("#{name} helps its own customers").length).to eq(1)
        expect(markdown.scan("#{name} helps its own customers").length).to eq(1)
      end
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
    end
  end

  it "requires both a local heading and paragraph when ordinary links lack record evidence" do
    with_url_page("https://solutions.example/industries", "<html><body><main></main></body></html>") do |page|
      page.add_script_tag(content: direct_prose_card_source)
      results = page.evaluate(<<~JAVASCRIPT)
        (() => {
          const examples = [
            '<a href="/a"><h2>First topic</h2></a><a href="/b"><h2>Other topic</h2></a>',
            '<a href="/a"><p>First ordinary paragraph</p></a><a href="/b"><p>Other ordinary paragraph</p></a>',
            '<h2>Shared heading</h2><a href="/a"><p>First paragraph</p></a><a href="/b"><p>Other paragraph</p></a>',
            '<a href="/a"><h2>First topic</h2><p>Local prose</p></a><a href="javascript:void(0)"><h2>Unsafe peer</h2><p>Other prose</p></a>',
            '<a href="/a"><h2>First topic</h2><p>Local prose</p></a><a href="https://user:secret@example.net/b"><h2>Credential peer</h2><p>Other prose</p></a>',
            '<a href="/a"><h2>First topic</h2><p>Local prose</p></a><a href="/b"><h2>Second topic</h2></a>',
            '<a href="/a"><h2>First topic</h2><p>Local prose</p></a><a href="/b"><h2>Second topic</h2><p>Other prose</p></a>',
            '<a href="/a"><h2>First topic</h2><p>Local prose</p></a><a href="/b"><img alt="Image record"></a>',
            '<a href="/a"><h2>First topic</h2><p> </p></a><a href="/b"><h2>Second topic</h2><p>Other prose</p></a>',
            '<a href="/a"><h2> </h2><p>Local prose</p></a><a href="/b"><h2>Second topic</h2><p>Other prose</p></a>',
            '<a href="/a"><h2>First topic</h2><p></p><p>Local prose</p></a><a href="/b"><h2>Second topic</h2><p>Other prose</p></a>'
          ];
          return examples.map(html => {
            const root = document.createElement('div');
            root.innerHTML = html;
            return FetchUtilDirectProseTest.direct(root.querySelector('a'), root);
          });
        })()
      JAVASCRIPT
      expect(results).to eq([false, false, false, false, false, false, true, true, false, false, true])
    end
  end
end
