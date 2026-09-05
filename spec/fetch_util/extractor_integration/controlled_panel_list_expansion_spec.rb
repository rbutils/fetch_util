# frozen_string_literal: true

RSpec.describe 'FetchUtil extractor controlled panel list expansion' do
  include_context 'extractor integration helpers'

  def controlled_panel_records(numbers)
    numbers.map do |number|
      <<~HTML
        <article class="destination-card">
          <h3><a href="/records/#{number}">Destination record #{number} with local guidance</a></h3>
          <p>Practical route details for destination record #{number}.</p>
        </article>
      HTML
    end.join
  end

  def controlled_panel_fixture(hidden_records: 8, control_role: 'checkbox', hidden_first: false,
                               nested_pages: true, nested_noise: false)
    state_name = control_role == 'tab' ? 'aria-selected' : 'aria-checked'
    hidden_numbers = (11...(11 + hidden_records)).to_a
    country_panel = <<~HTML
      <div id="country-panel">
        <div class="panel-page">#{controlled_panel_records(1..4)}</div>
        #{nested_pages ? %(<div class="panel-page" hidden>#{controlled_panel_records(5..7)}</div>) : nil}
        #{nested_pages ? %(<div class="panel-page" hidden>#{controlled_panel_records(8..10)}</div>) : nil}
        #{nested_noise ? %(<aside hidden>#{controlled_panel_records(900..902)}</aside>) : nil}
        #{nested_noise ? %(<div class="panel-page responsive-copy" hidden>#{controlled_panel_records(1..4)}</div>) : nil}
        <div class="pagination">
          <button type="button" aria-current="true" aria-label="Page 1">1</button>
          <button type="button" aria-current="false" aria-label="Page 2">2</button>
          <button type="button" aria-current="false" aria-label="Page 3">3</button>
        </div>
      </div>
    HTML
    inactive_panels = <<~HTML
      <div id="region-panel" hidden>#{controlled_panel_records(hidden_numbers.first(hidden_records / 2))}</div>
      <div id="airport-panel" style="display: none !important">
        #{controlled_panel_records(hidden_numbers.drop(hidden_records / 2))}
      </div>
    HTML
    targets = hidden_first ? inactive_panels + country_panel : country_panel + inactive_panels
    <<~HTML
      <html><head>
        <title>Travel destination directory</title>
        <meta name="description" content="Compare routes and destinations with practical local guidance.">
      </head><body><main>
        <h1>Travel destination directory</h1>
        <p>Independent introduction that must remain ahead of every directory record.</p>
        <div class="panel-controls">
          <button role="#{control_role}" #{state_name}="true" aria-controls="country-panel">Countries</button>
          <button role="#{control_role}" #{state_name}="false" aria-controls="region-panel">Regions</button>
          <button role="#{control_role}" #{state_name}="false" aria-controls="airport-panel">Airports</button>
        </div>
        <div class="panel-targets">
          #{targets}
        </div>
        <section hidden>#{controlled_panel_records([999])}</section>
      </main></body></html>
    HTML
  end

  def record_numbers(markdown)
    markdown.scan(%r{\]\(https://travel\.example/records/(\d+)\)}).flatten.map(&:to_i)
  end

  it 'appends every inactive panel record after preserving the selected list' do
    with_url_page('https://travel.example/', controlled_panel_fixture) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)
      markdown = payload.fetch('markdown')

      expect(payload['contentType']).to eq('list')
      expect(markdown).to include('Compare routes and destinations with practical local guidance.')
      expect(record_numbers(markdown)).to eq((1..18).to_a)
      expect(markdown).not_to include('/records/999')
      expect(markdown.index('/records/4')).to be < markdown.index('/records/5')
      expect(markdown.index('/records/6')).to be < markdown.index('/records/7')
      expect(payload).not_to have_key('listExtraction')
      expect(payload).not_to have_key('listSourceNode')
      expect(payload).not_to have_key('listSourceItems')
    end
  end

  it 'expands a generic portal whose owner has an additional lead record' do
    html = controlled_panel_fixture.sub(
      '<h1>Travel destination directory</h1>',
      '<a href="/discover">Explore worlds</a><h1>Travel destination directory</h1>'
    )

    with_url_page('https://travel.example/', html) do |page|
      markdown = FetchUtil::Extractor.new(reader_mode: false).extract(page).fetch('markdown')

      expect(markdown).to include('[Explore worlds](https://travel.example/discover)')
      expect(record_numbers(markdown)).to eq((1..18).to_a)
      expect(markdown.index('/discover')).to be < markdown.index('/records/1')
    end
  end

  it 'does not append a generic panel delta to a specialized portal result' do
    specialized = <<~HTML
      <section class="wp-section-grid">
        <h2><a class="wp-section-title-link" href="/news">Latest reports</a></h2>
        <a class="wp-teaser-tile" href="/special/1">Specialized report one</a>
        <a class="wp-teaser-tile" href="/special/2">Specialized report two</a>
        <a class="wp-teaser-tile" href="/special/3">Specialized report three</a>
      </section>
    HTML
    html = controlled_panel_fixture.sub('<h1>Travel destination directory</h1>', specialized)

    with_url_page('https://wp.pl/', html) do |page|
      markdown = FetchUtil::Extractor.new(reader_mode: false).extract(page).fetch('markdown')

      expect(markdown).to include('Specialized report one')
      expect(record_numbers(markdown)).to be_empty
    end
  end

  it 'does not expand ordinary accordion controls' do
    html = controlled_panel_fixture(control_role: 'button')

    with_url_page('https://travel.example/', html) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)

      expect(payload['contentType']).to eq('list')
      expect(record_numbers(payload.fetch('markdown'))).to eq((1..4).to_a)
    end
  end

  it 'requires visible controls and a visible selected target' do
    hidden_controls = controlled_panel_fixture.sub(
      '<div class="panel-controls">',
      '<div class="panel-controls" style="visibility: hidden">'
    )
    hidden_selected = controlled_panel_fixture
                      .sub('<div class="panel-targets">', "#{controlled_panel_records(1001..1004)}<div class=\"panel-targets\">")
                      .sub('<div id="country-panel">', '<div id="country-panel" style="visibility: hidden">')

    [[hidden_controls, 1..4], [hidden_selected, 1001..1004]].each do |html, expected|
      with_url_page('https://travel.example/', html) do |page|
        markdown = FetchUtil::Extractor.new(reader_mode: false).extract(page).fetch('markdown')

        expect(record_numbers(markdown)).to eq(expected.to_a)
      end
    end
  end

  it 'does not expose a hidden target whose checkbox remains checked' do
    html = controlled_panel_fixture.sub(
      'aria-checked="false" aria-controls="region-panel"',
      'aria-checked="true" aria-controls="region-panel"'
    )

    with_url_page('https://travel.example/results', html) do |page|
      markdown = FetchUtil::Extractor.new(reader_mode: false).extract(page).fetch('markdown')

      expect(record_numbers(markdown)).to eq((1..10).to_a + (15..18).to_a)
    end
  end

  it 'requires a visible selected continuation page' do
    html = controlled_panel_fixture
           .sub('<div class="panel-page">', '<div class="panel-page" style="visibility: hidden">')
           .sub('<div class="panel-targets">', "#{controlled_panel_records(1001..1004)}<div class=\"panel-targets\">")

    with_url_page('https://travel.example/results', html) do |page|
      markdown = FetchUtil::Extractor.new(reader_mode: false).extract(page).fetch('markdown')

      expect(record_numbers(markdown)).to eq((1001..1004).to_a + (11..18).to_a)
      expect(markdown).not_to include('/records/5')
    end
  end

  it 'requires at least three additional material records' do
    with_url_page('https://travel.example/', controlled_panel_fixture(hidden_records: 0, nested_pages: false)) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)

      expect(record_numbers(payload.fetch('markdown'))).to eq((1..4).to_a)
    end
  end

  it 'rejects panels whose hidden records precede the selected records' do
    with_url_page('https://travel.example/', controlled_panel_fixture(hidden_first: true)) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)

      expect(record_numbers(payload.fetch('markdown'))).to eq((1..4).to_a)
    end
  end

  it 'excludes nested draft and responsive duplicate records' do
    with_url_page('https://travel.example/', controlled_panel_fixture(nested_noise: true)) do |page|
      markdown = FetchUtil::Extractor.new(reader_mode: false).extract(page).fetch('markdown')

      expect(record_numbers(markdown)).to eq((1..18).to_a)
      expect(markdown).not_to include('/records/900')
    end
  end

  it 'does not let an inactive panel authorize hidden continuation records' do
    html = <<~HTML
      <html><head><title>Travel destination directory</title></head><body><main>
        <h1>Travel destination directory</h1>
        <div>
          <button role="tab" aria-selected="true" aria-controls="current-panel">Current</button>
          <button role="tab" aria-selected="false" aria-controls="future-panel">Future</button>
          <button role="tab" aria-selected="false" aria-controls="regional-panel">Regional</button>
        </div>
        <div>
          <div id="current-panel">#{controlled_panel_records(1..4)}</div>
          <div id="future-panel" hidden>
            <div class="panel-page">#{controlled_panel_records(5..7)}</div>
            <div class="panel-page" hidden>#{controlled_panel_records(900..902)}</div>
            <div class="panel-page" hidden>#{controlled_panel_records(903..905)}</div>
            <div class="pagination">
              <button aria-current="true">1</button><button aria-current="false">2</button>
            </div>
          </div>
          <div id="regional-panel" hidden>#{controlled_panel_records(8..10)}</div>
        </div>
      </main></body></html>
    HTML

    with_url_page('https://travel.example/', html) do |page|
      markdown = FetchUtil::Extractor.new(reader_mode: false).extract(page).fetch('markdown')

      expect(record_numbers(markdown)).to eq((1..10).to_a)
      expect(markdown).not_to include('/records/900')
    end
  end

  it 'does not use visually hidden pagination as continuation evidence' do
    html = <<~HTML
      <html><head><title>Travel destination directory</title></head><body><main>
        <h1>Travel destination directory</h1>
        <div>
          <button role="tab" aria-selected="true" aria-controls="current-panel">Current</button>
          <button role="tab" aria-selected="false" aria-controls="future-panel">Future</button>
          <button role="tab" aria-selected="false" aria-controls="regional-panel">Regional</button>
        </div>
        <div>
          <div id="current-panel">
            <div class="panel-page">#{controlled_panel_records(1..4)}</div>
            <div class="panel-page" hidden>#{controlled_panel_records(5..7)}</div>
            <div class="panel-page" hidden>#{controlled_panel_records(8..10)}</div>
            <div class="pagination" style="visibility: hidden">
              <button aria-current="true">1</button><button aria-current="false">2</button>
            </div>
          </div>
          <div id="future-panel" hidden>
            <div class="panel-page">#{controlled_panel_records(11..13)}</div>
            <div class="panel-page" hidden>#{controlled_panel_records(900..902)}</div>
            <div class="panel-page" hidden>#{controlled_panel_records(903..905)}</div>
            <div class="pagination">
              <button aria-current="true">1</button><button aria-current="false">2</button>
            </div>
          </div>
          <div id="regional-panel" hidden>#{controlled_panel_records(14..16)}</div>
        </div>
      </main></body></html>
    HTML

    with_url_page('https://travel.example/', html) do |page|
      markdown = FetchUtil::Extractor.new(reader_mode: false).extract(page).fetch('markdown')

      expect(record_numbers(markdown)).to eq((1..4).to_a + (11..16).to_a)
      expect(markdown).not_to include('/records/5')
      expect(markdown).not_to include('/records/900')
    end
  end

  it 'does not use an unrelated nested pager as continuation evidence' do
    unrelated_pager = <<~HTML
      <aside class="carousel">
        <a href="/promotions">Featured promotion</a>
        <div class="pagination">
          <button aria-current="true">1</button>
          <button aria-current="false">2</button>
          <button aria-current="false">3</button>
        </div>
      </aside>
    HTML
    html = controlled_panel_fixture.sub(%r{<div class="pagination">.*?</div>}m, unrelated_pager)

    with_url_page('https://travel.example/results', html) do |page|
      markdown = FetchUtil::Extractor.new(reader_mode: false).extract(page).fetch('markdown')

      expect(record_numbers(markdown)).to eq((1..4).to_a + (11..18).to_a)
      expect(markdown).not_to include('/records/5')
    end
  end

  it 'appends controlled records after deferred section descriptions' do
    html = <<~HTML
      <html><head><title>Sectioned travel directory</title></head><body><main>
        <h1>Sectioned travel directory</h1>
        <p>Independent directory guidance must remain before every section and controlled record.</p>
        <section><h2>Travel support</h2>#{controlled_panel_records(1..3)}</section>
        <section><h2>Regional routes</h2>
          <div><button role="tab" aria-selected="true" aria-controls="selected-routes">Selected</button>
            <button role="tab" aria-selected="false" aria-controls="other-routes">Other</button></div>
          <div><div id="selected-routes">#{controlled_panel_records(4..6)}</div>
            <div id="other-routes" hidden>#{controlled_panel_records(7..9)}</div></div>
        </section>
      </main></body></html>
    HTML

    with_url_page('https://travel.example/sections', html) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)
      markdown = payload.fetch('markdown')

      expect(payload.fetch('contentType')).to eq('list')
      expect(markdown).to include('Independent directory guidance')
      expect(record_numbers(markdown)).to eq((1..9).to_a)
      expect(payload.fetch('textContent').gsub(/\s+/, ' ').strip).to eq(markdown.gsub(/\s+/, ' ').strip)
    end
  end

  it 'does not let controlled records prevent warning-driven interstitial promotion' do
    compact_cards = lambda do |numbers|
      numbers.map do |number|
        %(<article class="resource-card"><h3><a href="/policy/#{number}">Consent #{number}</a></h3></article>)
      end.join
    end
    html = <<~HTML
      <html><head><title>Policy resources</title></head><body><main>
        <h1>Policy resources</h1>
        <section><h2>Cookie choices</h2>
          <div><button role="tab" aria-selected="true" aria-controls="basic-consent">Basic</button>
            <button role="tab" aria-selected="false" aria-controls="detailed-consent">Detailed</button></div>
          <div><div id="basic-consent">#{compact_cards.call(1..4)}</div>
            <div id="detailed-consent" hidden>#{controlled_panel_records(20..31)}</div></div>
        </section>
        <section><h2>Consent choices</h2>#{compact_cards.call(5..8)}</section>
      </main></body></html>
    HTML

    with_url_page('https://travel.example/policy', html) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)

      expect(payload.fetch('contentType')).to eq('interstitial')
      expect(payload.fetch('warnings')).to include('consent_interstitial')
      expect(payload.fetch('markdown')).not_to include('/records/20')
    end
  end

  it 'does not expose controlled panels through an article result' do
    paragraphs = 4.times.map do |index|
      <<~HTML
        <p>Operational section #{index + 1} explains the public transport program, its planning decisions, deployment
        safeguards, regional coordination, and the evidence readers need to understand the service in full.</p>
      HTML
    end.join
    html = <<~HTML
      <html><head><title>Transport program guide</title></head><body><main><article>
        <h1>Transport program guide</h1>
        #{paragraphs}
        <div><button role="tab" aria-selected="true" aria-controls="overview-panel">Overview</button>
          <button role="tab" aria-selected="false" aria-controls="archive-panel">Archive</button></div>
        <div><section id="overview-panel"><p>Visible implementation overview.</p></section>
          <section id="archive-panel" hidden>#{controlled_panel_records(20..24)}</section></div>
      </article></main></body></html>
    HTML

    with_url_page('https://travel.example/guides/transport-program', html) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: true).extract(page)

      expect(payload['contentType']).to eq('article')
      expect(payload.fetch('markdown')).to include('Operational section 1')
      expect(payload.fetch('markdown')).not_to include('/records/20')
    end
  end
end
