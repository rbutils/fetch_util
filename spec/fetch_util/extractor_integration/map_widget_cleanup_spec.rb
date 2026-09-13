# frozen_string_literal: true

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
end
