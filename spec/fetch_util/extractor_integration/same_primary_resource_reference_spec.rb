# frozen_string_literal: true

require 'spec_helper'
require 'support/extractor_integration_helpers'

RSpec.describe 'Independently labelled same-primary resource references' do
  include_context 'extractor integration helpers'

  def resource_collection_html
    records = (1..6).map do |number|
      <<~HTML
        <article data-record="#{number}">
          <a href="/reports/#{number}"><img src="/images/report-#{number}.png" alt="Report illustration #{number}"></a>
          <h3><a id="report-#{number}" href="/reports/#{number}">Published research report #{number}</a></h3>
          <a href="/reports/#{number}">Published research report #{number}</a>
          <p>The complete independently authored explanation belongs to research report #{number}.</p>
          <div class="resource-links">
            <a href="https://resources.example.test/guide-#{number}">Reference guide #{number}</a>
            <a href="/reports/#{number}" aria-label="Alternate publication resource #{number}">Alternate publication resource #{number}</a>
            <a href="https://resources.example.test/data-#{number}">Complete dataset #{number}</a>
            <a hidden href="/reports/#{number}">Hidden distribution #{number}</a>
          </div>
          <nav><a href="/reports/#{number}">Navigation distribution #{number}</a></nav>
        </article>
      HTML
    end
    <<~HTML
      <html><head><title>Published research collections</title></head><body><main>
      <h1>Published research collections</h1>
      <section><h2>Independent research</h2>#{records.take(3).join}</section>
      <section><h2>Community research</h2>#{records.drop(3).join}</section>
      </main></body></html>
    HTML
  end

  def selected_resource_markdown(page)
    root = File.expand_path('../..', File.dirname(FetchUtil::Extractor.instance_method(:extract).source_location.first))
    paths = File.readlines(File.join(root, 'websieve/manifest.txt'), chomp: true).reject { |line| line.empty? || line.start_with?('#') }
    source = paths.map { |path| File.read(File.join(root, 'websieve', path)) }.join("\n")
    outro = File.read(File.join(root, 'websieve/99_outro.js'))
    raise 'private source boundary changed' unless source.scan(outro).size == 1

    source = source.sub(outro, <<~JS)
      window.__selectedResourceMarkdown = function() {
        var root = visibleListClone(document.querySelector('main'));
        cleanupAgentRoot(root);
        var items = Array.from(root.querySelectorAll('article[data-record]')).map(function(card) {
          var link = card.querySelector('h3 a[href]');
          return {sourceNode: link, card: card, url: link.href, text: link.textContent,
            summary: card.querySelector('p').textContent};
        });
        return listMarkdown(items);
      };
      })(window);
    JS
    inject_standalone_extractor(page)
    page.add_script_tag(content: source)
    page.evaluate('window.__selectedResourceMarkdown()')
  end

  def expect_complete_resource_references(markdown, primary_occurrences: 1)
    (1..6).each do |number|
      primary = "https://publication.example.test/reports/#{number}"
      expect(markdown.scan("[Published research report #{number}](#{primary})").size).to eq(primary_occurrences)
      expect(markdown).to include("[Alternate publication resource #{number}](#{primary})",
                                  "[Reference guide #{number}](https://resources.example.test/guide-#{number})",
                                  "[Complete dataset #{number}](https://resources.example.test/data-#{number})",
                                  "The complete independently authored explanation belongs to research report #{number}.")
      expect(markdown).not_to include("Hidden distribution #{number}", "Navigation distribution #{number}")
    end
  end

  it 'retains independent resource bindings while suppressing only actual primary aliases' do
    with_url_page('https://publication.example.test/', resource_collection_html) do |page|
      before = page.evaluate('document.body.innerHTML')
      expect_complete_resource_references(selected_resource_markdown(page))
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'retains every authored resource label through ordinary collection extraction' do
    with_url_page('https://publication.example.test/', resource_collection_html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract(page)
      markdown = payload.fetch('markdown')
      expect_complete_resource_references(markdown, primary_occurrences: 2)
      expected_destinations = (1..6).flat_map do |number|
        primary = "https://publication.example.test/reports/#{number}"
        ["https://publication.example.test/images/report-#{number}.png", primary, primary, primary,
         "https://resources.example.test/guide-#{number}", primary, "https://resources.example.test/data-#{number}"]
      end
      expected_headings = (1..6).map do |number|
        ["Published research report #{number}", "https://publication.example.test/reports/#{number}"]
      end
      expect(markdown.scan(%r{\]\((https?://[^)]+)\)}).flatten).to eq(expected_destinations)
      expect(markdown.scan(/^### \[([^\]]+)\]\(([^)]+)\)$/)).to eq(expected_headings)
      expect(markdown.scan(/!\[([^\]]+)\]\(([^)]+)\)/)).to eq((1..6).map do |number|
        ["Report illustration #{number} Published research report #{number}",
         "https://publication.example.test/images/report-#{number}.png"]
      end)
      (1..6).each do |number|
        expect(payload.fetch('html')).to include("Alternate publication resource #{number}",
                                                 "https://resources.example.test/data-#{number}")
      end
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end
end
