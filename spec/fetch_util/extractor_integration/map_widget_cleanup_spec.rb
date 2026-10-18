# frozen_string_literal: true

require 'nokogiri'

RSpec.describe 'Map widget cleanup ownership' do
  include_context 'extractor integration helpers'

  it 'preserves leaflet cards and roadmap prose while removing actual map widgets' do
    html = <<~HTML
      <article>
        <h1>Community publications and plans</h1>
        <p>The community publishes local walking guides and a development roadmap.
        These descriptions and their destinations are part of the article, alongside its location map.</p>
        <div class="weekly-leaflet-card">
          <h2><a href="/walking-guide">A quiet walking route through the neighbourhood</a></h2>
          <p>The printed guide includes resting places and accessible entrances.</p>
        </div>
        <section class="roadmap-container">
          <h2><a href="/development-plan">The next stage of the neighbourhood plan</a></h2>
          <p>Residents can inspect the proposed improvements and their schedule.</p>
        </section>
        <div class="leaflet-container"><div class="leaflet-pane">Map tile attribution</div>
          <div class="leaflet-control"><a title="Zoom in">+</a><a title="Zoom out">-</a></div>
        </div>
        <div class="maplibregl-map">Interactive map controls</div>
        <div class="mw-kartographer-container">Map preview widget</div>
      </article>
    HTML

    extract_from_url('https://portal.example.test/community/', html, reader_mode: false) do |payload|
      expect(payload['markdown']).to include(
        'A quiet walking route through the neighbourhood', 'https://portal.example.test/walking-guide',
        'The next stage of the neighbourhood plan', 'https://portal.example.test/development-plan',
        'The printed guide includes resting places', 'Residents can inspect the proposed improvements'
      )
      expect(payload['markdown']).not_to include('Map tile attribution', 'Interactive map controls', 'Map preview widget')
    end
  end

  %w[article mkdocs].each do |framework|
    it "preserves every static map image layer in #{framework} content" do
      generator = framework == 'mkdocs' ? '<meta name="generator" content="mkdocs-1.6.0">' : ''
      article_class = framework == 'mkdocs' ? 'md-content__inner md-typeset' : ''
      html = <<~HTML
        <html><head><title>Published map resources</title>#{generator}</head><body>
          <main><article class="#{article_class}">
            <h1>Published map resources</h1>
            <p>The complete field guide preserves both independently published survey maps.
            Each image belongs to a different observation, even when their resource destination is shared.</p>
            <div class="leaflet-container">
              <div class="leaflet-pane leaflet-map-pane">
                <div class="leaflet-pane leaflet-tile-pane">
                  <img class="leaflet-tile" src="/tiles/7/12/34.png" alt="Tile furniture">
                </div>
                <div class="leaflet-pane leaflet-overlay-pane">
                  <img class="leaflet-image-layer" src="/maps/survey.webp" alt="">
                </div>
                <div class="leaflet-pane leaflet-marker-pane">
                  <img class="leaflet-marker-icon" src="/icons/marker.png" alt="Marker furniture">
                </div>
              </div>
              <div class="leaflet-control"><a title="Zoom in">+</a><a title="Zoom out">-</a></div>
            </div>
            <p>A second observation retains its own static map and the complete
            <a href="/field-notes/">field notes</a> rather than borrowing the first image occurrence.</p>
            <div class="leaflet-container"><div class="leaflet-pane leaflet-map-pane">
              <div class="leaflet-pane leaflet-overlay-pane">
                <img class="leaflet-image-layer" src="/maps/survey.webp" alt="">
              </div>
            </div></div>
            <section hidden><div class="leaflet-container"><div class="leaflet-pane leaflet-overlay-pane">
              <img class="leaflet-image-layer" src="/maps/hidden.webp" alt="Hidden map">
            </div></div></section>
            <pre><code>survey = [1, 2]
        print(survey)</code></pre>
          </article></main>
        </body></html>
      HTML

      with_url_page('https://publication.example.test/maps/', html) do |page|
        before = page.evaluate('document.body.outerHTML')
        payload = extract(page)
        expect(page.evaluate('document.body.outerHTML')).to eq(before)
        document = Nokogiri::HTML5.fragment(payload.fetch('html'))
        expect(document.css('img').map { |image| [image['src'], image['alt']] }).to eq(
          [
            ['https://publication.example.test/maps/survey.webp', ''],
            ['https://publication.example.test/maps/survey.webp', '']
          ]
        )
        expect(document.css('pre').map(&:text)).to eq(["survey = [1, 2]\nprint(survey)"])
        expect(payload.fetch('markdown').scan('![](https://publication.example.test/maps/survey.webp)').length).to eq(2)
        expect(payload.fetch('markdown')).to include(
          'The complete field guide preserves both independently published survey maps.',
          'A second observation retains its own static map and the complete',
          '[field notes](https://publication.example.test/field-notes/)',
          "survey = [1, 2]\nprint(survey)"
        )
        expect(payload.fetch('html') + payload.fetch('markdown')).not_to include(
          'Tile furniture', 'Marker furniture', '/tiles/', '/icons/marker.png', '/maps/hidden.webp', 'Hidden map', 'Zoom in', 'Zoom out'
        )
      end
    end
  end
end
