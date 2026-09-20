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
        global.__leadVisibleClone = visibilityPrunedClone;
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

  it "supplements a body lead from its mapped main list source" do
    html = <<~HTML
      <html><body><header><a href="/account">Account</a></header><main>
        <p>Visible financing terms owned by the main collection.</p>
        <article><a href="/one">First service</a></article>
        <article><a href="/two">Second service</a></article>
        <article><a href="/three">Third service</a></article>
      </main></body></html>
    HTML
    with_url_page("https://services.example/", html) do |page|
      page.add_script_tag(content: lead_coverage_source)
      result = page.evaluate(<<~JS)
        (() => {
          const root = __leadVisibleClone(document.body, document);
          const sourceMain = document.querySelector('main');
          const links = Array.from(root.querySelectorAll('main a'));
          const items = links.map(link => ({ text: link.textContent, url: link.href,
            sourceNode: link, card: link.parentElement }));
          const leadItems = Array.from(sourceMain.querySelectorAll('a')).slice(0, 2).map(link => ({
            text: link.textContent, url: link.href, sourceNode: link, card: link.parentElement
          }));
          return __leadCoverage({ root: document.body, items: leadItems }, { listExtraction: {
            sourceNode: sourceMain, root, items
          } });
        })()
      JS
      expect(result.fetch("markdown")).to start_with("Visible financing terms owned by the main collection.")
      expect(result.fetch("items").map { |item| item.fetch("url") }).to eq(
        %w[https://services.example/one https://services.example/two https://services.example/three]
      )
      expect(result.fetch("markdown")).not_to include("Account")
    end
  end

  it "rejects a body lead with a record outside the mapped list source" do
    html = <<~HTML
      <html><body><main>
        <p>Main collection context.</p>
        <article><a href="/one">First service</a></article>
        <article><a href="/two">Second service</a></article>
      </main><aside><a href="/outside">Outside promotion</a></aside></body></html>
    HTML
    with_url_page("https://services.example/", html) do |page|
      page.add_script_tag(content: lead_coverage_source)
      result = page.evaluate(<<~JS)
        (() => {
          const root = __leadVisibleClone(document.body, document);
          const sourceMain = document.querySelector('main');
          const links = Array.from(root.querySelectorAll('main a'));
          const items = links.map(link => ({ text: link.textContent, url: link.href,
            sourceNode: link, card: link.parentElement }));
          const first = sourceMain.querySelector('a[href="/one"]');
          const outside = document.querySelector('aside a');
          return __leadCoverage({ root: document.body, items: [
            { text: 'First service', url: first.href, sourceNode: first, card: first.parentElement },
            { text: 'Outside promotion', url: outside.href, sourceNode: outside, card: outside.parentElement }
          ] }, { listExtraction: { sourceNode: sourceMain, root, items } });
        })()
      JS
      expect(result).to be_nil
    end
  end

  it "rejects an unrelated narrower source inside the same lead root" do
    html = <<~HTML
      <html><body><main>
        <article><a href="/one">First service</a></article>
        <article><a href="/two">Second service</a></article>
      </main><section id="unrelated"><p>Unrelated section context.</p></section></body></html>
    HTML
    with_url_page("https://services.example/", html) do |page|
      page.add_script_tag(content: lead_coverage_source)
      result = page.evaluate(<<~JS)
        (() => {
          const root = __leadVisibleClone(document.body, document);
          const sourceMain = document.querySelector('main');
          const links = Array.from(root.querySelectorAll('main a'));
          const items = links.map(link => ({ text: link.textContent, url: link.href,
            sourceNode: link, card: link.parentElement }));
          const leadItems = Array.from(sourceMain.querySelectorAll('a')).map(link => ({
            text: link.textContent, url: link.href, sourceNode: link, card: link.parentElement
          }));
          return __leadCoverage({ root: document.body, items: leadItems }, { listExtraction: {
            sourceNode: document.querySelector('#unrelated'), root, items
          } });
        })()
      JS
      expect(result).to be_nil
    end
  end

  it "fails closed when cleaned records cannot map uniquely or preserve source order" do
    html = <<~HTML
      <html><body><main>
        <p>Visible collection context.</p>
        <article><a href="/one">First service</a></article>
        <article><a href="/two">Second service</a></article>
        <article><a href="/three">Third service</a></article>
      </main></body></html>
    HTML
    with_url_page("https://services.example/", html) do |page|
      page.add_script_tag(content: lead_coverage_source)
      result = page.evaluate(<<~JS)
        (() => {
          const sourceMain = document.querySelector('main');
          const leadItems = Array.from(sourceMain.querySelectorAll('a')).slice(0, 2).map(link => ({
            text: link.textContent, url: link.href, sourceNode: link, card: link.parentElement
          }));
          const extraction = () => {
            const root = __leadVisibleClone(sourceMain, document);
            const items = Array.from(root.querySelectorAll('a')).map(link => ({
              text: link.textContent, url: link.href, sourceNode: link, card: link.parentElement
            }));
            return { root, items };
          };

          const missing = extraction();
          missing.items[2].text = 'Unmapped replacement';
          const reordered = extraction();
          reordered.items.reverse();
          const injected = extraction();
          const paragraph = injected.root.querySelector('p');
          paragraph.textContent = 'Clone-only collection context.';

          return [missing, reordered, injected].map(candidate => __leadCoverage(
            { root: document.body, items: leadItems },
            { listExtraction: { sourceNode: sourceMain, root: candidate.root, items: candidate.items } }
          ) === null);
        })()
      JS
      expect(result).to eq([true, true, true])
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
    html = "<html><body><p>Ambient body prose.</p><div id='wrapper'><main><section>" \
           "<p>Visible lead-root prose.</p><p hidden>Hidden lead-root prose.</p>" \
           "<div class='card'><p>Generic card detail.</p><section><p>Nested card section detail.</p></section></div>" \
           "</section></main></div><section></section></body></html>"
    with_url_page("https://services.example/", html) do |page|
      page.add_script_tag(content: lead_coverage_source)
      result = page.evaluate(<<~JS)
        (() => {
          const leadRoot = document.body;
          const otherRoot = document.querySelector('body > section');
          const mainRoot = document.querySelector('main');
          const wrapper = document.querySelector('#wrapper');
          const description = '[Research organization](https://services.example/about) supports discovery.';
          const content = { listExtraction: { ancestorDescription: description,
            ancestorDescriptionSourceNode: leadRoot } };
          const nested = (source, text) => ({ listExtraction: { ancestorDescription: text,
            ancestorDescriptionSourceNode: source } });
          return [
            __leadAncestorDescription({ root: leadRoot }, content, { excerpt: 'A metadata summary.' }),
            __leadAncestorDescription({ root: otherRoot }, content, { excerpt: 'A metadata summary.' }),
            __leadAncestorDescription({ root: leadRoot }, content, { excerpt: description }),
            __leadAncestorDescription({ root: mainRoot }, nested(leadRoot, 'Visible lead-root prose.'), {}),
            __leadAncestorDescription({ root: mainRoot }, nested(leadRoot, 'Ambient body prose.'), {}),
            __leadAncestorDescription({ root: mainRoot }, nested(leadRoot, 'Hidden lead-root prose.'), {}),
            __leadAncestorDescription({ root: mainRoot }, nested(leadRoot, 'Generic card detail.'), {}),
            __leadAncestorDescription({ root: mainRoot }, nested(leadRoot, 'Nested card section detail.'), {}),
            __leadAncestorDescription({ root: mainRoot }, nested(wrapper, 'Visible lead-root prose.'), {}),
            __leadAncestorDescription({ root: mainRoot }, nested(leadRoot, '[Visible lead-root prose.][ref]'), {})
          ];
        })()
      JS
      expected = ["[Research organization](https://services.example/about) supports discovery.", "", "",
                  "Visible lead-root prose.", "", "", "", "", "", ""]
      expect(result).to eq(expected)
    end
  end
end
