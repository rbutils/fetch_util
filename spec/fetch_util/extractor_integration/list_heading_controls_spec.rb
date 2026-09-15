# frozen_string_literal: true

RSpec.describe 'FetchUtil extractor list heading controls' do
  include_context 'extractor integration helpers'

  def heading_control_record(number)
    <<~HTML
      <article>
        <h3><a href="/stories/#{number}">Independent newsroom story #{number}</a></h3>
        <p>Locally owned summary for newsroom story #{number}.</p>
      </article>
    HTML
  end

  def heading_control_tail
    (6..11).map do |number|
      "<li><a href=\"/stories/#{number}\">Independent newsroom story #{number}</a></li>"
    end.join
  end

  it 'removes a proved nested dropdown action while preserving the section link' do
    html = <<~HTML
      <html><head><title>Regional newsroom</title></head><body><main>
        <h1>Regional newsroom</h1>
        <section id="lead-record">#{heading_control_record(1)}</section>
        <section id="regional-desk" data-section="regional-warsaw">
          <h2 class="feed-header">
            <a href="/warsaw"><span class="feed-title">Warszawa</span><span class="Dropdown_select__hash">zmień</span></a>
          </h2>
          #{heading_control_record(2)}
          #{heading_control_record(3)}
        </section>
        <section id="culture-desk">
          <h2>Culture desk</h2>
          #{heading_control_record(4)}
          #{heading_control_record(5)}
        </section>
        <ul>#{heading_control_tail}</ul>
      </main></body></html>
    HTML

    with_url_page('https://newsroom.example/', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract_payload(page, reader_mode: false)
      markdown = payload['markdown']

      expect(payload['contentType']).to eq('list')
      expect(markdown).to include('## [Warszawa](https://newsroom.example/warsaw)')
      expect(markdown.lines.grep(/Warszawa/).map(&:strip)).to eq(
        ['## [Warszawa](https://newsroom.example/warsaw)']
      )
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'preserves material change labels and dropdown values without complete action evidence' do
    html = <<~HTML
      <html><head><title>Topic newsroom</title></head><body><main>
        <h1>Topic newsroom</h1>
        <section id="lead-record">#{heading_control_record(1)}</section>
        <section>
          <h2><span class="topic-title">Climate </span><span class="topic-select">Change</span></h2>
          #{heading_control_record(2)}#{heading_control_record(3)}
        </section>
        <section>
          <h2><span class="topic-title">Management topic: </span><span class="Dropdown_select__hash">Change Management</span></h2>
          #{heading_control_record(4)}#{heading_control_record(5)}
        </section>
        <section>
          <h2><span class="topic-title">Exact selected value: </span><span class="Dropdown_select__hash">Change</span></h2>
          <article><h3><a href="/stories/12">Independent newsroom story 12</a></h3></article>
          <article><h3><a href="/stories/13">Independent newsroom story 13</a></h3></article>
        </section>
        <section>
          <h2><span class="topic-title">Selected Polish value: </span><span class="Dropdown_select__hash" aria-selected="true">zmień</span></h2>
          <article><h3><a href="/stories/14">Independent newsroom story 14</a></h3></article>
          <article><h3><a href="/stories/15">Independent newsroom story 15</a></h3></article>
        </section>
        <section>
          <h2><span class="topic-title">Unmarked selected value: </span><span class="Dropdown_select__hash">zmień</span></h2>
          <article><h3><a href="/stories/18">Independent newsroom story 18</a></h3></article>
          <article><h3><a href="/stories/19">Independent newsroom story 19</a></h3></article>
        </section>
        <section>
          <h2><a href="/topics/change-management">Change Management</a></h2>
          <article><h3><a href="/stories/16">Independent newsroom story 16</a></h3></article>
          <article><h3><a href="/stories/17">Independent newsroom story 17</a></h3></article>
        </section>
        <section data-section="selected-workflow">
          <h2>
            <span class="topic-title">Inherited selected value: </span>
            <span aria-selected="true"><span class="Dropdown_select__hash Dropdown_action">Change</span></span>
          </h2>
          <article><h3><a href="/stories/20">Independent newsroom story 20</a></h3></article>
          <article><h3><a href="/stories/21">Independent newsroom story 21</a></h3></article>
        </section>
        <ul>#{heading_control_tail}</ul>
      </main></body></html>
    HTML

    extract_from_url('https://newsroom.example/', html, reader_mode: false) do |payload|
      expect(payload['contentType']).to eq('list')
      expect(payload['markdown']).to include('## Climate Change')
      expect(payload['markdown']).to include('## Management topic: Change Management')
      expect(payload['markdown']).to include('## Exact selected value: Change')
      expect(payload['markdown']).to include('## Selected Polish value: zmień')
      expect(payload['markdown']).to include('## Unmarked selected value: zmień')
      expect(payload['markdown']).to include(
        '## [Change Management](https://newsroom.example/topics/change-management)'
      )
      expect(payload['markdown']).to include('## Inherited selected value: Change')
    end
  end

  it 'removes a trailing semantic heading action' do
    html = <<~HTML
      <html><head><title>Semantic control newsroom</title></head><body><main>
        <h1>Semantic control newsroom</h1>
        <section id="lead-record">#{heading_control_record(1)}</section>
        <section>
          <h2><span>Warszawa</span><button type="button">Change</button></h2>
          #{heading_control_record(2)}#{heading_control_record(3)}
        </section>
        <section><h2>Culture desk</h2>#{heading_control_record(4)}#{heading_control_record(5)}</section>
        <ul>#{heading_control_tail}</ul>
      </main></body></html>
    HTML

    extract_from_url('https://newsroom.example/', html, reader_mode: false) do |payload|
      expect(payload['markdown']).to include('## Warszawa')
      expect(payload['markdown']).not_to include('## WarszawaChange')
    end
  end

  it 'does not alter action-like article prose, code, or ordinary destinations' do
    html = <<~HTML
      <html><head><title>How interfaces change</title></head><body><main><article>
        <h1>How interfaces change</h1>
        <p>Change Management remains material prose when it explains a substantive topic in an article.</p>
        <p><a href="/settings/change-location">Change location settings</a> documents the available setting.</p>
        <pre><code>&lt;span class="Dropdown_select"&gt;Change&lt;/span&gt;</code></pre>
      </article></main></body></html>
    HTML

    extract_from_url('https://newsroom.example/guides/change', html, reader_mode: false) do |payload|
      expect(payload['markdown']).to include('Change Management remains material prose')
      expect(payload['markdown']).to include('[Change location settings](https://newsroom.example/settings/change-location)')
      expect(payload['markdown']).to include('Dropdown_select')
    end
  end
end
