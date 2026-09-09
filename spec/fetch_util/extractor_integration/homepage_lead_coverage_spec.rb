require "support/extractor_integration_helpers"

RSpec.describe FetchUtil::Extractor do
  include_context "extractor integration helpers"

  def lead_coverage_source
    root = File.expand_path("../../..", __dir__)
    source = File.readlines("#{root}/websieve/manifest.txt").map(&:strip)
                 .reject { |path| path.empty? || path.start_with?("#") }
                 .map { |path| File.read("#{root}/websieve/#{path}") }.join("\n")
    source.sub("})(window);", <<~JS)
      global.__leadCoverage = supplementedHomepageLead;
      global.__leadAncestorDescription = homepageLeadAncestorDescription;
    })(window);
    JS
  end

  it "retains every lead detail and adds short independently owned actions and prose in DOM order" do
    actions = 125.times.map { |index| "<div class='action'><a href='/demo/#{index}'>Try #{index}</a></div>" }.join
    html = <<~HTML
      <html><body><main><p>Opening explanation that must precede every action.</p>#{actions}
      <article><h2><a href="/story">Independent customer story</a></h2><p>Locally owned story explanation.</p></article>
      <p>Closing explanation that must follow the customer story.</p><p hidden>Hidden explanation is excluded.</p>
      </main></body></html>
    HTML
    with_url_page("https://services.example/", html) do |page|
      page.add_script_tag(content: lead_coverage_source)
      result = page.evaluate(<<~JS)
        (() => {
          const root = document.querySelector('main');
          const items = Array.from(root.querySelectorAll('a')).map(link => ({ text: link.textContent,
            url: link.href, card: link.closest('article, .action'), sourceNode: link }));
          return __leadCoverage({ root, items: [{ text: 'Independent customer story',
            url: 'https://services.example/story', detail: 'Locally owned story explanation.' }] },
            { listExtraction: { sourceNode: root, root, items } });
        })()
      JS
      expected = ["Opening explanation that must precede every action.",
                  125.times.map { |index| "- [Try #{index}](https://services.example/demo/#{index})" }.join("\n"),
                  "- [Independent customer story](https://services.example/story) - Locally owned story explanation.",
                  "Closing explanation that must follow the customer story."]
      expected.each { |part| expect(result.fetch("markdown")).to include(part) }
      expect(result.fetch("items").map { |item| item.fetch("url") }).to eq(
        125.times.map { |index| "https://services.example/demo/#{index}" } + ["https://services.example/story"]
      )
      expect(result.fetch("markdown")).not_to include("Hidden explanation")
      expect(result.fetch("markdown").scan("Locally owned story explanation.").length).to eq(1)
      expect(result.fetch("markdown").scan("Independent customer story").length).to eq(1)
      expect(result.fetch("markdown")).to start_with("#{expected.first}\n\n")
      expect(result.fetch("markdown")).to end_with(expected.last)
    end
  end

  it "rejects different roots, ambiguous leads and shared or unsafe additional owners" do
    with_url_page("https://services.example/", "<html><body><main></main></body></html>") do |page|
      page.add_script_tag(content: lead_coverage_source)
      result = page.evaluate(<<~JS)
        (() => {
          const root = document.querySelector('main');
          const html = '<p>Independent opening explanation remains visible.</p>' +
            '<article><a href="/story">Customer story</a></article>' +
            '<div class="action"><a href="/demo">Try it</a></div>';
          return ['other-root', 'ambiguous', 'shared', 'unsafe', 'missing'].map(kind => {
            root.innerHTML = html;
            if (kind === 'ambiguous') root.innerHTML += '<a href="/story">Customer story</a>';
            if (kind === 'shared') root.querySelector('.action').innerHTML += '<a href="/other">Another action</a>';
            if (kind === 'unsafe') root.querySelector('.action').innerHTML += '<a href="javascript:void(0)">Unsafe action</a>';
            const link = root.querySelector('.action a');
            return __leadCoverage({ root, items: [{ text: kind === 'missing' ? 'Unknown story' : 'Customer story',
              url: 'https://services.example/story', detail: 'Own detail.' }] }, { listExtraction: {
                sourceNode: kind === 'other-root' ? document.body : root, root,
                items: [{ text: 'Try it', url: link.href, sourceNode: link, card: link.parentElement }]
              } }) === null;
          });
        })()
      JS
      expect(result).to eq(Array.new(5, true))
    end
  end

  it "retains a distinct visible description from the exact lead ancestor" do
    with_url_page("https://services.example/", "<html><body><main></main><section></section></body></html>") do |page|
      page.add_script_tag(content: lead_coverage_source)
      result = page.evaluate(<<~JS)
        (() => {
          const leadRoot = document.body;
          const otherRoot = document.querySelector('section');
          const description = '[Research organization](https://services.example/about) supports discovery.';
          const content = { listExtraction: { ancestorDescription: description,
            ancestorDescriptionSourceNode: leadRoot } };
          return [
            __leadAncestorDescription({ root: leadRoot }, content, { excerpt: 'A metadata summary.' }),
            __leadAncestorDescription({ root: otherRoot }, content, { excerpt: 'A metadata summary.' }),
            __leadAncestorDescription({ root: leadRoot }, content, { excerpt: description })
          ];
        })()
      JS
      expect(result).to eq([
        "[Research organization](https://services.example/about) supports discovery.", "", ""
      ])
    end
  end
end
