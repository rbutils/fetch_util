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
