# frozen_string_literal: true

require 'json'

RSpec.describe 'FetchUtil component page ownership' do
  include_context 'extractor integration helpers'

  def resource_cards
    (1..4).map do |index|
      <<~HTML
        <article class="resource-card"><h3>Research resource #{index}</h3>
        <p>First explanation for resource #{index} describes the findings and their practical use.</p>
        <p>Second explanation for resource #{index} preserves a separate qualification.</p>
        <a href="/resources/#{index}">Read this resource</a></article>
      HTML
    end.join
  end

  it 'retains the complete main and full resource cards around a subordinate hub' do
    html = <<~HTML
      <html><head><title>Research platform</title></head><body><main><h1>Research platform</h1>
      <p>Our platform joins independently collected records while preserving the context behind every decision.</p>
      <section><h2>Normalization engine</h2><p>Review the original values before applying a transformation.</p>
      <a href="/normalization">Explore normalization</a><pre>normalize(record)</pre></section>
      <section><h2>Identity orchestrator</h2><p>Choose the ownership and matching policy for each dataset.</p>
      <a href="/identity">Explore identity</a></section>
      <section><h2>Resources</h2><div role="list">#{resource_cards}</div></section>
      <aside><p>Unrelated sidebar promotion</p></aside></main>
      <footer>Unrelated footer directory</footer></body></html>
    HTML
    with_url_page('https://research.example/', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract_payload(page)
      markdown = payload.fetch('markdown')
      expect(markdown).to include('independently collected records', 'Normalization engine', 'Identity orchestrator',
                                  'https://research.example/normalization', 'https://research.example/identity',
                                  'normalize(record)')
      positions = (1..4).flat_map do |index|
        ["Research resource #{index}", "First explanation for resource #{index}",
         "Second explanation for resource #{index}", "https://research.example/resources/#{index}"].map do |value|
          expect(markdown).to include(value)
          markdown.index(value)
        end
      end
      expect(positions).to eq(positions.sort)
      expect(markdown).not_to include('Unrelated sidebar promotion', 'Unrelated footer directory')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'materializes source-declared component fields without dropping short titles, long titles or authored children' do
    names = ['Housing', 'Education', 'Transport', '中', 'A source title with complete context ' * 8]
    cards = names.each_with_index.map do |name, index|
      data = JSON.generate('tile' => { 'xdm:linkURL' => "/services/#{index}" })
      <<~HTML
        <gui-tile data-cmp-data-layer='#{data}'>
          <gui-tile-heading heading-text="#{name}"></gui-tile-heading>
          <gui-tile-content content-text="Source-declared service detail #{index}."></gui-tile-content>
          <p>Additional authored qualification #{index} must remain available.</p>
          <pre>service_#{index}(record)</pre><a href="/references/#{index}">Research citation #{index}</a>
        </gui-tile>
      HTML
    end.join
    html = <<~HTML
      <html><head><title>Public services</title></head><body><main><h1>Public services</h1>
      <p>Read the eligibility and evidence requirements before selecting one of these independently documented services.</p>
      <gui-tile-list role="list">#{cards}</gui-tile-list></main></body></html>
    HTML
    extract_from_url('https://services.example/', html) do |payload|
      markdown = payload.fetch('markdown')
      names.each_with_index do |name, index|
        expect(markdown).to include(name.strip, "Source-declared service detail #{index}",
                                    "Additional authored qualification #{index}", "service_#{index}(record)",
                                    "https://services.example/services/#{index}", "https://services.example/references/#{index}")
      end
    end
  end

  it 'does not expand a hub into competing main regions' do
    html = <<~HTML
      <html><head><title>Resource hub</title></head><body>
      <main><h1>Resource hub</h1><div role="list">#{resource_cards}</div></main>
      <main><h1>Unrelated ownership</h1><p>Do not import this separate main's reporting.</p></main></body></html>
    HTML
    extract_from_url('https://resources.example/', html) do |payload|
      expect(payload.fetch('markdown')).to include('https://resources.example/resources/1')
      expect(payload.fetch('markdown')).not_to include('Unrelated ownership', 'separate main')
    end
  end
end
