# frozen_string_literal: true

require "spec_helper"
require "support/extractor_integration_helpers"

RSpec.describe FetchUtil::Extractor, "rendered component content" do
  include_context "extractor integration helpers"

  it "preserves nested component headlines and slotted descriptions without constructing new live components" do
    html = "<html><head><title>Harbour Daily</title></head><body><daily-page></daily-page></body></html>"
    with_url_page("https://bulletin.example/", html) do |page|
      page.evaluate(<<~JS)
        (() => {
          window.componentConstructions = 0;
          window.componentConstructionStacks = [];
          customElements.define('daily-story', class extends HTMLElement {
            constructor() {
              super(); window.componentConstructions++;
              window.componentConstructionStacks.push(new Error().stack);
              this.attachShadow({mode: 'open'}).innerHTML = '<article><slot></slot></article>';
            }
          });
          customElements.define('daily-page', class extends HTMLElement {
            constructor() {
              super(); window.componentConstructions++;
              window.componentConstructionStacks.push(new Error().stack);
              this.attachShadow({mode: 'open'}).innerHTML = '<main><h1>Harbour Daily</h1><section><h2>Community reporting</h2></section></main>';
            }
          });
          const section = document.querySelector('daily-page').shadowRoot.querySelector('section');
          for (let index = 1; index <= 6; index++) {
            const card = document.createElement('daily-story');
            card.innerHTML = '<h3><a href="/news/report-' + index + '">Community report ' + index + ': new library schedules announced</a></h3>' +
              '<p>Report ' + index + ' explains the local opening hours and the public services available to residents.</p>';
            section.appendChild(card);
          }
          return true;
        })()
      JS
      before = page.evaluate("[document.body.outerHTML, document.querySelector('daily-page').shadowRoot.innerHTML, componentConstructions]")
      payload = described_class.new.extract(page)
      markdown = payload.fetch("markdown")
      positions = (1..6).map do |index|
        expect(markdown).to include("https://bulletin.example/news/report-#{index}", "Report #{index} explains the local opening hours")
        expect(markdown.scan("Community report #{index}:").length).to eq(1)
        markdown.index("Community report #{index}:")
      end
      expect(positions).to eq(positions.sort)
      expect(payload.fetch("contentType")).to eq("list")
      expect(payload.fetch("warnings")).not_to include("empty_extraction")
      after = page.evaluate("[document.body.outerHTML, document.querySelector('daily-page').shadowRoot.innerHTML, componentConstructions]")
      expect(after).to eq(before), page.evaluate("componentConstructionStacks.slice(#{before.last}).join('\\n')")
    end
  end

  it "uses assigned and fallback slots while excluding unassigned light content and hidden composed ancestors" do
    html = <<~HTML
      <html><head><title>Reading room schedule</title></head><body><div id="host">
        <h1 slot="lead">Reading room schedule</h1><p slot="lead">The council published a public schedule for the new reading room.</p>
        <p>Residents can now review the complete timetable online.</p>
        <p slot="unused">Unassigned draft must remain absent.</p>
        <article slot="unused"><h1>Unassigned draft article</h1><p>This unpublished alternative describes a different service location and schedule.</p></article>
        <p slot="suppressed">Transparent slot must remain absent.</p>
      </div></body></html>
    HTML
    with_url_page("https://bulletin.example/schedule", html) do |page|
      page.evaluate(<<~JS)
        (() => {
          const root = document.querySelector('#host').attachShadow({mode: 'open'});
          root.innerHTML = '<article><section style="visibility:hidden" title="Hidden ancestor label">' +
            'Hidden ancestor prose<!-- alignment marker --><slot name="lead" style="visibility:visible"></slot></section>' +
            '<slot></slot><slot name="empty"><p>The archive remains open throughout the winter term.</p></slot>' +
            '<slot name="suppressed" style="opacity:0"></slot><div hidden id="hidden-host"></div></article>';
          root.querySelector('#hidden-host').attachShadow({mode: 'open'}).innerHTML = '<p>Hidden nested story must remain absent.</p>';
          return true;
        })()
      JS
      markdown = described_class.new.extract(page).fetch("markdown")
      expect(markdown).to include("The council published", "Residents can now review", "The archive remains open")
      expect(markdown).not_to include("Unassigned draft", "Transparent slot", "Hidden ancestor", "Hidden nested story")
    end
  end

  it "retains article prose, relative references and code inside an open component" do
    html = "<html><head><title>Library data reference</title></head><body><div id='reference'></div></body></html>"
    with_url_page("https://bulletin.example/reference/", html) do |page|
      page.evaluate(<<~JS)
        document.querySelector('#reference').attachShadow({mode: 'open'}).innerHTML =
          '<article><h1>Library data reference</h1><p>The public catalogue includes opening hours, collection names and accessible facilities. ' +
          'Each record is published with a stable identifier so that readers can refer to the same service across updates.</p>' +
          '<h2>Read a catalogue entry</h2><p>Use the documented endpoint to retrieve the current schedule. ' +
          'The response provides a complete list of available services, including holiday exceptions and contact details.</p>' +
          '<pre><code class="language-ruby">catalogue.fetch(42)\\nputs entry.name</code></pre>' +
          '<p>See the <a href="schema">catalogue schema</a> for the meaning of each field.</p></article>';
      JS
      payload = described_class.new.extract(page)
      expect(payload.fetch("markdown")).to include("The public catalogue includes", "holiday exceptions", "catalogue.fetch(42)\nputs entry.name", "https://bulletin.example/reference/schema")
      expect(payload.fetch("contentType")).to eq("article")
    end
  end

  it "preserves nested closed component content created by initial page scripts" do
    token = JSON.generate(FetchUtil::Browser::SHADOW_ROOT_ACCESS_TOKEN)
    property = JSON.generate(FetchUtil::Browser::SHADOW_ROOT_READER_PROPERTY)
    html = <<~HTML
      <html><head><title>Closed component bulletin</title></head><body>
      <div id="host"><p slot="notice">Assigned closed-root notice remains visible.</p>
        <p slot="unused">Unassigned closed-root draft must remain absent.</p></div><div id="hidden" hidden></div>
      <script>
        const hostRoot = document.querySelector('#host').attachShadow({mode: 'closed'});
        hostRoot.innerHTML = '<article><h1>Closed component bulletin</h1>' +
          '<p>The council published a complete public notice with opening hours, contact details and accessibility information.</p>' +
          '<slot name="notice"></slot>' +
          '<section><h2>Service schedule</h2><div id="nested"></div></section></article>';
        const nestedRoot = hostRoot.querySelector('#nested').attachShadow({mode: 'closed'});
        nestedRoot.innerHTML = '<p>Residents can visit every weekday and request assistance at the front desk.</p>';
        const hiddenRoot = document.querySelector('#hidden').attachShadow({mode: 'closed'});
        hiddenRoot.innerHTML = '<p>Hidden closed-root announcement must remain absent.</p>';
      </script></body></html>
    HTML
    with_url_page("https://bulletin.example/closed", html) do |page|
      snapshot = <<~JS
        (() => {
          const readRoot = window[#{property}];
          const hostRoot = readRoot(#{token}, 'get', document.querySelector('#host'));
          return [
            document.body.outerHTML,
            hostRoot.innerHTML,
            readRoot(#{token}, 'get', hostRoot.querySelector('#nested')).innerHTML,
            readRoot(#{token}, 'get', document.querySelector('#hidden')).innerHTML
          ];
        })()
      JS
      expect(page.evaluate("window[#{property}]('wrong-token', 'get', document.querySelector('#host'))")).to be_nil
      before = page.evaluate(snapshot)
      extractor = described_class.new
      first = extractor.extract(page).fetch("markdown")
      second = extractor.extract(page).fetch("markdown")
      expect(first).to include("Closed component bulletin", "The council published", "Assigned closed-root notice", "Residents can visit every weekday")
      expect(first).not_to include("Unassigned closed-root draft", "Hidden closed-root announcement")
      expect(second).to eq(first)
      expect(page.evaluate(snapshot)).to eq(before)
    end
  end

  it "preserves declarative closed component content created by the parser" do
    html = <<~HTML
      <html><head><title>Declarative component bulletin</title></head><body>
      <section id="host"><template shadowrootmode="closed"><article>
        <h1>Declarative component bulletin</h1>
        <p>The library published complete holiday opening hours and accessible service information for every visitor.</p>
        <section id="nested-host"><template shadowrootmode="closed">
          <p>Nested declarative details list each available reading-room service.</p>
        </template></section>
      </article></template></section>
      <section id="hidden" hidden><template shadowrootmode="closed">
        <p>Hidden declarative announcement must remain absent.</p>
      </template></section>
      </body></html>
    HTML
    with_url_page("https://bulletin.example/declarative", html) do |page|
      before = page.evaluate("document.body.outerHTML")
      expect(page.evaluate("document.querySelector('#host').shadowRoot")).to be_nil

      payload = described_class.new.extract(page)

      expect(payload.fetch("markdown")).to include("Declarative component bulletin", "complete holiday opening hours", "Nested declarative details")
      expect(payload.fetch("markdown")).not_to include("Hidden declarative announcement")
      expect(page.evaluate("document.body.outerHTML")).to eq(before)
      expect(page.evaluate("document.querySelector('#host').shadowRoot")).to be_nil
    end
  end

  it "preserves native open-root behavior when page code replaces WeakMap methods" do
    html = "<html><head><title>Open root</title></head><body><div id='host'></div><div id='second'></div></body></html>"
    with_url_page("https://bulletin.example/open", html) do |page|
      behavior = page.evaluate(<<~JS)
        (() => {
          const host = document.querySelector('#host');
          const root = host.attachShadow({mode: 'open'});
          root.innerHTML = '<article><h1>Open root</h1><p>Visible component article content remains available.</p></article>';
          let duplicateError = null;
          try { host.attachShadow({mode: 'open'}); } catch (error) { duplicateError = error.name; }
          const originalSet = WeakMap.prototype.set;
          WeakMap.prototype.set = function() { throw new Error('page override'); };
          let secondAttached = false;
          try {
            const secondRoot = document.querySelector('#second').attachShadow({mode: 'closed'});
            secondRoot.innerHTML = '<p>Closed content survives a page override of WeakMap methods.</p>';
            secondAttached = true;
          } finally {
            WeakMap.prototype.set = originalSet;
          }
          return [
            root === host.shadowRoot,
            duplicateError,
            secondAttached,
            Object.getOwnPropertyNames(Element.prototype.attachShadow).filter(name => name.includes('FetchUtil'))
          ];
        })()
      JS
      expect(behavior).to eq([true, "NotSupportedError", true, []])
      markdown = described_class.new.extract(page).fetch("markdown")
      expect(markdown).to include("Visible component article content", "Closed content survives")
    end
  end

  it "retains tracked closed roots when their hosts move from same-origin frames" do
    with_url_page("https://bulletin.example/adopted", "<html><head><title>Adopted notice</title></head><body></body></html>") do |page|
      page.evaluate(<<~JS)
        (() => {
          const frame = document.createElement('iframe');
          document.body.appendChild(frame);
          const host = frame.contentDocument.createElement('div');
          frame.contentDocument.body.appendChild(host);
          const root = host.attachShadow({mode: 'closed'});
          root.innerHTML = '<article><h1>Adopted notice</h1><p>The transferred component preserves its complete public service announcement.</p></article>';
          document.body.appendChild(document.adoptNode(host));
          frame.remove();
        })()
      JS
      expect(described_class.new.extract(page).fetch("markdown")).to include("transferred component preserves")
    end
  end

  it "refreshes component discovery between extractions and observes changed host visibility" do
    with_url_page("https://bulletin.example/update", "<html><head><title>Service update</title></head><body><div id='host'></div></body></html>") do |page|
      extractor = described_class.new
      expect(extractor.extract(page).fetch("markdown")).not_to include("Public service announcement")
      page.evaluate(<<~JS)
        document.querySelector('#host').attachShadow({mode: 'open'}).innerHTML =
          '<article><h1>Public service announcement</h1><p>The community centre is extending its opening hours throughout the winter. ' +
          'Residents can use the reading room, request catalogue assistance and attend scheduled workshops every weekday.</p></article>';
      JS
      expect(extractor.extract(page).fetch("markdown")).to include("Public service announcement", "scheduled workshops")
      page.evaluate("document.querySelector('#host').hidden = true")
      expect(extractor.extract(page).fetch("markdown")).not_to include("Public service announcement", "scheduled workshops")
    end
  end
end
